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
# Raw disk image with a single FAT boot partition.
#
# `boot_disk` is platform and boot system agnostic: a platform lists its
# firmware files, its config and a boot system (e.g. //score/boot/uboot) in
# `srcs`, and the rule lays them out on the partition.
#
# Placement on the partition:
#   * targets providing rules_pkg's PackageFilesInfo (pkg_files,
#     uboot_boot_files, ...) land at their destination paths, so subdirectories
#     (`pkg_files(prefix = "overlays")`) and renames work;
#   * any other file lands in the partition root under its basename.

load("@rules_pkg//pkg:providers.bzl", "PackageFilesInfo")

def _dest_src_pairs(target):
    if PackageFilesInfo in target:
        return target[PackageFilesInfo].dest_src_map.items()
    return [(f.basename, f) for f in target[DefaultInfo].files.to_list()]

def _boot_disk_impl(ctx):
    files = {}

    # FAT is case-insensitive; key by lower-cased destination to catch clashes.
    seen = {}
    for target in ctx.attr.srcs:
        for dest, src in _dest_src_pairs(target):
            dest = dest.lstrip("/")
            if "=" in dest:
                fail("boot file destination must not contain '=': " + dest)
            key = dest.lower()
            if key in seen and seen[key] != src:
                fail("two boot files map to '%s': %s and %s" % (dest, seen[key].path, src.path))
            seen[key] = src
            files[dest] = src

    # A file can't also be the parent directory of another file (foo + foo/bar).
    # Directory sources are fine as parents, their contents land below them.
    for key in seen:
        parts = key.split("/")
        for i in range(1, len(parts)):
            parent = "/".join(parts[:i])
            if parent in seen and not seen[parent].is_directory:
                fail("boot file %s maps to '%s', which is also the parent directory of %s ('%s')" % (
                    seen[parent].path,
                    parent,
                    seen[key].path,
                    key,
                ))

    out = ctx.actions.declare_file(ctx.attr.out or ctx.label.name + ".img")

    args = ctx.actions.args()
    args.add("--out", out)
    args.add("--partition-table", ctx.attr.partition_table)
    args.add("--offset-kib", ctx.attr.offset_kib)
    args.add("--size-mib", ctx.attr.size_mib)
    args.add("--fat-type", ctx.attr.fat_type)
    args.add("--label", ctx.attr.volume_label)
    for dest in sorted(files):
        args.add("%s=%s" % (dest, files[dest].path))

    ctx.actions.run(
        executable = ctx.executable._build_image,
        arguments = [args],
        inputs = files.values(),
        outputs = [out],
        mnemonic = "BootDisk",
        progress_message = "Assembling boot disk %{output}",
        # mtools and sfdisk are host tools, found through PATH.
        use_default_shell_env = True,
    )

    return [DefaultInfo(files = depset([out]))]

boot_disk = rule(
    implementation = _boot_disk_impl,
    attrs = {
        "srcs": attr.label_list(
            allow_files = True,
            doc = "Files placed on the boot partition, see the file header for placement.",
        ),
        "out": attr.string(doc = "Output image name, defaults to <name>.img."),
        "partition_table": attr.string(
            default = "mbr",
            values = ["mbr", "gpt"],
            doc = "`mbr` (bootable FAT partition) or `gpt` (EFI System Partition).",
        ),
        "offset_kib": attr.int(
            default = 1024,
            doc = "Offset of the boot partition in KiB.",
        ),
        "size_mib": attr.int(
            default = 128,
            doc = "Size of the boot partition in MiB (FAT32 needs >= 33).",
        ),
        "fat_type": attr.int(
            default = 32,
            values = [16, 32],
            doc = "FAT variant.",
        ),
        "volume_label": attr.string(
            default = "BOOT",
            doc = "FAT volume label (<= 11 characters), also the GPT partition name.",
        ),
        "_build_image": attr.label(
            default = Label("//score/common/boot_disk:build_image"),
            executable = True,
            cfg = "exec",
        ),
    },
    doc = "Raw disk image with a single FAT boot partition. Needs mtools and " +
          "util-linux (sfdisk) on the host.",
)
