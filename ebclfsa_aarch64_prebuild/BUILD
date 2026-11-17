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

load("//:qemu_config.bzl", "qemu_config")

exports_files(
    [
        "build_image.sh",
    ],
    visibility = ["//visibility:public"],
)

# Debian packages also installed by //ebclfsa_aarch64:build-image.
IMAGE_PACKAGES = [
    "//ebclfsa_aarch64:network_config_deb",
    "//ebclfsa_aarch64:sshd_config_deb",
]

genrule(
    name = "extract-fastdev-image",
    srcs = ["@eb_corbos_toolkit_fastdev_archive//file"],
    outs = [
        "ebcl-qemuarm64/fastdev-trixie-ebclfsa-ebcl-qemuarm64.wic",
        "ebcl-qemuarm64/fastdev-trixie-ebclfsa-ebcl-qemuarm64-vmlinux",
    ],
    cmd = "mkdir -p $(RULEDIR)/ebcl-qemuarm64 && tar xzf $(location @eb_corbos_toolkit_fastdev_archive//file) -C $(RULEDIR)/ebcl-qemuarm64 && chmod +w $(RULEDIR)/ebcl-qemuarm64/fastdev-trixie-ebclfsa-ebcl-qemuarm64.wic",
    tags = [
        "manual",
    ],
    visibility = ["//visibility:private"],
)

genrule(
    name = "itf-image",
    srcs = [
        ":extract-fastdev-image",
        ":ssh_target_key",
        "build_image.sh",
    ] + IMAGE_PACKAGES,
    outs = [
        "ebcl-qemuarm64-itf/fastdev-trixie-ebclfsa-ebcl-qemuarm64.wic",
        "ebcl-qemuarm64-itf/fastdev-trixie-ebclfsa-ebcl-qemuarm64-vmlinux",
    ],
    cmd = """
        bash $(location :build_image.sh) \
            $(RULEDIR) \
            $(RULEDIR)/ebcl-qemuarm64 \
            $(RULEDIR)/ebcl-qemuarm64-itf \
            $(location :ssh_target_key) \
            $(location //ebclfsa_aarch64:network_config_deb) \
            $(location //ebclfsa_aarch64:sshd_config_deb)
    """,
    tags = [
        "manual",
    ],
    visibility = ["//visibility:private"],
)

filegroup(
    name = "image",
    srcs = [":ebcl-qemuarm64-itf/fastdev-trixie-ebclfsa-ebcl-qemuarm64.wic"],
    tags = [
        "manual",
    ],
    visibility = ["//visibility:public"],
)

filegroup(
    name = "vanilla-image",
    srcs = ["ebcl-qemuarm64/fastdev-trixie-ebclfsa-ebcl-qemuarm64.wic"],
    tags = [
        "manual",
    ],
    visibility = ["//visibility:public"],
)

filegroup(
    name = "kernel",
    srcs = [":ebcl-qemuarm64/fastdev-trixie-ebclfsa-ebcl-qemuarm64-vmlinux"],
    tags = [
        "manual",
    ],
    visibility = ["//visibility:public"],
)

filegroup(
    name = "ssh_target_key",
    srcs = ["@eb_corbos_toolkit_target_key//file"],
    visibility = ["//visibility:public"],
)

qemu_config(
    name = "qemu_config",
    out = "qemu_config.json",
    key = ":ssh_target_key",
    template = "//ebclfsa_aarch64:qemu_config.template.json",
    visibility = ["//visibility:public"],
)
