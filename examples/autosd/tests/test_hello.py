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

import time

ARCHIVE = "/tmp/example.oci"


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


# Tests run in file order on the same target: switch to the example image first.
def test_bootc_switch(target, bootc_oci_archive):
    target.upload(bootc_oci_archive, ARCHIVE)

    rc, out = target.execute(f"bootc switch --transport oci-archive {ARCHIVE}")
    assert rc == 0, out.decode()

    _reboot_and_wait(target)


def test_hello(target):
    rc, out = target.execute("hello")

    assert rc == 0, out.decode()
    assert out.decode().strip() == "Hello from S-CORE on AutoSD!"
