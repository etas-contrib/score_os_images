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
COMPATIBLE_MACHINE = "ebcl-qemuarm64"
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
            kas/references/public.yml:kas/score.yml:kas/score-packages.yml
    ' bash "$(id -u)" "$(id -g)"

deploy="$work/build/tmp/deploy/images/ebcl-qemuarm64"
for artifact in score-image-trixie-ebclfsa-ebcl-qemuarm64{.wic,-vmlinux}; do
    if [[ ! -f "$deploy/$artifact" ]]; then
        echo "Error: KAS did not produce the expected artifact: $deploy/$artifact" >&2
        exit 1
    fi
    cp --sparse=always -L "$deploy/$artifact" "$output/$artifact"
done
