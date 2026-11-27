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
# Compiles a plain-text U-Boot script into a boot.scr image. U-Boot only
# `source`s scripts wrapped in a legacy image header, which mkimage adds.
#
# Template expanded by uboot_boot_files (uboot.bzl); @@ARCH@@ is substituted
# at analysis time.
#
# Usage: compile_boot_script.sh <script source> <boot.scr output>

set -euo pipefail

if [[ $# -ne 2 ]]; then
    echo "Usage: $0 <script source> <boot.scr output>" >&2
    exit 1
fi

SRC="$1"
OUT="$2"

if ! command -v mkimage &>/dev/null; then
    echo "Error: mkimage is not installed (Fedora: uboot-tools, Ubuntu: u-boot-tools)." >&2
    exit 1
fi

mkimage -A "@@ARCH@@" -O linux -T script -C none -n boot.scr -d "${SRC}" "${OUT}" >/dev/null
