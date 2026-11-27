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
#
# Assembles a raw disk image with a single FAT boot partition, e.g. a firmware
# + U-Boot SD card. Used by the boot_disk rule (defs.bzl).
#
# The whole image is produced unprivileged (no loop mounts / no root) using
# mtools + sfdisk.
#
# Usage:
#   build_image.sh --out <image> [options] <dest>=<src> [<dest>=<src> ...]
#
# Options:
#   --partition-table mbr|gpt   (default: mbr)
#   --offset-kib <n>            first partition offset in KiB (default: 1024)
#   --size-mib <n>              FAT partition size in MiB (default: 128)
#   --fat-type 16|32            (default: 32)
#   --label <label>             FAT volume label, <= 11 chars (default: BOOT)
#
# Every <src> is copied to <dest> on the FAT partition (parent directories are
# created). A directory <src> is copied recursively below <dest>.

set -euo pipefail

usage() {
    echo "Usage: $0 --out <image> [--partition-table mbr|gpt] [--offset-kib N]" \
        "[--size-mib N] [--fat-type 16|32] [--label L] <dest>=<src>..." >&2
    exit 1
}

OUT_IMAGE=""
PARTITION_TABLE="mbr"
OFFSET_KIB=1024
SIZE_MIB=128
FAT_TYPE=32
VOLUME_LABEL="BOOT"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --out) OUT_IMAGE="$2"; shift 2 ;;
        --partition-table) PARTITION_TABLE="$2"; shift 2 ;;
        --offset-kib) OFFSET_KIB="$2"; shift 2 ;;
        --size-mib) SIZE_MIB="$2"; shift 2 ;;
        --fat-type) FAT_TYPE="$2"; shift 2 ;;
        --label) VOLUME_LABEL="$2"; shift 2 ;;
        --*) echo "Error: unknown option '$1'." >&2; usage ;;
        *) break ;;
    esac
done
ENTRIES=("$@")

if [[ -z "${OUT_IMAGE}" || ${#ENTRIES[@]} -eq 0 ]]; then
    usage
fi

for tool in mformat mcopy mmd sfdisk dd truncate; do
    if ! command -v "${tool}" &>/dev/null; then
        echo "Error: required tool '${tool}' is not installed." >&2
        echo "       Need mtools (mformat, mcopy, mmd) and util-linux (sfdisk)." >&2
        exit 1
    fi
done

SECTOR_SIZE=512
# The primary GPT occupies LBA 0-33; MBR only needs LBA 0.
case "${PARTITION_TABLE}" in
    mbr) min_offset_kib=1 ;;
    gpt) min_offset_kib=17 ;;
    *) echo "Error: partition table must be 'mbr' or 'gpt', got '${PARTITION_TABLE}'." >&2; exit 1 ;;
esac
case "${FAT_TYPE}" in
    16) mbr_type=e ;;  # W95 FAT16 (LBA)
    32) mbr_type=c ;;  # W95 FAT32 (LBA)
    *) echo "Error: FAT type must be 16 or 32, got '${FAT_TYPE}'." >&2; exit 1 ;;
esac
if (( OFFSET_KIB < min_offset_kib )); then
    echo "Error: offset must be >= ${min_offset_kib} KiB for ${PARTITION_TABLE}, got ${OFFSET_KIB}." >&2
    exit 1
fi
# FAT32 needs at least 65525 clusters.
if [[ "${FAT_TYPE}" == "32" ]] && (( SIZE_MIB < 33 )); then
    echo "Error: FAT32 needs a partition of at least 33 MiB, got ${SIZE_MIB}." >&2
    exit 1
