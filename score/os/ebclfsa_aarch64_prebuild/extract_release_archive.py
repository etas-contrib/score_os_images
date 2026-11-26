#!/usr/bin/env python3
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

"""Validates and normalizes an EBcLfSA release archive for QEMU builds."""

import argparse
import shutil
import sys
import tarfile
from pathlib import Path, PurePosixPath


class ArchiveError(Exception):
    """Raised when an archive does not satisfy the supported release contract."""


def _safe_members(archive: tarfile.TarFile) -> dict[str, tarfile.TarInfo]:
    members = {}
    for member in archive.getmembers():
        name = member.name
        if "\\" in name:
            raise ArchiveError(f"unsafe archive path: {name!r}")

        path = PurePosixPath(name)
        if path.is_absolute() or ".." in path.parts:
            raise ArchiveError(f"unsafe archive path: {name!r}")

        parts = [part for part in path.parts if part not in ("", ".")]
        if not parts:
            if member.isdir():
                continue
            raise ArchiveError(f"unsafe archive path: {name!r}")
        if len(parts) != 1:
            raise ArchiveError(f"archive is not flat: {name!r}")

        filename = parts[0]
        if filename in members:
            raise ArchiveError(f"duplicate archive path: {filename!r}")
        if not member.isfile() and not member.isdir():
            raise ArchiveError(f"unsupported archive entry type: {name!r}")
        if member.isdir():
            continue
        members[filename] = member

    return members


def _unique_matching_file(members, suffix, description):
    matches = [name for name in members if name.endswith(suffix)]
    if not matches:
        raise ArchiveError(f"missing {description}")
    if len(matches) != 1:
        raise ArchiveError(f"ambiguous {description}: {', '.join(sorted(matches))}")
    return matches[0]


def extract(archive_path: Path, output_dir: Path, without_key: bool) -> None:
    try:
        archive = tarfile.open(archive_path, mode="r:*")
    except (OSError, tarfile.TarError) as error:
        raise ArchiveError(f"cannot read archive: {error}") from error

    with archive:
        members = _safe_members(archive)
        image_name = _unique_matching_file(members, ".wic", ".wic file")
        stem = image_name[:-4]
        kernel_name = stem + "-vmlinux"
        kernel_candidates = [name for name in members if name.endswith("-vmlinux")]
        if not kernel_candidates:
            raise ArchiveError(f"missing matching -vmlinux for {image_name}")
        if len(kernel_candidates) != 1:
            raise ArchiveError(
                "ambiguous -vmlinux: " + ", ".join(sorted(kernel_candidates))
            )
        if kernel_candidates[0] != kernel_name:
            raise ArchiveError(
                f"missing matching -vmlinux for {image_name}; mismatched candidate: "
                f"{kernel_candidates[0]}"
            )

        key_name = stem + "-ssh-target-key"
        key_candidates = [name for name in members if name.endswith("-ssh-target-key")]
        if without_key:
            if len(key_candidates) > 1:
                raise ArchiveError(
                    "ambiguous -ssh-target-key: " + ", ".join(sorted(key_candidates))
                )
            if key_candidates and key_candidates[0] != key_name:
                raise ArchiveError(
                    f"mismatched -ssh-target-key for {image_name}: "
                    f"{', '.join(sorted(key_candidates))}"
                )
        elif not key_candidates:
            raise ArchiveError(f"missing matching -ssh-target-key for {image_name}")
        elif len(key_candidates) != 1:
            raise ArchiveError(
                "ambiguous -ssh-target-key: " + ", ".join(sorted(key_candidates))
            )
        elif key_candidates[0] != key_name:
            raise ArchiveError(
                f"mismatched -ssh-target-key for {image_name}: {key_candidates[0]}"
            )

        output_dir.mkdir(parents=True, exist_ok=True)
        outputs = [
            (image_name, output_dir / "vanilla.wic"),
            (kernel_name, output_dir / "vanilla-vmlinux"),
        ]
        if not without_key:
            outputs.append((key_name, output_dir / "ssh_target_key"))

        for source_name, destination in outputs:
            source = archive.extractfile(members[source_name])
            if source is None:
                raise ArchiveError(f"cannot read archive member: {source_name}")
            with source, destination.open("wb") as target:
                shutil.copyfileobj(source, target)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", type=Path)
    parser.add_argument("output_dir", type=Path)
    parser.add_argument(
        "--without-key",
        action="store_true",
        help="use when an explicit SSH key override is supplied",
    )
    arguments = parser.parse_args()

    try:
        extract(arguments.archive, arguments.output_dir, arguments.without_key)
    except (ArchiveError, OSError, tarfile.TarError) as error:
        print(f"extract_release_archive: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
