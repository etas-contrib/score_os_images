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
"""Verifies that an additional disk passed via ``--qemu-disk`` is mounted on
/opt automatically, without any help from the test code.
"""

# The additional disk is always attached as the second virtio block device, the
# root filesystem occupies the first one.
DISK_DEVICE = "/dev/vdb"
MOUNT_POINT = "/opt"
CONTENT_FILE = f"{MOUNT_POINT}/qemu_disk_content.txt"
EXPECTED_CONTENT = "Hello from the QEMU disk image!"


def test_disk_device_is_visible(target):
    exit_code, _ = target.execute(f"test -b {DISK_DEVICE}")
    assert exit_code == 0, f"Expected block device {DISK_DEVICE} to be present"


def test_disk_is_mounted_on_opt(target):
    exit_code, _ = target.execute(
        f"grep -q '^{DISK_DEVICE} {MOUNT_POINT} ' /proc/mounts"
    )
    assert exit_code == 0, f"{DISK_DEVICE} is not mounted on {MOUNT_POINT}"


def test_opt_contains_disk_content(target):
    exit_code, output = target.execute(f"cat {CONTENT_FILE}")
    assert exit_code == 0, f"{CONTENT_FILE} is not readable"
    assert output.decode("utf-8").strip() == EXPECTED_CONTENT


def test_opt_is_writable(target):
    exit_code, _ = target.execute(f"touch {MOUNT_POINT}/should_be_writable")
    assert exit_code == 0, f"{MOUNT_POINT} should be mounted read-write"