fi
if (( ${#VOLUME_LABEL} > 11 )); then
    echo "Error: volume label '${VOLUME_LABEL}' is longer than 11 characters." >&2
    exit 1
fi

# Geometry, all in 512-byte sectors.
offset_sectors=$(( OFFSET_KIB * 1024 / SECTOR_SIZE ))
part_sectors=$(( SIZE_MIB * 1024 * 1024 / SECTOR_SIZE ))
# GPT keeps a backup table at the end of the disk; reserve a 1 MiB tail for it
# (and for alignment slack on MBR).
tail_sectors=$(( 1024 * 1024 / SECTOR_SIZE ))
total_sectors=$(( offset_sectors + part_sectors + tail_sectors ))

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "${WORK_DIR}"' EXIT
FAT_IMAGE="${WORK_DIR}/boot.fat"

# ---------------------------------------------------------------------------
# 1. Build the FAT filesystem image and populate it.
# ---------------------------------------------------------------------------
truncate -s "$(( part_sectors * SECTOR_SIZE ))" "${FAT_IMAGE}"

# mformat derives the filesystem size from the backing file. MTOOLS_SKIP_CHECK
# silences the geometry heuristics that otherwise reject plain image files.
export MTOOLS_SKIP_CHECK=1
mformat_args=(-i "${FAT_IMAGE}" -v "${VOLUME_LABEL}")
if [[ "${FAT_TYPE}" == "32" ]]; then
    mformat_args+=(-F)
fi
mformat "${mformat_args[@]}" ::

declare -A made_dirs=()

# Creates every missing parent directory of FAT path $1.
make_parents() {
    local dir path="" parts key
    IFS=/ read -ra parts <<<"$(dirname "$1")"
    for dir in "${parts[@]}"; do
        [[ -z "${dir}" || "${dir}" == "." ]] && continue
        path="${path}/${dir}"
        key="${path,,}"
        if [[ -z "${made_dirs[${key}]:-}" ]]; then
            mmd -i "${FAT_IMAGE}" "::${path}"
            made_dirs[${key}]=1
        fi
    done
}

copy_file() {
    make_parents "$2"
    mcopy -i "${FAT_IMAGE}" "$1" "::/$2"
}

for entry in "${ENTRIES[@]}"; do
    if [[ "${entry}" != *=* ]]; then
        echo "Error: expected <dest>=<src>, got '${entry}'." >&2
        exit 1
    fi
    dest="${entry%%=*}"
    dest="${dest#/}"
    src="${entry#*=}"
    if [[ -d "${src}" ]]; then
        while IFS= read -r -d '' f; do
            copy_file "${f}" "${dest}/${f#"${src}"/}"
        done < <(find -L "${src}" -type f -print0 | sort -z)
    elif [[ -e "${src}" ]]; then
        copy_file "${src}" "${dest}"
    else
        echo "Error: boot file does not exist: ${src}" >&2
        exit 1
    fi
done

# ---------------------------------------------------------------------------
# 2. Create the raw disk, write the partition table, place the FAT partition.
# ---------------------------------------------------------------------------
mkdir -p "$(dirname "${OUT_IMAGE}")"
rm -f "${OUT_IMAGE}"
truncate -s "$(( total_sectors * SECTOR_SIZE ))" "${OUT_IMAGE}"

if [[ "${PARTITION_TABLE}" == "mbr" ]]; then
    # Bootable flag set so firmware that cares (e.g. the RPi) scans it.
    sfdisk --quiet "${OUT_IMAGE}" <<EOF
label: dos
unit: sectors
start=${offset_sectors}, size=${part_sectors}, type=${mbr_type}, bootable
EOF
else
    # EFI System Partition type GUID.
    ESP_GUID="C12A7328-F81F-11D2-BA4B-00A0C93EC93B"
    sfdisk --quiet "${OUT_IMAGE}" <<EOF
label: gpt
unit: sectors
start=${offset_sectors}, size=${part_sectors}, type=${ESP_GUID}, name="${VOLUME_LABEL}"
EOF
fi

dd if="${FAT_IMAGE}" of="${OUT_IMAGE}" bs="${SECTOR_SIZE}" seek="${offset_sectors}" \
    conv=notrunc status=none
