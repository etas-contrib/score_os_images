# Copyright 2026 Elektrobit. All rights reserved.
# Copyright (c) 2026 Contributors to the Eclipse Foundation
#
# Derived from eb_corbos_toolkit's fastdev_1.0.bb.
# SPDX-License-Identifier: MIT
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

SUMMARY = "Eclipse S-CORE EBcLfSA image"
LICENSE = "CLOSED"

inherit ebclfsa_image

# Include BSP-specific image configuration if available
# (keep the next line empty - there is a bug in oelint that requires this)

# nooelint: oelint.file.requireinclude oelint.file.includenotfound
include recipes-images/fastdev/fastdev-bsp.inc

# Default values for qemu environment
EBCLFSA_FASTDEV_COMPATIBLE_MACHINE ?= "ebcl-qemuarm64"
EBCLFSA_FASTDEV_FSTAB_CONFIG ?= "ebclfsa-fastdev-fstab"
EBCLFSA_FASTDEV_NETWORK_CONFIG ?= "ebclfsa-fastdev-network"
EBCLFSA_FASTDEV_SERIAL_CONFIG ?= "ebclfsa-fastdev-crinit-getty"

IMAGE_FSTYPES = "wic"
WKS_FILE = "baremetal-${MACHINE}.wks.in"

KERNEL_IMAGE_PKG = "${EBCLFSA_FASTDEV_KERNEL_PKG}"

COMPATIBLE_MACHINE = "${EBCLFSA_FASTDEV_COMPATIBLE_MACHINE}"

EBCL_BOOTLOADER = "1"

require recipes-images/common/ebclfsa-common.inc

require recipes-images/common/ebclfsa-dev.inc

# Additional fastdev-specific config packages
IMAGE_INSTALL:append = " \
    ebclfsa-fastdev-crinit-earlysetup\
"

IMAGE_INSTALL:append = " \
    ebclfsa-hi-cflinit \
    ebclfsa-hi-demo \
"

# BSP-specific packages
IMAGE_INSTALL:append = " \
    ${EBCLFSA_FASTDEV_FSTAB_CONFIG} \
    ${EBCLFSA_FASTDEV_NETWORK_CONFIG} \
    ${EBCLFSA_FASTDEV_SERIAL_CONFIG} \
"

# Add included features to rootfs
IMAGE_INSTALL:append = " \
    ${EBCLFSA_FASTDEV_FEATURES_CONTENT} \
"

SDK_INSTALL:append = " \
    ${EBCLFSA_FASTDEV_FEATURE_SDK_CONTENT} \
"

UNWANTED_PKGS = " \
    linux-firmware \
    wireless-regdb \
"

# Do not update fstab when creating wic images
WIC_CREATE_EXTRA_ARGS:append = " --no-fstab-update"

# Allow passwordless root login for integration testing, not for production use.
# Appended so it runs after image_postprocess_accounts, which sets the toolkit's
# default root password.
ROOTFS_POSTPROCESS_COMMAND:append = " score_passwordless_root ${@'score_opt_mount' if d.getVar('MACHINE') == 'ebcl-qemuarm64' else ''}"
ROOTFS_POSTPROCESS_COMMAND:remove:class-sdk = "score_passwordless_root score_opt_mount"

score_passwordless_root() {
    sudo sed -i 's/^root:[^:]*:/root::/' '${ROOTFSDIR}/etc/shadow'
}

score_opt_mount() {
    printf '\n# Additional disk attached by the ITF QEMU plugin\n/dev/vdb\t/opt\tauto\tdefaults,nofail\t0\t0\n' | \
        sudo tee -a '${ROOTFSDIR}/etc/fstab' >/dev/null
}
