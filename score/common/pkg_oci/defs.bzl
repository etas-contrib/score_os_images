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

def _pkg_oci_impl(ctx):
    out = ctx.actions.declare_file(ctx.attr.name + ".oci")

    args = ctx.actions.args()
    args.add(ctx.file.oci_image.path)
    args.add(out)

    ctx.actions.run(
        executable = ctx.executable._tool,
        arguments = [args],
        inputs = [ctx.file.oci_image],
        outputs = [out],
        mnemonic = "PackageOci",
        progress_message = "Packing oci-archive %{output}",
    )

    return [DefaultInfo(files = depset([out]))]

pkg_oci = rule(
    implementation = _pkg_oci_impl,
    attrs = {
        "oci_image": attr.label(
            doc = "oci_image target (OCI layout directory).",
            allow_single_file = True,
            mandatory = True,
        ),
        "_tool": attr.label(
            default = Label("//score/common/pkg_oci:archive"),
            executable = True,
            cfg = "exec",
        ),
    },
)
