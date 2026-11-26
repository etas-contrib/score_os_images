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

import hashlib
import json
import os
from pathlib import Path
import sys
import tarfile
import unittest


class ReleaseMacroEmptyPackagesTest(unittest.TestCase):
    def test_image_is_vanilla_and_config_uses_key_runfile_path(self):
        image, vanilla, kernel, key, config, archive = map(Path, sys.argv[1:])

        self.assertTrue(os.path.samefile(image, vanilla))
        with tarfile.open(archive, "r:gz") as release:
            for output, member in (
                (vanilla, "score-image-trixie-ebclfsa-ebcl-qemuarm64.wic"),
                (kernel, "score-image-trixie-ebclfsa-ebcl-qemuarm64-vmlinux"),
                (key, "score-image-trixie-ebclfsa-ebcl-qemuarm64-ssh-target-key"),
            ):
                with self.subTest(member=member):
                    with (
                        release.extractfile(member) as original,
                        output.open("rb") as extracted,
                    ):
                        self.assertEqual(
                            hashlib.file_digest(extracted, "sha256").digest(),
                            hashlib.file_digest(original, "sha256").digest(),
                        )

        with config.open(encoding="utf-8") as config_file:
            qemu_config = json.load(config_file)
        if key.is_absolute():
            expected_key_path = key.relative_to(
                Path(os.environ["TEST_SRCDIR"])
            ).as_posix()
        else:
            expected_key_path = key.as_posix()
        self.assertEqual(qemu_config["ssh_auth"]["pkey_path"], expected_key_path)


if __name__ == "__main__":
    unittest.main(argv=[sys.argv[0]])
