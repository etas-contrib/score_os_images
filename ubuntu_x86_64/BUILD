# *******************************************************************************
# Copyright (c) 2025 Contributors to the Eclipse Foundation
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

load("//:qemu_config.bzl", "qemu_config")

exports_files(
    [
        "build_image.sh",
    ],
    visibility = ["//visibility:public"],
)

genrule(
    name = "ssh-key-pair",
    outs = [
        "ssh/id_ed25519",
        "ssh/id_ed25519.pub",
    ],
    cmd = "umask 077; ssh-keygen -q -t ed25519 -N '' -C score-itf-development -f $(location ssh/id_ed25519)",
    visibility = ["//visibility:private"],
)

filegroup(
    name = "ssh_target_key",
    srcs = [":ssh/id_ed25519"],
    visibility = ["//visibility:public"],
)

genrule(
    name = "cloud-init-user-data",
    srcs = [
        "cloud-init/user-data",
        ":ssh/id_ed25519.pub",
    ],
    outs = ["cloud-init-rendered/user-data"],
    cmd = """sed "s|@SSH_AUTHORIZED_KEY@|$$(cat $(location :ssh/id_ed25519.pub))|" $(location cloud-init/user-data) > $@""",
    visibility = ["//visibility:private"],
)

genrule(
    name = "itf-image",
    srcs = [
        ":cloud-init-user-data",
        ":qemu_config",
        "cloud-init/meta-data",
        "@ubuntu_noble_minimal_cloudimg_amd64//file",
        "build_image.sh",
    ],
    outs = ["ubuntu-x86_64-itf/ubuntu-24.04-minimal-cloudimg-amd64.img"],
    cmd = """
        bash $(location :build_image.sh) \
            $(RULEDIR) \
            $(location @ubuntu_noble_minimal_cloudimg_amd64//file) \
            $(RULEDIR)/ubuntu-x86_64-itf/ubuntu-24.04-minimal-cloudimg-amd64.img \
            $(location :cloud-init-user-data) \
            $(location cloud-init/meta-data) \
            $(location :qemu_config)
    """,
    tags = [
        "manual",
    ],
    visibility = ["//visibility:private"],
)

filegroup(
    name = "image",
    srcs = [":ubuntu-x86_64-itf/ubuntu-24.04-minimal-cloudimg-amd64.img"],
    tags = [
        "manual",
    ],
    visibility = ["//visibility:public"],
)

filegroup(
    name = "vanilla-image",
    srcs = ["@ubuntu_noble_minimal_cloudimg_amd64//file"],
    tags = [
        "manual",
    ],
    visibility = ["//visibility:public"],
)

qemu_config(
    name = "qemu_config",
    out = "qemu_config.json",
    key = ":ssh_target_key",
    template = "qemu_config.template.json",
    visibility = ["//visibility:public"],
)

filegroup(
    name = "cloud_init",
    srcs = [
        "cloud-init/meta-data",
        ":cloud-init-user-data",
    ],
    visibility = ["//visibility:public"],
)
