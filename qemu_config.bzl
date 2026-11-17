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

def _qemu_config_impl(ctx):
    # Only the path is needed here. Tests explicitly include the key in data.
    ctx.actions.expand_template(
        template = ctx.file.template,
        output = ctx.outputs.out,
        substitutions = {"@SSH_KEY_PATH@": ctx.file.key.short_path},
    )
    return [DefaultInfo(files = depset([ctx.outputs.out]))]

qemu_config = rule(
    implementation = _qemu_config_impl,
    attrs = {
        "template": attr.label(allow_single_file = [".json"], mandatory = True),
        "key": attr.label(allow_single_file = True, mandatory = True),
        "out": attr.output(mandatory = True),
    },
)
