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
import json
import time

import paramiko
import pytest


def _get_boot_id(target):
    rc, out = target.execute("cat /proc/sys/kernel/random/boot_id")
    assert rc == 0, out.decode()

    return out.decode().strip()


def _reboot_and_wait(target, timeout_s: int = 300) -> None:
    old_boot_id = _get_boot_id(target)

    rc, _ = target.execute("systemctl reboot")
    assert rc in (0, -1), f"reboot failed with rc={rc}"

    deadline = time.monotonic() + timeout_s
    while time.monotonic() < deadline:
        try:
            if _get_boot_id(target) != old_boot_id:
                return
        except Exception:
            pass

        time.sleep(5)
    raise TimeoutError(f"Target did not come back from reboot within {timeout_s}s")


def test_bootc_switch(target, bootc_oci_archive):
    target.upload(bootc_oci_archive, "/tmp/score.oci")

    rc, out = target.execute("bootc switch --transport oci-archive /tmp/score.oci")
    assert rc == 0

    _reboot_and_wait(target)

    rc, out = target.execute("bootc status --format json --booted")
    parsed = json.loads(out)
    assert rc == 0
    assert "/tmp/score.oci" == parsed["status"]["booted"]["image"]["image"]["image"]
