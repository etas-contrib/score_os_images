# *******************************************************************************
# Copyright (c) 2025 Contributors to the Eclipse Foundation
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

"""Bazel build definition for the bootargs_fdt utility.

The binary is compiled for QNX 8.0 aarch64le using the qcc compiler from the
QNX SDP package exposed by the score_rules_imagefs Bazel module.
"""

_SRCS = [
    "main.c",
    "args.c",
    "args.h",
    "libfdt_loader.c",
    "libfdt_loader.h",
    "fdt_locate.c",
    "fdt_locate.h",
    "fdt_map.c",
    "fdt_map.h",
    "bootargs.c",
    "bootargs.h",
    "output.c",
    "output.h",
]

_CFLAGS = " ".join([
    "-Vgcc_ntoaarch64le",
    "-Wall",
    "-Wextra",
    "-Wpedantic",
    "-std=c11",
    "-D_QNX_SOURCE",
    "-O2",
])

genrule(
    name = "bootargs_fdt",
    srcs = _SRCS + [
        "@score_qnx_imagefs_toolchain_pkg//:qcc",
        "@score_qnx_imagefs_toolchain_pkg//:host_sysroot",
        "@score_qnx_imagefs_toolchain_pkg//:target_sysroot",
    ],
    outs = ["bootargs_fdt"],
    cmd = """
        # Derive the SDP root from the location of qcc:
        # qcc lives at <sdp_root>/host/linux/x86_64/usr/bin/qcc
        QCC=$(location @score_qnx_imagefs_toolchain_pkg//:qcc)
        SDP_ROOT=$$(cd $$(dirname $$QCC)/../../../../.. && pwd)

        export QNX_HOST=$$SDP_ROOT/host/linux/x86_64
        export QNX_TARGET=$$SDP_ROOT/target/qnx

        $$QCC {cflags} \\
            $(location main.c) \\
            $(location args.c) \\
            $(location libfdt_loader.c) \\
            $(location fdt_locate.c) \\
            $(location fdt_map.c) \\
            $(location bootargs.c) \\
            $(location output.c) \\
            -o $(OUTS)
    """.format(cflags = _CFLAGS),
    visibility = ["//visibility:public"],
)
