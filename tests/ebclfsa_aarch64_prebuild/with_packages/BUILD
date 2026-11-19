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
load("@rules_pkg//pkg:deb.bzl", "pkg_deb")
load("@rules_pkg//pkg:tar.bzl", "pkg_tar")

pkg_tar(
    name = "first_package_data",
    srcs = ["first.txt"],
    mode = "0644",
    package_dir = "/usr/share/os-images-test",
)

pkg_deb(
    name = "first_package",
    architecture = "all",
    data = ":first_package_data",
    description = "First package supplied by an external macro consumer",
    maintainer = "Test <test@example.com>",
    package = "external-first-test",
    version = "1.0",
)

pkg_tar(
    name = "second_package_data",
    srcs = ["second.txt"],
    mode = "0644",
    package_dir = "/usr/share/os-images-test",
)

pkg_deb(
    name = "second_package",
    architecture = "all",
    data = ":second_package_data",
    description = "Second package supplied by an external macro consumer",
    maintainer = "Test <test@example.com>",
    package = "external-second-test",
    version = "1.0",
)

ebclfsa_aarch64_prebuild(
    base_image = "@os_images_release_archive//file",
    packages = [
        ":first_package",
        ":second_package",
    ],
)

genrule(
    name = "macro_contract_check",
    srcs = [
        ":image",
        ":kernel",
        ":ssh_target_key",
        ":qemu_config",
        ":vanilla-image",
        "@os_images_release_archive//file",
    ],
    outs = ["macro_contract_check.txt"],
    cmd = """
        if cmp -s $(location :image) $(location :vanilla-image); then
            echo 'Customization did not change the release image' >&2
            exit 1
        fi
        tar -xOzf $(location @os_images_release_archive//file) score-image-trixie-ebclfsa-ebcl-qemuarm64.wic | cmp - $(location :vanilla-image)
        printf 'external consumer macro outputs verified\\n' > $@
    """,
    tags = ["qemu-integration"],
    visibility = ["//visibility:public"],
)
