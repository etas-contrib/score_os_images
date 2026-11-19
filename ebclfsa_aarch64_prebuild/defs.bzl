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

"""Public macro for using EBcLfSA release archives as QEMU images."""

load("//:qemu_config.bzl", "qemu_config")

_EXTRACTOR = Label("//ebclfsa_aarch64_prebuild:extract_release_archive.py")
_BUILD_SCRIPT = Label("//ebclfsa_aarch64_prebuild:build_image.sh")
_QEMU_TEMPLATE = Label("//ebclfsa_aarch64:qemu_config.template.json")

def ebclfsa_aarch64_prebuild(base_image, packages = [], ssh_target_key = None, visibility = None):
    """Defines the standard QEMU image targets for an EBcLfSA release archive.

    Args:
        base_image: Label of the pinned release archive file.
        packages: Optional labels of Debian packages in dependency order (i.e. more independent packages first) to install into the image.
        ssh_target_key: Optional key label for archives without a bundled key.
        visibility: Visibility applied to the five public image targets.
    """
    public_visibility = visibility if visibility != None else ["//visibility:public"]

    if ssh_target_key == None:
        extraction_outs = [
            "base/vanilla.wic",
            "base/vanilla-vmlinux",
            "base/ssh_target_key",
        ]
        key_source = "base/ssh_target_key"
        extraction_option = ""
    else:
        extraction_outs = [
            "base/vanilla.wic",
            "base/vanilla-vmlinux",
        ]
        key_source = ssh_target_key
        extraction_option = " --without-key"

    native.genrule(
        name = "extract_base_image",
        srcs = [base_image],
        outs = extraction_outs,
        tools = [_EXTRACTOR],
        cmd = "python3 $(location %s) $(location %s) $(RULEDIR)/base%s" % (
            _EXTRACTOR,
            base_image,
            extraction_option,
        ),
        tags = ["manual"],
        visibility = ["//visibility:private"],
    )

    native.filegroup(
        name = "vanilla-image",
        srcs = ["base/vanilla.wic"],
        tags = ["manual"],
        visibility = public_visibility,
    )

    native.filegroup(
        name = "kernel",
        srcs = ["base/vanilla-vmlinux"],
        tags = ["manual"],
        visibility = public_visibility,
    )

    native.filegroup(
        name = "ssh_target_key",
        srcs = [key_source],
        visibility = public_visibility,
    )

    if packages:
        package_locations = [
            " $(location %s)" % package
            for package in packages
        ]
        native.genrule(
            name = "build_custom_image",
            srcs = [
                ":extract_base_image",
                ":ssh_target_key",
                _BUILD_SCRIPT,
            ] + packages,
            outs = [
                "customized/image.wic",
                "customized/kernel-vmlinux",
            ],
            cmd = "bash $(location %s) $(RULEDIR) $(RULEDIR)/base $(RULEDIR)/customized $(location :ssh_target_key)%s" % (
                _BUILD_SCRIPT,
                "".join(package_locations),
            ),
            tags = ["manual"],
            visibility = ["//visibility:private"],
        )
        image_source = [
            "customized/image.wic",
        ]
    else:
        native.alias(
            name = "image",
            actual = ":vanilla-image",
            tags = ["manual"],
            visibility = public_visibility,
        )

    if packages:
        native.filegroup(
            name = "image",
            srcs = image_source,
            tags = ["manual"],
            visibility = public_visibility,
        )

    qemu_config(
        name = "qemu_config",
        out = "qemu_config.json",
        key = ":ssh_target_key",
        template = _QEMU_TEMPLATE,
        visibility = public_visibility,
    )
