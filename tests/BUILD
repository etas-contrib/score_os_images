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

load("@rules_pkg//pkg:mappings.bzl", "pkg_files")
load("@score_itf//:defs.bzl", "py_itf_test")
load("@score_rules_imagefs//rules/linux:ext4.bzl", "ext4")

pkg_files(
    name = "qemu_disk_files",
    srcs = ["qemu_disk_content.txt"],
    prefix = "",
)

# Additional disk attached to the QEMU targets via `--qemu-disk`. The images
# mount it on /opt automatically, see the `opt-mount` support in each image.
ext4(
    name = "qemu_disk_image",
    srcs = [":qemu_disk_files"],
    out = "qemu_disk.ext4",
    target_compatible_with = ["@platforms//os:linux"],
    visibility = ["//visibility:public"],
)

py_itf_test(
    name = "ubuntu_qemu_test",
    srcs = [
        "test_multicast.py",
        "test_no_disk.py",
        "test_ping.py",
    ],
    args = [
        "--qemu-config=$(location //ubuntu_x86_64:qemu_config)",
        "--qemu-rootfs=$(location //ubuntu_x86_64:image)",
    ],
    data = [
        "//ubuntu_x86_64:image",
        "//ubuntu_x86_64:qemu_config",
    ],
    plugins = ["@score_itf//score/itf/plugins:qemu_plugin"],
    tags = ["qemu-integration"],
    target_compatible_with = ["@platforms//os:linux"],
)

py_itf_test(
    name = "ebclfsa_qemu_test",
    srcs = [
        "test_multicast.py",
        "test_no_disk.py",
        "test_ping.py",
    ],
    args = [
        "--qemu-config=$(location //ebclfsa_aarch64:qemu_config)",
        "--qemu-kernel=$(location //ebclfsa_aarch64:kernel)",
        "--qemu-rootfs=$(location //ebclfsa_aarch64:image)",
    ],
    data = [
        "//ebclfsa_aarch64:image",
        "//ebclfsa_aarch64:kernel",
        "//ebclfsa_aarch64:qemu_config",
    ],
    plugins = ["@score_itf//score/itf/plugins:qemu_plugin"],
    tags = ["qemu-integration"],
    target_compatible_with = ["@platforms//os:linux"],
)

py_itf_test(
    name = "ubuntu_qemu_opt_mount_test",
    srcs = ["test_opt_mount.py"],
    args = [
        "--qemu-config=$(location //ubuntu_x86_64:qemu_config)",
        "--qemu-disk=$(location :qemu_disk_image)",
        "--qemu-rootfs=$(location //ubuntu_x86_64:image)",
    ],
    data = [
        ":qemu_disk_image",
        "//ubuntu_x86_64:image",
        "//ubuntu_x86_64:qemu_config",
    ],
    plugins = ["@score_itf//score/itf/plugins:qemu_plugin"],
    tags = ["qemu-integration"],
    target_compatible_with = ["@platforms//os:linux"],
)

py_itf_test(
    name = "ebclfsa_qemu_opt_mount_test",
    srcs = ["test_opt_mount.py"],
    args = [
        "--qemu-config=$(location //ebclfsa_aarch64:qemu_config)",
        "--qemu-disk=$(location :qemu_disk_image)",
        "--qemu-kernel=$(location //ebclfsa_aarch64:kernel)",
        "--qemu-rootfs=$(location //ebclfsa_aarch64:image)",
    ],
    data = [
        ":qemu_disk_image",
        "//ebclfsa_aarch64:image",
        "//ebclfsa_aarch64:kernel",
        "//ebclfsa_aarch64:qemu_config",
    ],
    plugins = ["@score_itf//score/itf/plugins:qemu_plugin"],
    tags = ["qemu-integration"],
    target_compatible_with = ["@platforms//os:linux"],
)
