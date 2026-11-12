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

load("@rules_pkg//pkg:deb.bzl", "pkg_deb")
load("@rules_pkg//pkg:tar.bzl", "pkg_tar")

# Debian packages installed in addition to the score-image recipe's packages.
IMAGE_PACKAGES = [
    ":network_config_deb",
    ":sshd_config_deb",
]

exports_files(
    [
        "build_image.sh",
        "kas.yml",
        "meta-score/conf/layer.conf",
        "meta-score/recipes-images/score-image/score-image_1.0.bb",
        "qemu_config.json",
    ],
    visibility = ["//visibility:public"],
)

# Shared by both EBcLfSA image packages.
pkg_tar(
    name = "network_config_tar",
    srcs = ["config-overlay/etc/config/network"],
    mode = "0644",
    package_dir = "/etc/config",
    visibility = ["//visibility:public"],
)

# Selected in kas.yml through EBCLFSA_FASTDEV_NETWORK_CONFIG, so it replaces the
# toolkit's ebclfsa-fastdev-network package instead of conflicting with it.
pkg_deb(
    name = "network_config_deb",
    architecture = "all",
    conffiles = ["/etc/config/network"],
    conflicts = ["ebclfsa-fastdev-network"],
    data = ":network_config_tar",
    description = "Eclipse S-CORE network configuration for EB corbos Linux for Safety Applications",
    homepage = "https://github.com/eclipse-score/os_images",
    maintainer = "Eclipse S-CORE contributors <score-dev@eclipse.org>",
    package = "score-network-config",
    replaces = ["ebclfsa-fastdev-network"],
    version = "1.0",
    visibility = ["//visibility:public"],
)

pkg_tar(
    name = "sshd_config_tar",
    srcs = ["sshd-config/99-integration-test.conf"],
    mode = "0644",
    package_dir = "/etc/ssh/sshd_config.d",
)

# Together with the empty root password set in meta-score, this allows
# passwordless root SSH login for integration testing, not for production use.
pkg_deb(
    name = "sshd_config_deb",
    architecture = "all",
    conffiles = ["/etc/ssh/sshd_config.d/99-integration-test.conf"],
    data = ":sshd_config_tar",
    depends = ["openssh-server"],
    description = "Eclipse S-CORE passwordless root SSH login for integration testing",
    homepage = "https://github.com/eclipse-score/os_images",
    maintainer = "Eclipse S-CORE contributors <score-dev@eclipse.org>",
    package = "score-itf-sshd-config",
    version = "1.0",
    visibility = ["//visibility:public"],
)

# Builds the image with KAS/Isar in a privileged container. This takes a long
# time, so the target is only built when explicitly requested.
genrule(
    name = "build-image",
    srcs = [
        "kas.yml",
        "@eb_corbos_toolkit//:BUILD.bazel",
        "@eb_corbos_toolkit//:sources",
    ] + IMAGE_PACKAGES + glob(["meta-score/**"]),
    outs = [
        "score-image-trixie-ebclfsa-ebcl-qemuarm64-vmlinux",
        "score-image-trixie-ebclfsa-ebcl-qemuarm64.wic",
    ],
    cmd = "bash $(location build_image.sh) " +
          "$$(dirname $(location @eb_corbos_toolkit//:BUILD.bazel)) " +
          "$(location kas.yml) " +
          "$(RULEDIR) " +
          " ".join(["\"$(location %s)\"" % package for package in IMAGE_PACKAGES]),
    local = True,
    tags = ["manual"],
    tools = ["build_image.sh"],
    visibility = ["//visibility:private"],
)

filegroup(
    name = "image",
    srcs = [":score-image-trixie-ebclfsa-ebcl-qemuarm64.wic"],
    tags = ["manual"],
    visibility = ["//visibility:public"],
)

filegroup(
    name = "kernel",
    srcs = [":score-image-trixie-ebclfsa-ebcl-qemuarm64-vmlinux"],
    tags = ["manual"],
    visibility = ["//visibility:public"],
)

filegroup(
    name = "qemu_config",
    srcs = ["qemu_config.json"],
    visibility = ["//visibility:public"],
)
