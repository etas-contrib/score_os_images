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
def test_vanilla_release_does_not_contain_custom_packages(target, name):
    status, output = target.execute(f"dpkg-query -W external-{name}-test 2>&1")
    assert status == 1, output
    assert b"no packages found matching" in output.lower()

    status, output = target.execute(f"test ! -e /usr/share/os-images-test/{name}.txt")
    assert status == 0, output
