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

load("@os_images//ebclfsa_aarch64_prebuild:defs.bzl", "ebclfsa_aarch64_prebuild")
load("@rules_python//python:defs.bzl", "py_test")
load("@score_itf//:defs.bzl", "py_itf_test")

py_test(
    name = "release_archive_test",
    srcs = ["test_release_archive.py"],
    args = ["$(location //ebclfsa_aarch64_prebuild:extract_release_archive.py)"],
    data = ["//ebclfsa_aarch64_prebuild:extract_release_archive.py"],
    main = "test_release_archive.py",
)

ebclfsa_aarch64_prebuild(
    base_image = "@os_images_release_archive//file",
)

py_test(
    name = "release_macro_empty_test",
    srcs = ["test_release_macro_empty.py"],
    args = [
        "$(location :image)",
        "$(location :vanilla-image)",
        "$(location :kernel)",
        "$(location :ssh_target_key)",
        "$(location :qemu_config)",
        "$(location @os_images_release_archive//file)",
    ],
    data = [
        ":image",
        ":kernel",
        ":qemu_config",
        ":ssh_target_key",
        ":vanilla-image",
        "@os_images_release_archive//file",
    ],
    main = "test_release_macro_empty.py",
    tags = ["qemu-integration"],
)

py_itf_test(
    name = "release_macro_vanilla_qemu_test",
    srcs = ["test_release_vanilla.py"],
    args = [
        "--qemu-config=$(location :qemu_config)",
        "--qemu-kernel=$(location :kernel)",
        "--qemu-rootfs=$(location :vanilla-image)",
    ],
    data = [
        ":kernel",
        ":qemu_config",
        ":ssh_target_key",
        ":vanilla-image",
    ],
    plugins = ["@score_itf//score/itf/plugins:qemu_plugin"],
    tags = ["qemu-integration"],
    target_compatible_with = ["@platforms//os:linux"],
)

py_itf_test(
    name = "release_macro_packages_qemu_test",
    srcs = ["test_release_packages.py"],
    args = [
        "--qemu-config=$(location //tests/ebclfsa_aarch64_prebuild/with_packages:qemu_config)",
        "--qemu-kernel=$(location //tests/ebclfsa_aarch64_prebuild/with_packages:kernel)",
        "--qemu-rootfs=$(location //tests/ebclfsa_aarch64_prebuild/with_packages:image)",
    ],
    data = [
        "//tests/ebclfsa_aarch64_prebuild/with_packages:image",
        "//tests/ebclfsa_aarch64_prebuild/with_packages:kernel",
        "//tests/ebclfsa_aarch64_prebuild/with_packages:macro_contract_check",
        "//tests/ebclfsa_aarch64_prebuild/with_packages:qemu_config",
        "//tests/ebclfsa_aarch64_prebuild/with_packages:ssh_target_key",
    ],
    plugins = ["@score_itf//score/itf/plugins:qemu_plugin"],
    tags = ["qemu-integration"],
    target_compatible_with = ["@platforms//os:linux"],
)
