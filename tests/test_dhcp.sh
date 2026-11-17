#!/bin/bash
# *******************************************************************************
# Copyright (c) 2026 Contributors to the Eclipse Foundation
#
# See the NOTICE file(s) distributed with this work for additional
# information regarding copyright ownership.
#
# This program and the accompanying materials are made available under the
# terms of the Apache License Version 2.0 which is available at
# https://www.apache.org/licenses/LICENSE-2.0
#
# SPDX-License-Identifier: Apache-2.0
# *******************************************************************************

set -euo pipefail
export TMPDIR="$TEST_TMPDIR"

architecture=$1
image=$2
key=$3
shift 3

case "$architecture" in
    aarch64)
        kernel=$1
        qemu=(qemu-system-aarch64 -machine "virt,virtualization=true,gic-version=3"
            -cpu cortex-a53 -kernel "$kernel"
            -append "root=/dev/vda1 sdk_enable lisa_syscall_whitelist=2026 rw sharedmem.enable_sharedmem=0 init=/usr/bin/ebclfsa-cflinit"
            -device "virtio-blk-device,drive=vd0"
            -device "virtio-net-device,netdev=net0")
        format=raw
        ;;
    x86_64)
        qemu=(qemu-system-x86_64 -accel kvm -accel tcg -machine pc
            -cpu Cascadelake-Server-v5
            -device "virtio-blk-pci,drive=vd0"
            -device "virtio-net-pci,netdev=net0")
        format=qcow2
        ;;
    *)
        echo "Unsupported QEMU architecture: $architecture" >&2
        exit 1
        ;;
esac

cp "$key" "$TEST_TMPDIR/ssh-key"
chmod 600 "$TEST_TMPDIR/ssh-key"
ssh_options=(-i "$TEST_TMPDIR/ssh-key" -p 2222
    -o IdentitiesOnly=yes -o BatchMode=yes -o ConnectTimeout=2
    -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null
    -o LogLevel=ERROR)

"${qemu[@]}" -m 2048 -smp 2 -snapshot \
    -drive "if=none,format=$format,file=$image,id=vd0" \
    -netdev user,id=net0,net=192.168.7.0/24,dhcpstart=192.168.7.2,dns=192.168.7.3,host=192.168.7.5,hostfwd=tcp:127.0.0.1:2222-:22 \
    -nographic >"$TEST_TMPDIR/qemu.log" 2>&1 </dev/null &
qemu_pid=$!
cleanup() {
    kill "$qemu_pid" 2>/dev/null || true
    wait "$qemu_pid" 2>/dev/null || true
}
trap cleanup EXIT

ready=false
for _ in {1..120}; do
    if ssh "${ssh_options[@]}" root@127.0.0.1 true; then
        ready=true
        break
    fi
    if ! kill -0 "$qemu_pid" 2>/dev/null; then
        break
    fi
    sleep 1
done
if [[ $ready != true ]]; then
    echo "QEMU guest did not become reachable through DHCP and SSH" >&2
    cat "$TEST_TMPDIR/qemu.log" >&2
    exit 1
fi

ssh "${ssh_options[@]}" root@127.0.0.1 '
    set -eu
    for attempt in $(seq 1 30); do
        addresses=$(ip -4 -o addr show)
        static_interface=$(printf "%s\n" "$addresses" | awk "\$4 == \"169.254.158.190/16\" {print \$2}")
        dhcp_interface=$(printf "%s\n" "$addresses" | awk "\$4 == \"192.168.7.2/24\" {print \$2}")
        if [ -n "$static_interface" ] && [ "$static_interface" = "$dhcp_interface" ]; then
            break
        fi
        sleep 1
    done
    printf "%s\n" "$addresses"
    test -n "$static_interface"
    test "$static_interface" = "$dhcp_interface"
    ip -4 route show default | grep -E "via 169\\.254\\.21\\.88 .*metric 500"
    route=$(ip -4 route get 1.1.1.1)
    printf "%s\n" "$route"
    printf "%s\n" "$route" | grep -E "via 192\\.168\\.7\\.5 .*src 192\\.168\\.7\\.2"
    ping -c 1 -W 5 192.168.7.5
'
