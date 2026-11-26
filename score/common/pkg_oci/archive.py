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

import argparse
import os
import tarfile


def _normalize(info):
    info.mtime = 0
    info.uid = info.gid = 0
    info.uname = info.gname = ""
    info.mode = 0o755 if info.isdir() else 0o644

    return info


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "layout_dir", help="OCI image layout directory (oci-layout, index.json, blobs/)"
    )
    parser.add_argument("output", help="Output oci-archive tar file")
    args = parser.parse_args()

    if not os.path.isfile(os.path.join(args.layout_dir, "oci-layout")):
        raise SystemExit(
            f"{args.layout_dir} is not an OCI image layout (missing oci-layout)"
        )

    with tarfile.open(
        args.output, "w", format=tarfile.PAX_FORMAT, dereference=True
    ) as tar:
        for root, dirs, files in os.walk(args.layout_dir, followlinks=True):
            dirs.sort()
            for name in sorted(dirs) + sorted(files):
                path = os.path.join(root, name)
                arcname = os.path.relpath(path, args.layout_dir)
                info = _normalize(tar.gettarinfo(path, arcname))

                if info.isfile():
                    with open(path, "rb") as f:
                        tar.addfile(info, f)
                else:
                    tar.addfile(info)


if __name__ == "__main__":
    main()
