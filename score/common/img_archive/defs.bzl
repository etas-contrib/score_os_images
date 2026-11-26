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

_SUPPORTED_FILES = [".xz"]

def _default_out(src):
    for ext in _SUPPORTED_FILES:
        if src.basename.endswith(ext):
            return src.basename.removesuffix(ext)
    fail("unsupported image archive: " + src.basename)

def _img_archive_impl(ctx):
    out = ctx.actions.declare_file(ctx.attr.out or _default_out(ctx.file.src))

    ctx.actions.run(
        executable = ctx.executable._tool,
        arguments = [ctx.file.src.path, out.path],
        inputs = [ctx.file.src],
        outputs = [out],
        mnemonic = "ImageArchive",
        progress_message = "Extracting %{input} to %{output}",
    )

    return [DefaultInfo(files = depset([out]))]

img_archive = rule(
    implementation = _img_archive_impl,
    attrs = {
        "src": attr.label(allow_single_file = _SUPPORTED_FILES, mandatory = True),
        "out": attr.string(doc = "Output file name, defaults to src without its archive extension"),
        "_tool": attr.label(
            default = Label("//score/common/img_archive:extract"),
            executable = True,
            cfg = "exec",
        ),
    },
)
