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

machine=ebcl-qemuarm64
release=false
if [[ ${1:-} == --release ]]; then
    if [[ $# -lt 5 ]]; then
        echo "Usage: $0 --release MACHINE TOOLKIT_SOURCE_DIR KAS_CONFIG OUTPUT_DIR [PACKAGE_DEB ...]" >&2
        exit 1
    fi
    machine=$2
    case "$machine" in
        ebcl-qemuarm64|rpi4b) ;;
        *)
            echo "Error: unsupported release machine: $machine" >&2
            exit 1
            ;;
    esac
    release=true
    shift 2
fi

if [[ $# -lt 3 ]]; then
    echo "Usage: $0 TOOLKIT_SOURCE_DIR KAS_CONFIG OUTPUT_DIR [PACKAGE_DEB ...]" >&2
    exit 1
fi

for tool in docker realpath dpkg-deb; do
    if ! command -v "$tool" >/dev/null; then
        echo "Error: required image build tool is missing: $tool" >&2
        exit 1
    fi
done
docker info >/dev/null

toolkit=$(realpath "$1")
config=$(realpath "$2")
output=$(realpath "$3")
shift 3
sources=$(dirname "$config")
# Keep the workspace on the same filesystem visible to the Docker daemon.
work=$(mktemp -d "$output/kas-work.XXXXXXXX")
trap 'rm -rf -- "$work"' EXIT

cp -R "$toolkit/kas" "$toolkit/layers" "$toolkit/.devcontainer" "$work/"
cp -R "$sources/meta-score" "$work/meta-score"
cp "$config" "$work/kas/score.yml"
package_names=()
for deb in "$@"; do
    name=$(dpkg-deb --field "$deb" Package)
    if [[ ! "$name" =~ ^[a-z0-9][a-z0-9+.-]+$ ]]; then
        echo "Error: invalid Debian package name in $deb: $name" >&2
        exit 1
    fi
    recipe="$work/meta-score/recipes-score/$name"
    if [[ -e "$recipe" ]]; then
        echo "Error: duplicate package or existing recipe for: $name" >&2
        exit 1
    fi
    mkdir -p "$recipe/files"
    cp -- "$deb" "$recipe/files/$name.deb"
    cat > "$recipe/${name}_1.0.bb" <<EOF
SUMMARY = "Bazel-built Debian package $name"
LICENSE = "CLOSED"

inherit dpkg-prebuilt

SRC_URI = "file://$name.deb"
COMPATIBLE_MACHINE = "$machine"
EOF
    package_names+=("$name")
done
cat > "$work/kas/score-packages.yml" <<EOF
header:
  version: 18

local_conf_header:
  score_packages: |
    IMAGE_INSTALL:append = " ${package_names[*]}"
EOF

cat > "$work/kas/score-target.yml" <<EOF
header:
  version: 18
machine: "$machine"
target:
  - "score-image"
EOF
if [[ "$release" == true ]]; then
    echo '  - "score-image-sdk"' >> "$work/kas/score-target.yml"
fi
if [[ "$machine" == rpi4b ]]; then
    cat > "$work/kas/score-bsp.yml" <<EOF
header:
  version: 18
  includes:
    - "kas/machines/public/rpi4b.yml"
EOF
else
    cat > "$work/kas/score-bsp.yml" <<EOF
header:
  version: 18
EOF
fi

# Match the toolkit's v18 container, pinned independently of its mutable tag.
container=ghcr.io/elektrobit/eb-corbos-toolkit-devcontainer-amd64@sha256:10f487469c03fb2b5be1c804ec0b0c911d3903a9dd9a8fcbb8b8f401d43b158c
# The image is public. Avoid host credential helpers, which may be unavailable
# when this local Bazel action runs inside a dev container.
mkdir "$work/.docker"
DOCKER_CONFIG="$work/.docker" docker run --rm --init --privileged --user root \
    --mount "type=bind,src=$work,dst=/workspace" \
    --workdir /workspace "$container" \
    bash -euo pipefail -c '
        uid=$1
        gid=$2
        if ! getent group "$gid" >/dev/null; then
            groupmod -g "$gid" developer
        fi
        usermod -u "$uid" -g "$gid" developer
        cleanup() {
            status=$?
            # BitBake may remove its socket and lock while chown traverses the
            # workspace. Cleanup must not turn a successful build into a failure.
            chown -R "$uid:$gid" /workspace || :
            exit "$status"
        }
        trap cleanup EXIT
        if [[ ! -e /proc/sys/fs/binfmt_misc/qemu-aarch64 ]]; then
            mount -t binfmt_misc binfmt_misc /proc/sys/fs/binfmt_misc
            update-binfmts --import /workspace/.devcontainer/binfmt-config/qemu-aarch64
        fi
        # KAS resolves includes relative to the enclosing Git repository.
        runuser -u developer -- git init --quiet /workspace
        # The release checkout already includes the patched Isar tree; its internal
        # patch sources are not shipped.
        runuser -u developer -- kas build \
            --skip repos_checkout --skip repos_apply_patches \
            kas/references/public.yml:kas/score-bsp.yml:kas/score.yml:kas/score-packages.yml:kas/score-target.yml
    ' bash "$(id -u)" "$(id -g)"

deploy="$work/build/tmp/deploy/images/$machine"
image="score-image-trixie-ebclfsa-$machine"
sdk="score-image-sdk-trixie-ebclfsa-$machine"
artifacts=("$image.wic" "$image-vmlinux")
if [[ "$release" == true ]]; then
    artifacts+=("$image.spdx.json" "$image-ssh-target-key" "$sdk.tar.gz" "$sdk.spdx.json")
fi
for artifact in "${artifacts[@]}"; do
    if [[ ! -f "$deploy/$artifact" ]]; then
        echo "Error: KAS did not produce the expected artifact: $deploy/$artifact" >&2
        exit 1
    fi
    if [[ "$release" == false ]]; then
        cp --sparse=always -L "$deploy/$artifact" "$output/$artifact"
    fi
done

if [[ "$release" == true ]]; then
    # Publish only the development login key, never SSH server host keys.
    tar --sparse -czf "$output/$image.tar.gz" -C "$deploy" \
        "$image.wic" "$image-vmlinux" "$image.spdx.json" "$image-ssh-target-key"
    cp -L "$deploy/$sdk.tar.gz" "$deploy/$sdk.spdx.json" "$output/"
    (
        cd "$output"
        sha256sum "$image.tar.gz" "$sdk.tar.gz" "$sdk.spdx.json" > "$image.sha256"
    )
fi
