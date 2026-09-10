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
"""Verifies that the automatic /opt mount does not break a target that is booted
without an additional disk.
"""

MOUNT_POINT = "/opt"


def test_no_second_block_device(target):
    exit_code, _ = target.execute("test -b /dev/vdb")
    assert exit_code != 0, "No additional disk was attached, /dev/vdb must not exist"


def test_opt_is_not_a_mount_point(target):
    exit_code, _ = target.execute(f"grep -q ' {MOUNT_POINT} ' /proc/mounts")
    assert exit_code != 0, (
        f"{MOUNT_POINT} must not be mounted without an additional disk"
    )


def test_opt_is_usable(target):
    exit_code, _ = target.execute(
        f"test -d {MOUNT_POINT} && touch {MOUNT_POINT}/should_be_writable"
    )
    assert exit_code == 0, f"{MOUNT_POINT} should still be a usable directory"
