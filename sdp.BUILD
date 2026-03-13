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

"""Default BUILD file for QNX SDP archives.

This file is shipped with score_rules_imagefs so that consumers do not need
to provide their own BUILD file for the standard QNX SDP directory layout.
It can be overridden by passing a custom `build_file` to the `imagefs.sdp` tag.
"""

package(default_visibility = [
    "//visibility:public",
])

filegroup(
    name = "all_files",
    srcs = glob(["*/**/*"]),
)

filegroup(
    name = "target_dir",
    srcs = ["target/qnx"],
)

filegroup(
    name = "host_dir",
    srcs = ["host/linux/x86_64"],
)

filegroup(
    name = "target_all",
    srcs = glob(["target/**/*"]),
)

filegroup(
    name = "host_all",
    srcs = glob(["host/**/*"]),
)

filegroup(
    name = "mkifs",
    srcs = ["host/linux/x86_64/usr/bin/mkifs"],
)

filegroup(
    name = "mkfatfs",
    srcs = ["host/linux/x86_64/usr/bin/mkfatfsimg"],
)

filegroup(
    name = "mkqnx6fs",
    srcs = ["host/linux/x86_64/usr/bin/mkqnx6fsimg"],
)

filegroup(
    name = "mkdiskimage",
    srcs = ["host/linux/x86_64/usr/bin/diskimage"],
)
