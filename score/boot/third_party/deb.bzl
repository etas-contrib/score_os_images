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
#
# Repository rule that makes the contents of a Debian/Ubuntu `.deb` package
# available as a Bazel repository.
#
# A `.deb` is an `ar` archive holding `debian-binary`, `control.tar.*` and
# `data.tar.*`; the installed files live in `data.tar.*`. The rule downloads the
# package, unpacks it with `ar`, extracts the data member and applies the given
# BUILD file, so targets can reference individual files (e.g. a binary shipped
# under `usr/lib/...`).
#
# Requires `ar` (binutils) on the host PATH at fetch time.

def _tar_members(name):
    return [name + ".tar" + ext for ext in [".zst", ".xz", ".gz", ".bz2", ".lzma", ""]]

def _deb_impl(repository_ctx):
    deb_file = "package.deb"
    repository_ctx.download(
        url = repository_ctx.attr.urls,
        output = deb_file,
        sha256 = repository_ctx.attr.sha256,
    )

    ar = repository_ctx.which("ar")
    if ar == None:
        fail("the 'deb' rule requires 'ar' (binutils) on the host PATH")

    result = repository_ctx.execute([ar, "x", deb_file])
    if result.return_code != 0:
        fail("failed to unpack %s with ar:\n%s" % (deb_file, result.stderr))

    # Locate and extract the data member (compression varies by distro/version).
    data_member = None
    for member in _tar_members("data"):
        if repository_ctx.path(member).exists:
            data_member = member
            break
    if data_member == None:
        fail("no data.tar member found in %s" % deb_file)

    repository_ctx.extract(archive = data_member)

    # Drop the download and the archive members; keep only the payload.
    for member in [deb_file, "debian-binary"] + _tar_members("data") + _tar_members("control"):
        path = repository_ctx.path(member)
        if path.exists:
            repository_ctx.delete(path)

    repository_ctx.symlink(repository_ctx.attr.build, "BUILD.bazel")

deb = repository_rule(
    implementation = _deb_impl,
    attrs = {
        "urls": attr.string_list(
            mandatory = True,
            doc = "URLs the .deb package is downloaded from (tried in order).",
        ),
        "build": attr.label(
            mandatory = True,
            allow_single_file = True,
            doc = "BUILD file applied to the extracted package contents.",
        ),
        "sha256": attr.string(
            mandatory = True,
            doc = "Expected SHA-256 of the .deb, keeps fetches reproducible.",
        ),
    },
    doc = "Exposes the contents of a Debian/Ubuntu .deb package as a repository.",
)
