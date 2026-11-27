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
# U-Boot boot partition files.
#
# `uboot_boot_files` collects the files U-Boot needs on a boot partition: the
# board's U-Boot binary and, optionally, a boot script. The binary is board
# specific, so each platform instantiates the rule with its own binary (see
# //score/boot/third_party/uboot) and adds it to its boot_disk.
#
# The rule provides PackageFilesInfo, placing the binary at `binary_name` and
# the script at boot.scr.

load("@rules_pkg//pkg:providers.bzl", "PackageFilesInfo")

def _uboot_boot_files_impl(ctx):
    binary = ctx.file.binary
    dest_src_map = {ctx.attr.binary_name: binary}

    script = ctx.file.boot_script
    if script:
        boot_scr = ctx.actions.declare_file(ctx.label.name + "/boot.scr")
        if script.extension == "scr":
            # Already compiled with mkimage, ship as-is.
            ctx.actions.symlink(output = boot_scr, target_file = script)
        else:
            # Compile with the host mkimage, via a script expanded from the
            # static compile_boot_script.sh.tpl template.
            compiler = ctx.actions.declare_file(ctx.label.name + "/compile_boot_script.sh")
            ctx.actions.expand_template(
                template = ctx.file._compile_template,
                output = compiler,
                substitutions = {"@@ARCH@@": ctx.attr.arch},
                is_executable = True,
            )
            ctx.actions.run(
                executable = compiler,
                arguments = [script.path, boot_scr.path],
                inputs = [script],
                outputs = [boot_scr],
                mnemonic = "UbootMkimage",
                progress_message = "Compiling U-Boot script %{label}",
                # mkimage is a host tool, found through PATH.
                use_default_shell_env = True,
            )
        dest_src_map["boot.scr"] = boot_scr

    return [
        DefaultInfo(files = depset(dest_src_map.values())),
        PackageFilesInfo(dest_src_map = dest_src_map, attributes = {}),
    ]

uboot_boot_files = rule(
    implementation = _uboot_boot_files_impl,
    attrs = {
        "binary": attr.label(
            mandatory = True,
            allow_single_file = True,
            doc = "Board specific U-Boot binary, e.g. //score/boot/third_party/uboot:rpi_arm64.",
        ),
        "binary_name": attr.string(
            default = "u-boot.bin",
            doc = "Path of the binary on the boot partition; must match what the " +
                  "board firmware loads (e.g. `kernel=` in the RPi config.txt).",
        ),
        "boot_script": attr.label(
            allow_single_file = True,
            doc = "Optional U-Boot script. Plain text sources are compiled with " +
                  "mkimage; a precompiled .scr is used as-is. Lands as boot.scr.",
        ),
        "arch": attr.string(
            default = "arm64",
            doc = "mkimage architecture for the compiled boot script.",
        ),
        "_compile_template": attr.label(
            default = Label("//score/boot/uboot:compile_boot_script.sh.tpl"),
            allow_single_file = True,
        ),
    },
    doc = "Files U-Boot needs on a boot partition: the binary and an optional boot.scr.",
)
