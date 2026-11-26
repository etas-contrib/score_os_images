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
"""QEMU configuration rendering without building the referenced image key."""

UefiPathInfo = provider(
    doc = "Host path to a UEFI firmware file.",
    fields = ["path"],
)

def _uefi_path_impl(ctx):
    return UefiPathInfo(path = ctx.build_setting_value)

uefi_path = rule(
    implementation = _uefi_path_impl,
    build_setting = config.string(flag = True),
)

def _qemu_config_impl(ctx):
    substitutions = {}

    if ctx.attr.uefi_code and ctx.attr.uefi_vars:
        substitutions["@UEFI_CODE@"] = ctx.attr.uefi_code[UefiPathInfo].path
        substitutions["@UEFI_VARS@"] = ctx.attr.uefi_vars[UefiPathInfo].path

    if ctx.file.key:
        # Only the path is needed here. Tests explicitly include the key in data.
        substitutions["@SSH_KEY_PATH@"] = ctx.file.key.short_path

    ctx.actions.expand_template(
        template = ctx.file.template,
        output = ctx.outputs.out,
        substitutions = substitutions,
    )
    return [DefaultInfo(files = depset([ctx.outputs.out]))]

qemu_config = rule(
    implementation = _qemu_config_impl,
    attrs = {
        "template": attr.label(allow_single_file = [".json"], mandatory = True),
        "key": attr.label(allow_single_file = True),
        "out": attr.output(mandatory = True),
        "uefi_code": attr.label(mandatory = False),
        "uefi_vars": attr.label(mandatory = False),
    },
)
