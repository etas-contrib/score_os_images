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

""" Module rule for defining GCC toolchains in Bazel.
"""

load("@score_bazel_cpp_toolchains//rules:common.bzl", "get_flag_groups")

def _impl(rctx):
    """ Implementation of the gcc_toolchain repository rule.

    Args:
        rctx: The repository context.
    """
    tc_identifier = "gcc_{}".format(rctx.attr.gcc_version)
    if rctx.attr.tc_os == "qnx":
        tc_identifier = "sdp_{}".format(rctx.attr.sdp_version)

    rctx.template(
        "BUILD",
        rctx.attr._cc_toolchain_gcc_build,
        {
            "%{tc_pkg_repo}": rctx.attr.tc_pkg_repo,
            "%{tc_cpu}": rctx.attr.tc_cpu,
            "%{tc_os}": rctx.attr.tc_os,
            "%{tc_version}": rctx.attr.gcc_version,
            "%{tc_identifier}": tc_identifier, 
            "%{tc_runtime_es}": rctx.attr.tc_runtime_ecosystem,
        },
    )

    extra_compile_flags = get_flag_groups(rctx.attr.extra_compile_flags)
    extra_link_flags = get_flag_groups(rctx.attr.extra_link_flags)

    rctx.template(
        "cc_toolchain_config.bzl",
        rctx.attr._cc_toolchain_config,
        {
            "%{tc_version}": rctx.attr.gcc_version,
            "%{tc_identifier}": "gcc",
            "%{tc_runtime_es}": rctx.attr.tc_runtime_ecosystem,
            "%{extra_compile_flags_switch}": "True" if len(rctx.attr.extra_compile_flags) else "False",
            "%{extra_compile_flags}":extra_compile_flags,
            "%{extra_link_flags_switch}": "True" if len(rctx.attr.extra_link_flags) else "False",
            "%{extra_link_flags}": extra_link_flags,
        },
    )

    rctx.template(
        "flags.bzl",
        rctx.attr._cc_toolchain_flags,
        {},
    )

gcc_toolchain = repository_rule(
    implementation = _impl,
    attrs = {
        "tc_pkg_repo": attr.string(doc="The label name of toolchain tarbal."),
        "tc_cpu": attr.string(doc="Target platform CPU."),
        "tc_os": attr.string(doc="Target platform OS."),
        "gcc_version": attr.string(doc="GCC version number"),
        "extra_compile_flags": attr.string_list(doc="Extra/Additional compile flags."),
        "extra_link_flags": attr.string_list(doc="Extra/Additional link flags."),
        "sdp_version": attr.string(doc="SDP version number"),
        "license_path": attr.string(doc="Lincese path"),
        "license_info_variable": attr.string(doc="License info variable name (custom settings)"),
        "license_info_value": attr.string(doc="License info value (custom settings)"),
        "tc_runtime_ecosystem": attr.string(doc="Runtime ecosystem."),
        "tc_system_toolchain": attr.bool(doc="Boolean flag to state if this is a system toolchain"),
        "_cc_toolchain_config": attr.label(
            default = "@score_bazel_cpp_toolchains//templates:cc_toolchain_config.bzl.template",
            doc = "Path to the cc_config.bzl template file.",
        ),
        "_cc_toolchain_gcc_build": attr.label(
            default = "@score_bazel_cpp_toolchains//templates:BUILD.template",
            doc = "Path to the Bazel BUILD file template for the toolchain.",
        ),
        "_cc_toolchain_flags": attr.label(
            default = "@score_bazel_cpp_toolchains//templates:flags.bzl.template",
            doc = "Path to the Bazel BUILD file template for the toolchain.",
        ),
    },
)