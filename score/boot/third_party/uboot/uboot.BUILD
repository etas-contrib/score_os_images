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
# Applied to the extracted contents of the Ubuntu `u-boot-rpi` .deb. The package
# installs per-board U-Boot binaries under usr/lib/u-boot/<target>/.

# 64-bit U-Boot for the Raspberry Pi 4 (rpi_arm64 multi-Pi build).
filegroup(
    name = "rpi_arm64",
    srcs = ["usr/lib/u-boot/rpi_arm64/u-boot.bin"],
    visibility = ["//visibility:public"],
)

# All U-Boot binaries shipped by the package, in case another board is needed.
filegroup(
    name = "all",
    srcs = glob(["usr/lib/u-boot/**"]),
    visibility = ["//visibility:public"],
)
