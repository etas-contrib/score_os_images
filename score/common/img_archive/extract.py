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

import sys
import lzma
import shutil


def get_params():
    """Return a tuple with $source,$dest"""

    if len(sys.argv) < 3:
        sys.exit("Usage: {} <input.xz> <output>".format(sys.argv[0]))

    return sys.argv[1], sys.argv[2]


def extract(in_path, out_path):
    """Extract xz archive"""

    with lzma.open(in_path, "r") as in_file, open(out_path, "wb") as out_file:
        shutil.copyfileobj(in_file, out_file)


def main():
    """Runs everything (for __main__)"""

    src, dest = get_params()
    extract(src, dest)


if __name__ == "__main__":
    main()
