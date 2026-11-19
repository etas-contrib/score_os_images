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

import pytest


@pytest.mark.parametrize("name", ["first", "second"])
def test_release_customization_installs_packages_and_payloads(target, name):
    status, output = target.execute(
        f"dpkg-query -W -f='${{Status}} ${{Version}}' external-{name}-test"
    )
    assert status == 0, output
    assert output == b"install ok installed 1.0"

    status, output = target.execute(f"cat /usr/share/os-images-test/{name}.txt")
    assert status == 0, output
    assert output == f"{name} release test payload\n".encode()


def test_release_customization_preserves_single_opt_mount(target):
    status, output = target.execute(
        """awk '$1 == "/dev/vdb" && $2 == "/opt" {count++} END {print count+0}' /etc/fstab"""
    )
    assert status == 0, output
    assert output.strip() == b"1"
