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
load("@rules_python//python:defs.bzl", "py_test")
load("@score_itf//:defs.bzl", "py_itf_test")
load("@score_rules_imagefs//rules/linux:ext4.bzl", "ext4")

exports_files(
    glob(["test_*.py"]),
    visibility = ["//score/tests:__subpackages__"],
)

test_suite(
    name = "ebclfsa_aarch64_qemu_tests",
    tags = ["manual"],
    tests = [
        ":ebclfsa_dhcp_qemu_test",
        ":ebclfsa_qemu_opt_mount_test",
        ":ebclfsa_qemu_test",
    ],
)

sh_test(
    name = "ebclfsa_prebuild_dhcp_qemu_test",
    timeout = "long",
    srcs = ["test_dhcp.sh"],
    args = [
        "aarch64",
        "$(location //score/tests/ebclfsa_aarch64_prebuild:image)",
        "$(location //score/tests/ebclfsa_aarch64_prebuild:ssh_target_key)",
        "$(location //score/tests/ebclfsa_aarch64_prebuild:kernel)",
    ],
    data = [
        "//score/tests/ebclfsa_aarch64_prebuild:image",
        "//score/tests/ebclfsa_aarch64_prebuild:kernel",
        "//score/tests/ebclfsa_aarch64_prebuild:ssh_target_key",
    ],
    tags = ["qemu-integration"],
    target_compatible_with = ["@platforms//os:linux"],
)

sh_test(
    name = "ubuntu_dhcp_qemu_test",
    timeout = "long",
    srcs = ["test_dhcp.sh"],
    args = [
        "x86_64",
        "$(location //score/os/ubuntu_x86_64:image)",
        "$(location //score/os/ubuntu_x86_64:ssh_target_key)",
    ],
    data = [
        "//score/os/ubuntu_x86_64:image",
        "//score/os/ubuntu_x86_64:ssh_target_key",
    ],
    tags = ["qemu-integration"],
    target_compatible_with = ["@platforms//os:linux"],
)

sh_test(
    name = "ebclfsa_dhcp_qemu_test",
    timeout = "long",
    srcs = ["test_dhcp.sh"],
    args = [
        "aarch64",
        "$(location //score/os/ebclfsa_aarch64:image)",
        "$(location //score/os/ebclfsa_aarch64:ssh_target_key)",
        "$(location //score/os/ebclfsa_aarch64:kernel)",
    ],
    data = [
        "//score/os/ebclfsa_aarch64:image",
        "//score/os/ebclfsa_aarch64:kernel",
        "//score/os/ebclfsa_aarch64:ssh_target_key",
    ],
    tags = [
        "manual",
        "qemu-integration",
    ],
    target_compatible_with = ["@platforms//os:linux"],
)

py_test(
    name = "qemu_config_test",
    srcs = ["test_qemu_config.py"],
    args = [
        "$(location //score/tests/ebclfsa_aarch64_prebuild:qemu_config)",
        "$(location //score/os/ebclfsa_aarch64:qemu_config)",
        "$(location //score/os/ubuntu_x86_64:qemu_config)",
    ],
    data = [
        "//score/os/ebclfsa_aarch64:qemu_config",
        "//score/os/ubuntu_x86_64:qemu_config",
        "//score/tests/ebclfsa_aarch64_prebuild:qemu_config",
    ],
    main = "test_qemu_config.py",
)

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
        "test_ssh_auth.py",
    ],
    args = [
        "--qemu-config=$(location //score/os/ubuntu_x86_64:qemu_config)",
        "--qemu-rootfs=$(location //score/os/ubuntu_x86_64:image)",
    ],
    data = [
        "//score/os/ubuntu_x86_64:image",
        "//score/os/ubuntu_x86_64:qemu_config",
        "//score/os/ubuntu_x86_64:ssh_target_key",
    ],
    plugins = ["@score_itf//score/itf/plugins:qemu_plugin"],
    tags = ["qemu-integration"],
    target_compatible_with = ["@platforms//os:linux"],
)

py_itf_test(
    name = "ebclfsa_qemu_test",
    srcs = [
        "test_ebclfsa_ssh_host_keys.py",
        "test_multicast.py",
        "test_no_disk.py",
        "test_ping.py",
        "test_ssh_auth.py",
    ],
    args = [
        "--qemu-config=$(location //score/os/ebclfsa_aarch64:qemu_config)",
        "--qemu-kernel=$(location //score/os/ebclfsa_aarch64:kernel)",
        "--qemu-rootfs=$(location //score/os/ebclfsa_aarch64:image)",
    ],
    data = [
        "//score/os/ebclfsa_aarch64:image",
        "//score/os/ebclfsa_aarch64:kernel",
        "//score/os/ebclfsa_aarch64:qemu_config",
        "//score/os/ebclfsa_aarch64:ssh_host_public_keys",
        "//score/os/ebclfsa_aarch64:ssh_target_key",
    ],
    plugins = ["@score_itf//score/itf/plugins:qemu_plugin"],
    # Building the image takes long, so the test only runs when selected
    # explicitly, see .github/workflows/ebclfsa.yml.
    tags = [
        "manual",
        "qemu-integration",
    ],
    target_compatible_with = ["@platforms//os:linux"],
)

