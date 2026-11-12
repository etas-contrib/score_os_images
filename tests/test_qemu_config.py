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

import json
import sys
import unittest


class QemuConfigTest(unittest.TestCase):
    def test_configs_have_required_fields(self):
        config_paths = sys.argv[1:]
        self.assertEqual(len(config_paths), 3)

        for config_path in config_paths:
            with self.subTest(config_path=config_path):
                with open(config_path, encoding="utf-8") as config_file:
                    config = json.load(config_file)

                self.assertIsInstance(config["networks"], list)
                self.assertTrue(config["networks"])
                self.assertGreater(config["ssh_port"], 0)
                self.assertGreater(config["qemu_num_cores"], 0)
                self.assertTrue(config["qemu_ram_size"])
                self.assertTrue(config["qemu_machine"])


if __name__ == "__main__":
    unittest.main(argv=[sys.argv[0]])
