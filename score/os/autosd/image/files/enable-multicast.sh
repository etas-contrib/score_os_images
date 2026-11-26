#!/bin/bash
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

# Enable the MULTICAST link flag and add the 224.0.0.0/4 multicast route
# on the primary network interface (used for Zenoh/DDS multicast discovery).
set -euo pipefail

# Pick the interface that carries the default route; fall back to the first
# non-loopback interface if there is no default route yet.
IFACE="$(ip -o route show default 2>/dev/null | awk '{print $5; exit}')"
if [ -z "${IFACE:-}" ]; then
    IFACE="$(ip -o link show | awk -F': ' '$2 != "lo" {print $2; exit}')"
fi

if [ -z "${IFACE:-}" ]; then
    echo "enable-multicast: no usable network interface found" >&2
    exit 1
fi

echo "enable-multicast: configuring multicast on ${IFACE}"
ip link set dev "${IFACE}" multicast on
ip route replace 224.0.0.0/4 dev "${IFACE}"
