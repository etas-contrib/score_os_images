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

import paramiko
import pytest


def test_distro(target):
    expected = [
        b'NAME="Automotive Stream Distribution"',
        b'VERSION="10"',
        b'ID="autosd"',
        b'ID_LIKE="rhel fedora centos"',
        b'VERSION_ID="10"',
        b'PLATFORM_ID="platform:el10"',
        b'PRETTY_NAME="Automotive Stream Distribution 10"',
        b'ANSI_COLOR="0;31"',
        b'LOGO="fedora-logo-icon"',
        b'CPE_NAME="cpe:/o:centos:autosd:10"',
        b'HOME_URL="https://sig.centos.org/automotive/"',
        b'REDHAT_SUPPORT_PRODUCT="Automotive Stream Distribution"',
        b'REDHAT_SUPPORT_PRODUCT_VERSION="Automotive Stream Distribution 10"',
    ]
    rc, output = target.execute("cat /etc/os-release")

    assert 0 == rc
    assert expected == output.splitlines()


def test_bootc_deployment(target):
    rc, output = target.execute("bootc status --booted --format json")
    parsed = json.loads(output)

    assert 0 == rc
    assert "localhost/aib-" in parsed["spec"]["image"]["image"]
    assert "localhost/aib-" in parsed["status"]["booted"]["image"]["image"]["image"]
    assert "bootcHost" == parsed["status"]["type"]
