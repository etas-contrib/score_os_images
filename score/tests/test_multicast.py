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


def test_multicast_route_exists(target):
    """Verify that a route for the IPv4 multicast range 224.0.0.0/4 is present."""
    exit_code, output = target.execute("ip route show 224.0.0.0/4")
    if isinstance(output, bytes):
        output = output.decode()
    assert exit_code == 0, f"ip route show failed: {output}"
    assert "224.0.0.0" in output, (
        f"Multicast route not found in routing table: {output}"
    )


def test_network_interface_has_multicast_flag(target):
    """Verify that the primary network interface has the MULTICAST flag set."""
    exit_code, output = target.execute("ip link show | grep -i multicast")
    if isinstance(output, bytes):
        output = output.decode()
    assert exit_code == 0, f"No interfaces with MULTICAST flag found: {output}"
    assert "MULTICAST" in output, f"MULTICAST flag not found: {output}"
