<!-- ----------------------------------------------------------------------------
  Copyright (c) 2026 Contributors to the Eclipse Foundation

  See the NOTICE file(s) distributed with this work for additional
  information regarding copyright ownership.

  This program and the accompanying materials are made available under the
  terms of the Apache License Version 2.0 which is available at
  https://www.apache.org/licenses/LICENSE-2.0

  SPDX-License-Identifier: Apache-2.0
----------------------------------------------------------------------------- -->
# EB corbos Linux for Safety Applications: image from scratch

Builds a new `score-image` aarch64 disk image with KAS/Isar.
The standalone [recipe](meta-score/recipes-images/score-image/score-image_1.0.bb)
is derived from the toolkit's
[`fastdev_1.0.bb`](https://github.com/Elektrobit/eb_corbos_toolkit/blob/fe2cddbc01232e4b62accb9abab783c8ccf75ef7/layers/meta-ebclfsa/meta-ebclfsa-public/meta-ebclfsa-public-images/recipes-images/fastdev/fastdev_1.0.bb),
without `ebclfsa-comfwdlib-sim` or `ebclfsa-li-demo`.
It retains `ebclfsa-hi-cflinit` and its mandatory `ebclfsa-hi-demo` application
for booting with the shared QEMU configuration.
[kas.yml](kas.yml) selects it instead of `fastdev`.
Unlike [`//ebclfsa_aarch64_prebuild`](../ebclfsa_aarch64_prebuild),
it neither downloads nor boots the toolkit's prebuilt disk image. The toolkit
still supplies precompiled system packages, including the kernel; this is an
image build from packages, not a source rebuild of the entire OS.

```console
$ bazel build //ebclfsa_aarch64:image //ebclfsa_aarch64:kernel
```

The build takes a long time, so all image targets are tagged `manual` and are
only built when selected explicitly. The kernel and `.wic` disk image are written
to `bazel-bin/ebclfsa_aarch64/`.

| Target | Content |
| --- | --- |
| `:image` | The `.wic` disk image |
| `:kernel` | The kernel required to boot the image |
| `:qemu_config` | QEMU configuration shared with `//ebclfsa_aarch64_prebuild` |
| `:network_config_deb` | The `score-network-config` Debian package |

## Requirements

- An x86_64 Linux host with Docker, `dpkg-deb` (from `dpkg`), and permission to
  run privileged containers. The Docker daemon must see the Bazel output
  directory at the same absolute path as the build process (no remote daemon).
- Network access to GitHub, GHCR and the package repositories referenced by the
  toolkit, and substantial free disk space for the Isar build.

The build runs the toolkit's digest-pinned development container. It registers
its aarch64 binfmt interpreter if none is registered; this requires privileged
access and affects the host kernel's binfmt registry. KAS/Isar needs privileges
for chroots and mounts, so the action cannot run in a Bazel sandbox or on a
remote executor.

## Network configuration

The image uses the same network configuration as `//ebclfsa_aarch64_prebuild`
([`network`](config-overlay/etc/config/network)): static
address `169.254.158.190/16` on `eth0`, gateway `169.254.21.88`, and a multicast
route. The file is packaged as `score-network-config`, which [kas.yml](kas.yml)
selects through `EBCLFSA_FASTDEV_NETWORK_CONFIG` in place of the toolkit's
`ebclfsa-fastdev-network` package. It therefore matches the addresses in
[`qemu_config.json`](qemu_config.json).

## Root SSH login

Like `//ebclfsa_aarch64_prebuild:image`, the image permits passwordless root SSH login for
integration testing. It must never be used in production.

- The `score-itf-sshd-config` package installs
  [`99-integration-test.conf`](sshd-config/99-integration-test.conf) into
  `/etc/ssh/sshd_config.d`.
- [`score-image_1.0.bb`](meta-score/recipes-images/score-image/score-image_1.0.bb)
  clears the root password at the end of the rootfs post-processing, after the
  toolkit has set its default password `linux`.

## /opt mount

A secondary disk image can be attached to the QEMU targets via the `--qemu-disk` option, in which case it is mounted on `/opt` inside the guest.
The image recipe adds `/dev/vdb` to `/etc/fstab` with `nofail`, so the image
also boots when no secondary disk is attached.

## Selecting packages

Edit `IMAGE_PACKAGES` in [BUILD](BUILD) to select the Debian packages installed in
the image. The [build script](build_image.sh) accepts zero or more Debian package
paths after its three fixed arguments:

```console
$ bash ebclfsa_aarch64/build_image.sh \
    /path/to/toolkit ebclfsa_aarch64/kas.yml \
    /existing/output/directory \
    /path/to/first.deb "/path/to/another package.deb"
```

Each package is copied into its own generated `dpkg-prebuilt` recipe in a
temporary workspace, and a generated KAS fragment adds all package names, read
from the Debian control metadata, to `IMAGE_INSTALL`. Duplicate package names are
rejected. Packages must be compatible with the arm64 image, and their
dependencies must be available from the configured repositories or supplied in
the same list.

## Tests

The ping, multicast and no-disk QEMU integration tests boot the image with
`:qemu_config`. The test is tagged `manual`, so
`bazel test --config=qemu-integration //tests/...` does not build this image:

```console
$ bazel test --config=qemu-integration //tests:ebclfsa_from_scratch_qemu_test //tests:ebclfsa_from_scratch_opt_mount_qemu_test
```

The [EBcLfSA workflow](../.github/workflows/ebclfsa.yml)
builds the image and runs these tests when files of this package, the shared
network or QEMU configuration, or the tests change. It can also be started manually.