py_itf_test(
    name = "ebclfsa_prebuild_qemu_test",
    srcs = [
        "test_multicast.py",
        "test_no_disk.py",
        "test_ping.py",
        "test_ssh_auth.py",
    ],
    args = [
        "--qemu-config=$(location //score/tests/ebclfsa_aarch64_prebuild:qemu_config)",
        "--qemu-kernel=$(location //score/tests/ebclfsa_aarch64_prebuild:kernel)",
        "--qemu-rootfs=$(location //score/tests/ebclfsa_aarch64_prebuild:image)",
    ],
    data = [
        "//score/tests/ebclfsa_aarch64_prebuild:image",
        "//score/tests/ebclfsa_aarch64_prebuild:kernel",
        "//score/tests/ebclfsa_aarch64_prebuild:qemu_config",
        "//score/tests/ebclfsa_aarch64_prebuild:ssh_target_key",
    ],
    plugins = ["@score_itf//score/itf/plugins:qemu_plugin"],
    tags = [
        "qemu-integration",
    ],
    target_compatible_with = ["@platforms//os:linux"],
)

py_itf_test(
    name = "ubuntu_qemu_opt_mount_test",
    srcs = ["test_opt_mount.py"],
    args = [
        "--qemu-config=$(location //score/os/ubuntu_x86_64:qemu_config)",
        "--qemu-disk=$(location :qemu_disk_image)",
        "--qemu-rootfs=$(location //score/os/ubuntu_x86_64:image)",
    ],
    data = [
        ":qemu_disk_image",
        "//score/os/ubuntu_x86_64:image",
        "//score/os/ubuntu_x86_64:qemu_config",
        "//score/os/ubuntu_x86_64:ssh_target_key",
    ],
    plugins = ["@score_itf//score/itf/plugins:qemu_plugin"],
    tags = ["qemu-integration"],
    target_compatible_with = ["@platforms//os:linux"],
)

py_itf_test(
    name = "ebclfsa_qemu_opt_mount_test",
    srcs = ["test_opt_mount.py"],
    args = [
        "--qemu-config=$(location //score/os/ebclfsa_aarch64:qemu_config)",
        "--qemu-disk=$(location :qemu_disk_image)",
        "--qemu-kernel=$(location //score/os/ebclfsa_aarch64:kernel)",
        "--qemu-rootfs=$(location //score/os/ebclfsa_aarch64:image)",
    ],
    data = [
        ":qemu_disk_image",
        "//score/os/ebclfsa_aarch64:image",
        "//score/os/ebclfsa_aarch64:kernel",
        "//score/os/ebclfsa_aarch64:qemu_config",
        "//score/os/ebclfsa_aarch64:ssh_target_key",
    ],
    plugins = ["@score_itf//score/itf/plugins:qemu_plugin"],
    # Building the image takes long, so the test only runs when selected
    # explicitly, see .github/workflows/ebclfsa.yml.
    tags = [
        "manual",
        "qemu-integration",
    ],
    target_compatible_with = ["@platforms//os:linux"],
)

py_itf_test(
    name = "ebclfsa_prebuild_opt_mount_qemu_test",
    srcs = [
        "test_opt_mount.py",
    ],
    args = [
        "--qemu-config=$(location //score/tests/ebclfsa_aarch64_prebuild:qemu_config)",
        "--qemu-disk=$(location :qemu_disk_image)",
        "--qemu-kernel=$(location //score/tests/ebclfsa_aarch64_prebuild:kernel)",
        "--qemu-rootfs=$(location //score/tests/ebclfsa_aarch64_prebuild:image)",
    ],
    data = [
        ":qemu_disk_image",
        "//score/tests/ebclfsa_aarch64_prebuild:image",
        "//score/tests/ebclfsa_aarch64_prebuild:kernel",
        "//score/tests/ebclfsa_aarch64_prebuild:qemu_config",
        "//score/tests/ebclfsa_aarch64_prebuild:ssh_target_key",
    ],
    plugins = ["@score_itf//score/itf/plugins:qemu_plugin"],
    tags = [
        "qemu-integration",
    ],
    target_compatible_with = ["@platforms//os:linux"],
)
