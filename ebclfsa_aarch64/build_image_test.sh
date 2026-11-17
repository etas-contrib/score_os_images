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

script=$(realpath "$(dirname "$0")/build_image.sh")
fixture=$(mktemp -d)
trap 'rm -rf -- "$fixture"' EXIT
export fixture
mkdir -p "$fixture/toolkit"/{kas,layers,.devcontainer} \
    "$fixture/source/meta-score" "$fixture/deb/DEBIAN"
printf 'header:\n  version: 18\n' > "$fixture/source/kas.yml"
cat > "$fixture/deb/DEBIAN/control" <<EOF
Package: score-test
Version: 1.0
Architecture: all
Maintainer: Test <test@example.com>
Description: Image builder test fixture
EOF
dpkg-deb --build "$fixture/deb" "$fixture/score-test.deb" >/dev/null

# Substitute only the expensive container build, checking its generated inputs.
docker() {
    if [[ $1 == info ]]; then
        return
    fi
    [[ $1 == run ]]
    local work="" argument
    for argument in "$@"; do
        if [[ $argument == type=bind,src=*,dst=/workspace ]]; then
            work=${argument#type=bind,src=}
            work=${work%,dst=/workspace}
        fi
    done
    [[ -d "$work" ]]
    grep -Fx "machine: \"$test_machine\"" "$work/kas/score-target.yml"
    grep -Fx '  - "score-image"' "$work/kas/score-target.yml"
    grep -Fx "COMPATIBLE_MACHINE = \"$test_machine\"" \
        "$work/meta-score/recipes-score/score-test/score-test_1.0.bb"
    if [[ $test_release == true ]]; then
        grep -Fx '  - "score-image-sdk"' "$work/kas/score-target.yml"
    elif grep -Fq score-image-sdk "$work/kas/score-target.yml"; then
        echo "Error: legacy image build unexpectedly includes the SDK" >&2
        return 1
    fi
    if [[ $test_machine == rpi4b ]]; then
        grep -F 'kas/machines/public/rpi4b.yml' "$work/kas/score-bsp.yml"
    fi
    local deploy="$work/build/tmp/deploy/images/$test_machine"
    local image="score-image-trixie-ebclfsa-$test_machine"
    local sdk="score-image-sdk-trixie-ebclfsa-$test_machine"
    mkdir -p "$deploy"
    truncate -s 1M "$deploy/$image.wic"
    printf kernel > "$deploy/$image-vmlinux"
    printf '{}' > "$deploy/$image.spdx.json"
    if [[ ${omit_key:-false} == false ]]; then
        printf 'development login key fixture for %s\n' "$test_machine" > "$deploy/$image-ssh-target-key"
        chmod 0600 "$deploy/$image-ssh-target-key"
    fi
    touch "$deploy/ssh_host_ed25519_key"
    if [[ ${omit_sdk:-false} == false ]]; then
        tar -czf "$deploy/$sdk.tar.gz" --files-from /dev/null
        printf '{}' > "$deploy/$sdk.spdx.json"
    fi
}
export -f docker

export test_machine=ebcl-qemuarm64 test_release=false
mkdir "$fixture/legacy"
bash "$script" "$fixture/toolkit" "$fixture/source/kas.yml" \
    "$fixture/legacy" "$fixture/score-test.deb"
[[ $(find "$fixture/legacy" -type f | wc -l) == 3 ]]
[[ -f "$fixture/legacy/score-image-trixie-ebclfsa-ebcl-qemuarm64.wic" ]]
[[ -f "$fixture/legacy/score-image-trixie-ebclfsa-ebcl-qemuarm64-vmlinux" ]]
[[ -f "$fixture/legacy/score-image-trixie-ebclfsa-ebcl-qemuarm64-ssh-target-key" ]]

export test_release=true
for test_machine in ebcl-qemuarm64 rpi4b; do
    output="$fixture/$test_machine"
    mkdir "$output"
    bash "$script" --release "$test_machine" "$fixture/toolkit" \
        "$fixture/source/kas.yml" "$output" "$fixture/score-test.deb"
    image="score-image-trixie-ebclfsa-$test_machine"
    [[ $(find "$output" -type f | wc -l) == 4 ]]
    (
        cd "$output"
        sha256sum --check "$image.sha256"
        tar -tzf "$image.tar.gz" > contents
        [[ $(wc -l < contents) == 4 ]]
        grep -Fx "$image.wic" contents
        grep -Fx "$image-vmlinux" contents
        grep -Fx "$image.spdx.json" contents
        grep -Fx "$image-ssh-target-key" contents
        if grep -Fq ssh_host contents; then
            echo "Error: image archive includes SSH server host keys" >&2
            exit 1
        fi
        tar -xzf "$image.tar.gz" "$image-ssh-target-key"
        [[ $(cat "$image-ssh-target-key") == "development login key fixture for $test_machine" ]]
        [[ $(stat -c %a "$image-ssh-target-key") == 600 ]]
    )
done

export omit_sdk=true
mkdir "$fixture/missing"
if bash "$script" --release "$test_machine" "$fixture/toolkit" \
    "$fixture/source/kas.yml" "$fixture/missing" "$fixture/score-test.deb" \
    > "$fixture/missing.log" 2>&1; then
    echo "Error: missing SDK did not fail the build" >&2
    exit 1
fi
grep -F 'KAS did not produce the expected artifact:' "$fixture/missing.log"
[[ -z $(find "$fixture/missing" -mindepth 1 -print -quit) ]]

export omit_sdk=false omit_key=true
mkdir "$fixture/missing-key"
if bash "$script" --release "$test_machine" "$fixture/toolkit" \
    "$fixture/source/kas.yml" "$fixture/missing-key" "$fixture/score-test.deb" \
    > "$fixture/missing-key.log" 2>&1; then
    echo "Error: missing SSH login key did not fail the build" >&2
    exit 1
fi
grep -F "KAS did not produce the expected artifact:" "$fixture/missing-key.log" \
    | grep -F "$image-ssh-target-key"
[[ -z $(find "$fixture/missing-key" -mindepth 1 -print -quit) ]]

if bash "$script" --release invalid "$fixture/toolkit" \
    "$fixture/source/kas.yml" "$fixture/missing" > "$fixture/invalid.log" 2>&1; then
    echo "Error: unsupported machine did not fail the build" >&2
    exit 1
fi
grep -F 'unsupported release machine: invalid' "$fixture/invalid.log"
echo "Image build script tests passed"
