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

import os
from pathlib import Path


def test_packaged_host_keys_survive_boot(target):
    built_keys = (
        Path(os.environ["TEST_SRCDIR"])
        / os.environ["TEST_WORKSPACE"]
        / "score"
        / "os"
        / "ebclfsa_aarch64"
        / "ssh-host-keys"
    )

    for algorithm in ("rsa", "ecdsa", "ed25519"):
        key = f"/etc/ssh/ssh_host_{algorithm}_key"

        # Check that key packages are installed
        exit_code, output = target.execute(f"dpkg-query -S {key} {key}.pub")
        assert exit_code == 0, output
        assert output.splitlines() == [
            f"score-itf-ssh-host-keys: {key}".encode(),
            f"score-itf-ssh-host-keys: {key}.pub".encode(),
        ]

        # Check file permissions
        exit_code, output = target.execute(f"stat -c '%U:%G %a' {key} {key}.pub")
        assert exit_code == 0, output
        assert output.splitlines() == [b"root:root 600", b"root:root 644"]

        # Check key content is the same as the built keys
        exit_code, private_public = target.execute(f"ssh-keygen -y -f {key}")
        assert exit_code == 0, private_public
        exit_code, public = target.execute(f"cat {key}.pub")
        assert exit_code == 0, public
        assert public == (built_keys / f"ssh_host_{algorithm}_key.pub").read_bytes()
        assert private_public.split()[:2] == public.split()[:2]
