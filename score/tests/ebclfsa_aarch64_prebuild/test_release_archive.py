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

import io
import os
from pathlib import Path
import subprocess
import sys
import tarfile
import tempfile
import unittest


class ReleaseArchiveTest(unittest.TestCase):
    def setUp(self):
        test_tmpdir = os.environ.get("TEST_TMPDIR")
        self.assertTrue(
            test_tmpdir, "run this test through Bazel (TEST_TMPDIR is required)"
        )
        self.tempdir = tempfile.TemporaryDirectory(dir=test_tmpdir)
        self.addCleanup(self.tempdir.cleanup)
        self.root = Path(self.tempdir.name)
        self.helper = Path(sys.argv[1])

    def _archive(self, members, name="release.tar.gz"):
        archive = self.root / name
        with tarfile.open(archive, "w:gz") as tar:
            for member_name, contents in members:
                info = tarfile.TarInfo(member_name)
                if contents is None:
                    info.type = tarfile.SYMTYPE
                    info.linkname = "release-kernel"
                    tar.addfile(info)
                else:
                    data = contents.encode()
                    info.size = len(data)
                    tar.addfile(info, io.BytesIO(data))
        return archive

    def _run_helper(self, members, *options):
        archive = self._archive(members)
        output = self.root / "output"
        result = subprocess.run(
            [sys.executable, str(self.helper), str(archive), str(output), *options],
            check=False,
            capture_output=True,
            text=True,
        )
        return result, output

    def test_extracts_only_matching_image_kernel_and_key_to_normalized_names(self):
        result, output = self._run_helper(
            [
                ("score-release.wic", "wic bytes"),
                ("score-release-vmlinux", "kernel bytes"),
                ("score-release-ssh-target-key", "key bytes"),
                ("score-release.spdx.json", "{}"),
                ("README.txt", "release metadata"),
            ]
        )

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            sorted(path.name for path in output.iterdir()),
            ["ssh_target_key", "vanilla-vmlinux", "vanilla.wic"],
        )
        self.assertEqual((output / "vanilla.wic").read_bytes(), b"wic bytes")
        self.assertEqual((output / "vanilla-vmlinux").read_bytes(), b"kernel bytes")
        self.assertEqual((output / "ssh_target_key").read_bytes(), b"key bytes")

    def test_override_mode_does_not_require_or_extract_archive_key(self):
        result, output = self._run_helper(
            [
                ("score-release.wic", "wic bytes"),
                ("score-release-vmlinux", "kernel bytes"),
            ],
            "--without-key",
        )

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            sorted(path.name for path in output.iterdir()),
            ["vanilla-vmlinux", "vanilla.wic"],
        )

    def test_rejects_missing_ambiguous_mismatched_and_unsafe_members(self):
        cases = [
            (
                "missing image",
                [
                    ("score-release-vmlinux", "kernel"),
                    ("score-release-ssh-target-key", "key"),
                ],
                "missing .wic",
            ),
            (
                "ambiguous image",
                [
                    ("first.wic", "one"),
                    ("second.wic", "two"),
                    ("first-vmlinux", "kernel"),
                    ("first-ssh-target-key", "key"),
                ],
                "ambiguous .wic",
            ),
            (
                "missing matching kernel",
                [
                    ("score-release.wic", "wic"),
                    ("score-release-ssh-target-key", "key"),
                ],
                "missing matching -vmlinux",
            ),
            (
                "mismatched kernel",
                [
                    ("score-release.wic", "wic"),
                    ("other-release-vmlinux", "kernel"),
                    ("score-release-ssh-target-key", "key"),
                ],
                "mismatched",
            ),
            (
                "missing key",
                [
                    ("score-release.wic", "wic"),
                    ("score-release-vmlinux", "kernel"),
                ],
                "missing matching -ssh-target-key",
            ),
            (
                "mismatched key",
                [
                    ("score-release.wic", "wic"),
                    ("score-release-vmlinux", "kernel"),
                    ("other-release-ssh-target-key", "key"),
                ],
                "mismatched",
            ),
            (
                "unsafe member path",
                [
                    ("../score-release.wic", "wic"),
                    ("score-release-vmlinux", "kernel"),
                    ("score-release-ssh-target-key", "key"),
                ],
                "unsafe archive path",
            ),
            (
                "nested member path",
                [
                    ("release/score-release.wic", "wic"),
                    ("score-release-vmlinux", "kernel"),
                    ("score-release-ssh-target-key", "key"),
                ],
                "archive is not flat",
            ),
            (
                "non-regular image",
                [
                    ("score-release.wic", None),
                    ("score-release-vmlinux", "kernel"),
                    ("score-release-ssh-target-key", "key"),
                ],
                "unsupported archive entry type",
            ),
        ]

        for case_name, members, diagnostic in cases:
            with self.subTest(case=case_name):
                result, output = self._run_helper(members)
                self.assertEqual(result.returncode, 1, result.stderr)
                self.assertIn("extract_release_archive:", result.stderr)
                self.assertIn(diagnostic, result.stderr)
                if output.exists():
                    self.assertEqual(list(output.iterdir()), [])


if __name__ == "__main__":
    unittest.main(argv=[sys.argv[0]])
