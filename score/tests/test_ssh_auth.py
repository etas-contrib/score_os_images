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

import paramiko
import pytest


def test_root_password_is_not_empty(target):
    exit_code, output = target.execute(
        """awk -F: '$1 == "root" {print length($2)}' /etc/shadow"""
    )
    assert exit_code == 0
    assert int(output.strip()) > 0, "The root password must not be empty"


def test_passwordless_ssh_config_is_not_installed(target):
    exit_code, output = target.execute("/usr/sbin/sshd -T")
    assert exit_code == 0
    assert b"permitemptypasswords no" in output.splitlines()


def test_key_only_root_login(target):
    exit_code, output = target.execute("passwd -S root")
    assert exit_code == 0
    assert output.split()[1] == b"L", "Root password authentication must be locked"

    exit_code, output = target.execute("/usr/sbin/sshd -T")
    assert exit_code == 0
    settings = output.splitlines()
    for setting in (
        b"pubkeyauthentication yes",
        b"passwordauthentication no",
        b"kbdinteractiveauthentication no",
        b"permitemptypasswords no",
    ):
        assert setting in settings
    assert any(
        setting in settings
        for setting in (
            b"permitrootlogin prohibit-password",
            b"permitrootlogin without-password",
        )
    )


def test_empty_password_login_is_rejected(target, config):
    # The target fixture ensures SSH is ready before attempting authentication.
    with paramiko.SSHClient() as client:
        client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        with pytest.raises(paramiko.AuthenticationException):
            client.connect(
                hostname=config.qemu_config.networks[0].ip_address,
                port=config.qemu_config.ssh_port,
                username="root",
                password="",
                allow_agent=False,
                look_for_keys=False,
                timeout=5,
            )
