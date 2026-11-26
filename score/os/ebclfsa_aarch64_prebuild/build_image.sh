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

if [[ $# -lt 5 ]]; then
    echo "Error: Expected working directory, image source, image target, SSH target key, and one or more Debian packages in dependency order (i.e. more independent packages first)" >&2
    exit 1
fi

WORKING_DIR="$1"
IMAGE_SOURCE="$2"
IMAGE_TARGET="$3"
SSH_TARGET_KEY="$4"
shift 4
DEPLOY_SRCS=("$@")

if [[ ! -d "${WORKING_DIR}" ]]; then
    echo "Error: Working directory does not exist: ${WORKING_DIR}" >&2
    exit 1
fi
if [[ ! -d "${IMAGE_SOURCE}" ]]; then
    echo "Error: Image source location is not a directory: ${IMAGE_SOURCE}" >&2
    exit 1
fi
if [[ -e "${IMAGE_TARGET}" && ! -d "${IMAGE_TARGET}" ]]; then
    echo "Error: Image target location exists but is not a directory: ${IMAGE_TARGET}" >&2
    exit 1
fi
if [[ ! -f "${SSH_TARGET_KEY}" ]]; then
    echo "Error: SSH target key does not exist: ${SSH_TARGET_KEY}" >&2
    exit 1
fi

for src in "${DEPLOY_SRCS[@]}"; do
    if [[ ! -f "${src}" ]]; then
        echo "Error: Deploy source file does not exist: ${src}" >&2
        exit 1
    fi
    if [[ ! "${src}" =~ \.deb$ ]]; then
        echo "Error: Deploy source is not a Debian package: ${src}" >&2
        exit 1
    fi
    if ! dpkg-deb --info "${src}" >/dev/null; then
        echo "Error: invalid Debian package: ${src}" >&2
        exit 1
    fi
done

mapfile -t image_files < <(find -L "${IMAGE_SOURCE}" -maxdepth 1 -type f -name "*.wic" -print)
mapfile -t kernel_files < <(find -L "${IMAGE_SOURCE}" -maxdepth 1 -type f -name "*-vmlinux" -print)
if [[ ${#image_files[@]} -ne 1 ]]; then
    echo "Error: Expected exactly one .wic file in ${IMAGE_SOURCE}, found ${#image_files[@]}" >&2
    exit 1
fi
if [[ ${#kernel_files[@]} -ne 1 ]]; then
    echo "Error: Expected exactly one *-vmlinux file in ${IMAGE_SOURCE}, found ${#kernel_files[@]}" >&2
    exit 1
fi
IMAGE="${image_files[0]}"
KERNEL="${kernel_files[0]}"
if [[ "${KERNEL}" != "${IMAGE%.wic}-vmlinux" ]]; then
    echo "Error: Kernel does not match image: ${KERNEL} and ${IMAGE}" >&2
    exit 1
fi

mkdir -p "${IMAGE_TARGET}"
cp -L --remove-destination -- "${IMAGE}" "${IMAGE_TARGET}/image.wic"
cp -L --remove-destination -- "${KERNEL}" "${IMAGE_TARGET}/kernel-vmlinux"
IMAGE="${IMAGE_TARGET}/image.wic"
KERNEL="${IMAGE_TARGET}/kernel-vmlinux"

# The image file must be writable for qemu overlay handling.
chmod +w "${IMAGE}"

SSH_KEY="${WORKING_DIR}/ssh_target_key"
cp "${SSH_TARGET_KEY}" "${SSH_KEY}"
chmod 600 "${SSH_KEY}"
SSH_OPTIONS=(
    -i "${SSH_KEY}"
    -o IdentitiesOnly=yes
    -o BatchMode=yes
    -o PasswordAuthentication=no
    -o KbdInteractiveAuthentication=no
    -o StrictHostKeyChecking=no
)

SSH_PORT="$(python3 -c 'import socket; s = socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1]); s.close()')"
QEMU_LOG="${WORKING_DIR}/qemu_deployment.log"
QEMU_PID=

cleanup() {
    result=$?
    trap - EXIT INT TERM
    if [[ -n "${QEMU_PID}" ]] && kill -0 "${QEMU_PID}" 2>/dev/null; then
        kill "${QEMU_PID}" 2>/dev/null || true
    fi
    if [[ -n "${QEMU_PID}" ]]; then
        wait "${QEMU_PID}" 2>/dev/null || true
    fi
    rm -f -- "${SSH_KEY}"
    exit "${result}"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

qemu-system-aarch64 -m 2048 -cpu cortex-a53 \
    -kernel "${KERNEL}" \
    -machine "virt,virtualization=true,gic-version=3" \
    -smp 8 \
    -device virtio-blk-device,drive=vd0 -drive if=none,format=raw,file="${IMAGE}",id=vd0 \
    -append "root=/dev/vda1 sdk_enable lisa_syscall_whitelist=2026 rw sharedmem.enable_sharedmem=0 init=/usr/bin/ebclfsa-cflinit" \
    -netdev user,id=net0,net=192.168.7.0/24,dhcpstart=192.168.7.2,dns=192.168.7.3,host=192.168.7.5,hostfwd="tcp:127.0.0.1:${SSH_PORT}-:22" \
    -device virtio-net-device,netdev=net0 \
    -nographic > "${QEMU_LOG}" 2>&1 &
QEMU_PID=$!

ready=false
for _ in {1..60}; do
    if ssh "${SSH_OPTIONS[@]}" -o ConnectTimeout=1 -p "${SSH_PORT}" root@localhost true 2>/dev/null; then
        ready=true
        break
    fi
    if ! kill -0 "${QEMU_PID}" 2>/dev/null; then
        break
    fi
    sleep 1
done
if [[ "${ready}" != true ]]; then
    echo "Error: QEMU image did not accept SSH connections on port ${SSH_PORT}" >&2
    exit 1
fi

for src in "${DEPLOY_SRCS[@]}"; do
    scp -rp "${SSH_OPTIONS[@]}" -P "${SSH_PORT}" "${src}" root@localhost:/
    ssh "${SSH_OPTIONS[@]}" -p "${SSH_PORT}" root@localhost "dpkg -i -- /$(basename "${src}")"
    ssh "${SSH_OPTIONS[@]}" -p "${SSH_PORT}" root@localhost "rm -f /$(basename "${src}")"
done

# Lock password-based logins - we rely exclusively on key-pairs.
ssh "${SSH_OPTIONS[@]}" -p "${SSH_PORT}" root@localhost "passwd -l root"

# Release images may already mount an attached ITF disk on /opt.
ssh "${SSH_OPTIONS[@]}" -p "${SSH_PORT}" root@localhost \
    'if ! awk '\''$2 == "/opt" && $1 !~ /^#/ { found=1 } END { exit !found }'\'' /etc/fstab; then printf "\n# Additional disk attached by the ITF QEMU plugin\n/dev/vdb\t/opt\tauto\tdefaults,nofail\t0\t0\n" >> /etc/fstab; fi'
ssh "${SSH_OPTIONS[@]}" -p "${SSH_PORT}" root@localhost "sync && crinit-ctl poweroff" || true
wait "${QEMU_PID}" 2>/dev/null || true
QEMU_PID=
