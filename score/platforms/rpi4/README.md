<!-- ----------------------------------------------------------------------------
  Copyright (c) 2026 Contributors to the Eclipse Foundation

  See the NOTICE file(s) distributed with this work for additional
  information regarding copyright ownership.

  This program and the accompanying materials are made available under the
  terms of the Apache License Version 2.0 which is available at
  https://www.apache.org/licenses/LICENSE-2.0

  SPDX-License-Identifier: Apache-2.0
----------------------------------------------------------------------------- -->
Raspberry Pi 4 U-Boot boot disk
===============================

This target builds a small **SD card image** for the Raspberry Pi 4 that only
carries the boot firmware and U-Boot. It deliberately contains **no operating
system**: U-Boot provides a UEFI (EBBR) environment and boots the actual OS from
a **separate USB stick**.

```
 SD card (this image)            USB stick (built elsewhere)
 ┌───────────────────────┐      ┌───────────────────────────┐
 │ FAT boot partition     │      │ the real OS image          │
 │  - start4.elf          │      │  (e.g. the AutoSD disk)    │
 │  - fixup4.dat          │ ───▶ │                            │
 │  - bcm2711-rpi-4-b.dtb │ UEFI │                            │
 │  - u-boot.bin          │      │                            │
 │  - config.txt          │      │                            │
 └───────────────────────┘      └───────────────────────────┘
```

Boot flow: the Pi4 GPU firmware reads `config.txt`, loads `u-boot.bin` as the
"kernel", and U-Boot's UEFI implementation then finds and boots the OS on USB.

## Building

```
bazel build //score/platforms/rpi4:image
```

The resulting raw image is `bazel-bin/score/platforms/rpi4/rpi4-boot.img`.
Flash it to an SD card, e.g.:

```
sudo dd if=bazel-bin/score/platforms/rpi4/rpi4-boot.img of=/dev/sdX bs=4M conv=fsync status=progress
```

The image is assembled **unprivileged** (no loop mounts / no root) by the
generic [`boot_disk`](../../common/boot_disk/defs.bzl) rule, using `mtools`
(`mformat`, `mcopy`, `mmd`) and `sfdisk` from `util-linux`. Fetching U-Boot
needs `ar` (binutils). Make sure those are installed on the build host.

## How the target is put together

[`BUILD.bazel`](BUILD.bazel) combines three pieces into a `boot_disk`:

- `config.txt`, the firmware configuration,
- `:firmware`, the Pi4 GPU firmware and device tree,
- `:uboot`, a [`uboot_boot_files`](../../boot/uboot/uboot.bzl) instance with the
  `rpi_arm64` U-Boot from
  [`//score/boot/third_party/uboot`](../../boot/third_party/uboot).

The partition layout is set on the `boot_disk` target:

| Attribute         | Default | Meaning                                    |
| ----------------- | ------- | ------------------------------------------ |
| `partition_table` | `mbr`   | `mbr` (classic RPi) or `gpt` (EBBR/ESP)    |
| `offset_kib`      | `1024`  | Boot partition offset in KiB (alignment)   |
| `size_mib`        | `128`   | FAT boot partition size in MiB             |
| `fat_type`        | `32`    | `16` or `32`                               |
| `volume_label`    | `BOOT`  | FAT volume label (≤ 11 chars)              |

This image sets `volume_label = "RPI4BOOT"`. For GPT the boot partition is
created as an EFI System Partition. The Pi4 GPU firmware reads the first FAT
partition from either scheme.

### Files and paths on the partition

Plain files land in the partition root under their basename. To place files
elsewhere, wrap them in `pkg_files` from `rules_pkg`, e.g. device tree overlays:

```python
load("@rules_pkg//pkg:mappings.bzl", "pkg_files")

pkg_files(
    name = "overlays",
    srcs = ["@rpi4_fw_disable_bt_dtbo//file"],
    prefix = "overlays",
)
```

and add `:overlays` to the image's `srcs`.

### U-Boot boot script

To ship a U-Boot boot script, set `boot_script` on the `:uboot` target:

```python
uboot_boot_files(
    name = "uboot",
    binary = "//score/boot/third_party/uboot:rpi_arm64",
    boot_script = "boot.cmd",  # compiled with mkimage, lands as boot.scr
)
```

## Downloaded inputs (not stored in the repo)

The firmware and U-Boot binaries are downloaded by Bazel and pinned in the
Raspberry Pi section of [`MODULE.bazel`](../../../MODULE.bazel):

- **RPi4 firmware** (`start4.elf`, `fixup4.dat`, `bcm2711-rpi-4-b.dtb`): pinned
  to a [`raspberrypi/firmware`](https://github.com/raspberrypi/firmware) commit
  in `RPI_FIRMWARE_COMMIT`. To add more files (e.g. `start4cd.elf`), declare an
  extra `http_file` and add it to `:firmware`.
- **U-Boot** (`u-boot.bin`): from the Ubuntu `u-boot-rpi` package, repo
  `u_boot_rpi_deb`.

## Adding another platform

Create `score/platforms/<board>/BUILD.bazel` with the board's firmware files,
a `uboot_boot_files` with that board's U-Boot binary (add a target for it in
[`//score/boot/third_party/uboot`](../../boot/third_party/uboot), plus a `deb`
or `http_file` repo in `MODULE.bazel` if it comes from another package), and a
`boot_disk` that lists them. Another boot system works as long as its targets
provide files or `PackageFilesInfo`.
