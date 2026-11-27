# U-Boot Images

Bazel rules to build **boot disks**: small disk images that carry only the
board specific boot chain (vendor firmware, device tree, U-Boot). U-Boot
provides a standard [EBBR](https://github.com/ARM-software/ebbr) environment
(UEFI + device tree) and boots the actual OS from separate storage, e.g. a USB
stick. The OS image stays board neutral; everything board specific lives on
the boot disk.

```
 Boot disk (per board)            OS disk (board neutral)
 ┌────────────────────────┐      ┌────────────────────────────┐
 │ FAT boot partition     │      │ GPT                        │
 │  - vendor firmware     │ ───▶ │  - EFI System Partition    │
 │  - device tree         │ UEFI │  - root, ...               │
 │  - U-Boot (+ boot.scr) │      │                            │
 └────────────────────────┘      └────────────────────────────┘
```

Boot flow: board ROM / firmware → U-Boot → UEFI boot manager → the OS loader
on the OS disk's EFI System Partition.

## Layout

| Path | Content |
| --- | --- |
| `score/common/boot_disk` | `boot_disk` rule: raw disk with one FAT boot partition |
| `score/boot/uboot` | `uboot_boot_files` rule: U-Boot binary + optional boot script |
| `score/boot/third_party` | `deb` repository rule and prebuilt U-Boot binaries per board |
| `score/platforms/$board` | One package per board, combining the pieces above |

| Board | Target | Details |
| --- | --- | --- |
| Raspberry Pi 4 | `//score/platforms/rpi4:image` | [Raspberry Pi 4](#raspberry-pi-4) |

## Rules

### `boot_disk`

```python
load("//score/common/boot_disk:defs.bzl", "boot_disk")

boot_disk(
    name = "image",
    srcs = [...],                 # files placed on the boot partition
    partition_table = "mbr",      # mbr (bootable FAT) | gpt (EFI System Partition)
    offset_kib = 1024,
    size_mib = 128,
    fat_type = 32,                # 16 | 32
    volume_label = "BOOT",        # <= 11 characters
    out = "my-board.img",         # default: <name>.img
)
```

Placement on the partition:

- plain files land in the root under their basename;
- targets providing `PackageFilesInfo` (`pkg_files` from `rules_pkg`,
  `uboot_boot_files`) land at their destination path, so subdirectories and
  renames work:

```python
pkg_files(
    name = "overlays",
    srcs = ["some-overlay.dtbo"],
    prefix = "overlays",
)
```

Two files mapping to the same path (case-insensitive, as on FAT) fail at
analysis time. The image is assembled unprivileged with `mtools` and `sfdisk`.

### `uboot_boot_files`

```python
load("//score/boot/uboot:uboot.bzl", "uboot_boot_files")

uboot_boot_files(
    name = "uboot",
    binary = "//score/boot/third_party/uboot:<board>",  # mandatory, board specific
    binary_name = "u-boot.bin",   # path on the partition, must match what the firmware loads
    boot_script = "boot.cmd",     # optional, compiled with host mkimage -> boot.scr
    arch = "arm64",               # mkimage architecture for the script
)
```

A precompiled `.scr` is used as-is. Without a boot script U-Boot runs its
default flow (UEFI boot manager / bootflow scan).

## Adding a board

1. Pin the downloads in `MODULE.bazel`: firmware files as `http_file`, the
   U-Boot binary as `deb` (Debian/Ubuntu package) or `http_file`.
2. Expose the U-Boot binary as a target in
   `score/boot/third_party/uboot/BUILD.bazel` (and in the `.deb`'s BUILD file).
3. Create `score/platforms/<board>/BUILD.bazel`:

```python
load("//score/boot/uboot:uboot.bzl", "uboot_boot_files")
load("//score/common/boot_disk:defs.bzl", "boot_disk")

filegroup(
    name = "firmware",
    srcs = ["@myboard_fw_foo//file"],
    visibility = ["//visibility:public"],
)

uboot_boot_files(
    name = "uboot",
    binary = "//score/boot/third_party/uboot:myboard",
    visibility = ["//visibility:public"],
)

boot_disk(
    name = "image",
    srcs = [":firmware", ":uboot"],
    tags = ["manual"],
)
```

`srcs` can mix pieces from different packages, e.g. one board's firmware with
another boot system, as long as they provide files or `PackageFilesInfo`.

## Building and testing

Host tools: `mtools` (`mformat`, `mcopy`, `mmd`), `util-linux` (`sfdisk`),
`binutils` (`ar`, for `deb` repositories), `mkimage` only for boot scripts.

```sh
bazel build //score/platforms/<board>:image
bazel test //score/common/boot_disk:boot_disk_test   # manual: needs mtools
```

Inspect an image without flashing (partition at the default 1 MiB offset):

```sh
sfdisk -d bazel-bin/score/platforms/<board>/<image>.img
mdir -i bazel-bin/score/platforms/<board>/<image>.img@@1M ::
```

Flash: find the device with `lsblk` (whole disk, not a partition). `dd`
overwrites the target without asking.

```sh
sudo umount /dev/sdX?* 2>/dev/null
sudo dd if=<image>.img of=/dev/sdX bs=4M conv=fsync status=progress
```

Write the OS image to its own disk the same way.

## Serial console

```sh
sudo picocom -b 115200 /dev/ttyUSB0      # exit: Ctrl-a Ctrl-x
# or: tio -b 115200 /dev/ttyUSB0          # exit: Ctrl-t q
```

Start the terminal **before** powering the board.

> picocom must print `Terminal ready` after its settings. If it stops before
> that, the host port is stuck (another process holds it, often ModemManager,
> or the adapter needs replugging) and you will see nothing from the board:
> `sudo fuser -v /dev/ttyUSB0`, `sudo systemctl stop ModemManager`.

## U-Boot commands

Press any key during `Hit any key to stop autoboot` to get the `U-Boot>`
prompt. Without interruption U-Boot runs the UEFI boot manager and boots the
first bootable device on its own.

### Boot

```
bootefi bootmgr               # same path as autoboot: UEFI boot manager
bootflow scan -lb             # scan all devices, list and boot the first bootflow
bootflow scan -l              # only list what was found
boot                          # run the default boot command (bootcmd)
reset                         # reboot
```

Boot a specific EFI loader by hand (e.g. when the OS image has no
`EFI/BOOT/BOOTAA64.EFI` fallback):

```
load usb 0:1 ${kernel_addr_r} EFI/BOOT/BOOTAA64.EFI
bootefi ${kernel_addr_r} ${fdt_addr}
```

### Storage

```
usb reset                     # (re)scan USB; may need a second try
usb tree                      # devices on the bus
usb storage                   # detected storage devices
part list usb 0               # partitions of the first USB disk
ls usb 0:1 /                  # files on partition 1 (e.g. the ESP)
mmc list
```

### Device tree

On boards where the firmware provides the device tree, U-Boot passes it to the
OS (`devicetree: board` in the banner).

```
fdt addr ${fdt_addr}
fdt print /chosen             # stdout-path: the console the OS should use
fdt print /aliases            # serialN -> UART node
```

One-shot change before booting, e.g. a different console:

```
fdt addr ${fdt_addr}
fdt resize 1024
fdt set /chosen stdout-path "serial0:115200n8"
bootefi bootmgr
```

### Network

```
setenv autoload no            # dhcp only, no TFTP boot attempt
dhcp
echo ${ipaddr} ${gatewayip}
ping ${gatewayip}
```

The OS reuses the same MAC address, so it usually gets the same IP later. That
is not guaranteed: the OS DHCP client may identify itself differently.

### UEFI

```
efidebug boot dump            # UEFI boot options (Boot0000, ...)
efidebug boot order           # boot order
```

Without a variable store on the boot disk, U-Boot logs
`Failed to load EFI variables` and `Unable to read "uboot.env"` on every boot.
Both are harmless; changes made with `efidebug` or `saveenv` do not persist.

### Environment and info

```
version
bdinfo
printenv                      # all variables
printenv bootcmd boot_targets
```

## Requirements for the OS image

The boot disk provides EBBR. The OS image must:

- be a GPT disk with an EFI System Partition, ideally with the
  `EFI/BOOT/BOOTAA64.EFI` fallback (aarch64) so autoboot finds it;
- run a kernel with drivers for the board;
- load in its initramfs the drivers on the path to its root filesystem and for
  the console. A udev-based initramfs loads them from the firmware device tree
  automatically, which is what keeps the OS image board neutral. An initramfs
  with a fixed driver list only works on the boards in that list.

---

## Raspberry Pi 4

`//score/platforms/rpi4:image` builds `rpi4-boot.img`: an MBR disk with one
bootable FAT32 partition (label `RPI4BOOT`).

| File | Source |
| --- | --- |
| `config.txt` | `score/platforms/rpi4/config.txt` |
| `start4.elf`, `fixup4.dat`, `bcm2711-rpi-4-b.dtb` | [raspberrypi/firmware](https://github.com/raspberrypi/firmware), pinned commit |
| `u-boot.bin` | Ubuntu `u-boot-rpi` package, `rpi_arm64` build |

`config.txt` makes the GPU firmware start U-Boot in 64-bit mode with the serial
console enabled:

```
arm_64bit=1
enable_uart=1
uart_2ndstage=1
kernel=u-boot.bin
```

Boot flow: Pi EEPROM → `start4.elf` → `u-boot.bin` → UEFI → OS on USB.

### Build and flash

```sh
bazel build //score/platforms/rpi4:image
sudo dd if=bazel-bin/score/platforms/rpi4/rpi4-boot.img of=/dev/sdX bs=4M conv=fsync status=progress
```

### Serial wiring

Use a **3.3 V** USB-to-TTL adapter. Do not connect its VCC pin; power the Pi
from its own USB-C supply.

| Adapter | Pi 4 header |
| --- | --- |
| GND | pin 6 |
| RX | pin 8 (GPIO14, Pi TX) |
| TX | pin 10 (GPIO15, Pi RX) |

U-Boot also prints to HDMI (the HDMI0 port next to USB-C) and accepts a USB
keyboard.

### Pi 4 specific U-Boot commands

The USB-A ports sit behind a VL805 controller on PCIe; bring PCIe up first:

```
pci enum
usb reset                     # may need a second try
usb tree
part list usb 0
```

The black USB 2.0 ports are more reliable than the blue USB 3.0 ones.

The firmware provided device tree already sets the console:

```
U-Boot> fdt addr ${fdt_addr}
U-Boot> fdt print /chosen
    stdout-path = "serial0:115200n8";
U-Boot> fdt print /aliases
    serial0 = "/soc/serial@7e215040";      # mini UART on GPIO14/15, ttyS0 in Linux
    serial1 = "/soc/serial@7e201000";      # PL011, used by Bluetooth
```

`/chosen/bootargs` holds the firmware's default Raspberry Pi OS command line;
it is ignored on UEFI boot.

### OS requirements on the Pi 4

On top of the [generic requirements](#requirements-for-the-os-image), the
initramfs must load:

| Purpose | Modules |
| --- | --- |
| PCIe (USB controller) | `pcie_brcmstb`, `reset_raspberrypi` |
| USB storage | `xhci_pci`, `usb_storage`, `uas` |
| Serial console (mini UART) | `8250_bcm2835aux` |

### Troubleshooting

| Symptom | Meaning |
| --- | --- |
| Red LED on, green flickers once then off | Normal: firmware ran and handed over to U-Boot |
| Green LED blinks a repeating long/short pattern | Firmware error code; check the SD card contents |
| Green LED never flickers | SD card not read; reflash or try another card |
| picocom shows nothing, no `Terminal ready` | Host serial port stuck, see [Serial console](#serial-console) |
| Garbage on serial | Wrong baud rate or missing GND |
| U-Boot does not find the USB stick | `pci enum`, `usb reset` (twice), try a USB 2.0 port |
| Stops after `Starting kernel` / `Starting UKI` | OS side: initramfs drivers or console, see [OS requirements](#os-requirements-on-the-pi-4) |
