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
It neither downloads nor boots a prebuilt disk image. The toolkit
still supplies precompiled system packages, including the kernel; this is an
image build from packages, not a source rebuild of the entire OS.

```console
$ bazel build //score/os/ebclfsa_aarch64:image //score/os/ebclfsa_aarch64:kernel
```

The build takes a long time, so all image targets are tagged `manual` and are
only built when selected explicitly.

| Target | Content |
| --- | --- |
| `:image` | The `.wic` disk image |
| `:kernel` | The kernel required to boot the image |
| `:qemu_config` | Generated QEMU configuration with the image's SSH key path |
| `:ssh_target_key` | Development private key generated with the image |
| `:network_config_deb` | The `score-network-config` Debian package |
| `:ssh_host_keys_deb` | Generated SSH server host keys as a Debian package |

## Requirements

- An x86_64 Linux host with Docker, `dpkg-deb` (from `dpkg`), `ssh-keygen`
  (from `openssh-client`), and permission to
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

The image uses the network configuration
([`network`](config-overlay/etc/config/network)): static
address `169.254.158.190/16` on `eth0`, gateway `169.254.21.88`, and a multicast
route. It also acquires an IPv4 address via DHCP on the same interface, and
prefers a DHCP-provided default gateway when available. The file is packaged as
`score-network-config`, which [kas.yml](kas.yml) selects through
`EBCLFSA_FASTDEV_NETWORK_CONFIG` in place of the toolkit's
`ebclfsa-fastdev-network` package. It therefore matches the addresses in
[`qemu_config.template.json`](qemu_config.template.json).

## Selecting packages

Edit `IMAGE_PACKAGES` in [BUILD](BUILD) to select the Debian packages installed in
the image. The [build script](build_image.sh) accepts zero or more Debian package
paths after its three fixed arguments:

```console
$ bash score/os/ebclfsa_aarch64/build_image.sh \
    /path/to/toolkit score/os/ebclfsa_aarch64/kas.yml \
    /existing/output/directory \
    /path/to/first.deb "/path/to/another package.deb"
```

Each package is copied into its own generated `dpkg-prebuilt` recipe in a
temporary workspace, and a generated KAS fragment adds all package names, read
from the Debian control metadata, to `IMAGE_INSTALL`. Duplicate package names are
rejected. Packages must be compatible with the arm64 image, and their
dependencies must be available from the configured repositories or supplied in
the same list.

The `score-itf-ssh-host-keys` package supplies RSA, ECDSA and Ed25519 host
key pairs at build time, replacing the toolkit's empty private-key placeholders.
This avoids generating them at boot. Images built from the same package share
these keys; Bazel may reuse the package across builds. The private keys are
present in the disk image and build outputs, so they are not secret and must
not be trusted for host authentication. Use these images only for isolated
testing. Generate unique host keys for each device before any non-test use.

## Tests

The ping, multicast, SSH authentication, no-disk, and DHCP QEMU integration
tests are tagged `manual`, so
`bazel test --config=qemu-integration //score/tests/...` does not build this image:

```console
$ bazel test --config=qemu-integration //score/tests:ebclfsa_aarch64_qemu_tests
```

The [EBcLfSA workflow](../../../.github/workflows/ebclfsa.yml)
builds the image and runs these tests when files of this package, the shared
network or QEMU configuration, or the tests change. It can also be started manually.

## Release images and SDKs

The [release workflow](../../../.github/workflows/release.yml) runs when a GitHub
release is published, including prereleases. It checks out the release tag and
builds `score-image` and its matching SDK for QEMU aarch64 (`ebcl-qemuarm64`)
and Raspberry Pi 4B (`rpi4b`).

The same builds can be run locally:

```console
$ bazel build //score/os/ebclfsa_aarch64:release-ebcl-qemuarm64 //score/os/ebclfsa_aarch64:release-rpi4b
```

Outputs are written to `bazel-bin/score/os/ebclfsa_aarch64/release/<machine>/`.
For each machine, the workflow attaches these assets to the existing release,
following the upstream toolkit's archive layout:

- `score-image-trixie-ebclfsa-<machine>.tar.gz`: disk image, kernel, image
  SPDX metadata and the generated development SSH private key.
- `score-image-sdk-trixie-ebclfsa-<machine>.tar.gz`: cross-compilation SDK sysroot.
- `score-image-sdk-trixie-ebclfsa-<machine>.spdx.json`: SDK SPDX metadata.
- `score-image-trixie-ebclfsa-<machine>.sha256`: checksums of the three assets.

The Raspberry Pi build uses the toolkit's Raspberry Pi BSP and fstab configuration,
but expects an already provisioned AArch64 EBBR firmware platform and uses a
systemd-boot EFI partition. The QEMU build retains the toolkit's bare-metal disk
layout; the additional `/opt` disk mount is QEMU-only. Both images
retain the S-CORE network configuration and passwordless root SSH login described
above and are **for integration testing, not production**.

Each image archive includes `score-image-trixie-ebclfsa-<machine>-ssh-target-key`,
whose public key is installed in root's `authorized_keys`. After extracting the
archive, connect using the key for that image build:

```console
$ chmod 600 score-image-trixie-ebclfsa-ebcl-qemuarm64-ssh-target-key
$ ssh -o IdentitiesOnly=yes -i score-image-trixie-ebclfsa-ebcl-qemuarm64-ssh-target-key root@169.254.158.190
```

For Raspberry Pi, use the `rpi4b` key instead and the device's reachable IP
address. Key-based login is the only means to login via SSH.
These keys are deliberately public development credentials: anyone downloading
the release can log in as root on a reachable image. Use only on isolated test
networks, never reuse the keys elsewhere, and replace the authorized key and
disable passwordless login before any non-test deployment. SSH server host
private keys are included in the disk image inside each archive.

Both platform builds must succeed before any assets are published. Re-running a
successful workflow replaces assets with the same names. If releases are created
by another workflow using `GITHUB_TOKEN`, GitHub will not trigger this workflow;
use a GitHub App token or personal access token for that release creation instead.
