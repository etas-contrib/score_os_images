# OS images 

This module creates OS images intended for testing S-CORE software:

* bootable QNX IFS images using the QNX 8 SDP.
* bootable Linux image: TODO

**Why do we need OS images?**

The basic idea is to have modular OS images for *testing* and *verifying* S-CORE binaries. Main purposes:

* re-usable for multiple use cases: unit-, component-, binary- and system tests and demonstrations
* stuffed with common OS utilities: shell-, file-, test utilities
* no need for rebuilding OS images to match the use case - use cases are realized by a separate partition image created by the user/tester which is attached at OS boot time and is containing files required for the use case.

**Features**:

* Launches `sshd` service for remote control (user `root`, empty password by default).
* Supports attaching a user-created file system to `/` (root) in case of QNX. Linux: TODO. By placing some files on this file system the user can make these adaptions:
  * Configure hostname and network IP address.
  * Add an autostart script launched at the end of the OS startup to start arbitrary tasks.

=> users can focus on creating the file system with content to match their use cases and *use* the OS image of their choice.

## OS images for QNX 8

Following QNX 8 OS images can be created:

* QEMU aarch64 "virt" image using virtio block and network drivers.
* QEMU x86_64 image using virtio block and network drivers.

### Pre-requisites

#### QNX SDP

Building the images requires a QNX SDP 8.0.3 (or later) available during build with following additional QNX SDP packages integrated:

* QNX® SDP 8.0 Networking - io-sock Virtio Drivers
* QNX® SDP 8.0 Virtualization Drivers (Block)
* QNX® SDP 8.0 Virtualization Drivers (Startup)

Add the URL of the QNX SDP tarball to the `MODULE.bazel`:

```
[...]

toolchains_qnx = use_extension("@score_toolchains_qnx//:extensions.bzl", "toolchains_qnx", dev_dependency=True)
toolchains_qnx.sdp(
    url = "http://link/to/qnx803.tar.gz",
    # or:
    # url = "file:///path/to/qnx803.tar.gz",
    sha256 = "<sha256-sum>",
)

[...]

```

#### bazelrc

A `.bazelrc` should include general eclipse-score registry and toolchain requirements given by 
https://github.com/eclipse-score/toolchains_qnx/blob/main/README.md .

```
common --registry=https://raw.githubusercontent.com/eclipse-score/bazel_registry/main/
common --registry=https://bcr.bazel.build

common --incompatible_strict_action_env
# mkifs is not a target platform specific tool, the host would be sufficient. But there is only
# target platform specific toolchains defined for QNX in this repo.
# Therefore we have to select a target platform and we choose x86_64-qnx.
common --platforms=@score_toolchains_qnx//platforms:x86_64-qnx
common --sandbox_writable_path=/var/tmp
```

### Building QNX OS images

QEMU arm64 image using "virt" VM:

```bash
bazel build //qnx8/boards/qemu-arm64virt:all
```

QEMU x86_64 image:

```bash
bazel build //qnx8/boards/qemu-x86_64:all
```

In case of requiring an online QNX license checkout for the QNX SDP `mkifs` utility you might have to set the QNXLM_LICENSE_FILE environment variable with the link to the license server `--action_env=QNXLM_LICENSE_FILE=...`, for example:

```bash
bazel build --action_env=QNXLM_LICENSE_FILE=my@internal.qnx-license-server.com //qnx8/boards/qemu-arm64virt:all
```

### Running the images

#### Pre-requisites

In order to run the QEMU images on the host you must have `qemu-system-aarch64` and `qemu-system-x86_64` installed. The x86_64 QEMU run script uses `-accel kvm`, so the running user must have access to `/dev/kvm` for acceleration.

#### Get started

After successful build you'll find the IFS binary and an exemplary run script in `bazel-out`:

```
bazel-out/k8-fastbuild/bin/qnx8/boards/qemu-arm64virt/run-qemu.sh
bazel-out/k8-fastbuild/bin/qnx8/boards/qemu-arm64virt/ifs-qemu-arm64virt.bin
bazel-out/k8-fastbuild/bin/qnx8/boards/qemu-x86_64/run-qemu.sh
bazel-out/k8-fastbuild/bin/qnx8/boards/qemu-x86_64/ifs-qemu-x86_64.bin
```

In order to run the image, change into the directory with the IFS and execute the run script:

```
cd bazel-out/k8-fastbuild/bin/qnx8/boards/qemu-arm64virt
./run-qemu.sh
```

You'll get something like:

```
Welcome to QNX 8.0.0 on QEMU_virt !

---> Starting slogger2
---> Starting serial driver
---> Starting block driver
Path=0 -
 target=0 lun=0     Direct-Access(0) - VIRTIO  Rev:
---> Preparing /run using /dev/ram0
---> Mounting file systems
No root file system has been detected
---> Starting Ethernet driver
---> Setting up vtnet0 with ip address 192.168.120.20/24
---> Starting qconn
---> Starting sshd
---> Starting shell ... Have fun :-)
#
```

#### ssh from host into QEMU image

The QNX IFS images start up a `sshd` server. The user `root` has by default no password and `sshd` is configured to accept a root login w/o password.
The exemplary `run-qemu.sh` script configures QEMU to use QEMU user networking and sets up a port forwarding from localhost:2210 -> VM-IP 192.168.120.20:22. So you can open a ssh from host using:

```
ssh -p 2210 root@localhost
```

#### Attaching a user-created QNX6fs file system

The QNX startup script (see `qnx8/boards/<board>/initscript`) calls `mount-fs.sh` which tries to mount a file system to the system.
By default, the partition is mounted at `/` (root) and therefore a user sees a virtual file system with a combination of the IFS and the mounted file system. The path manager resolves path names first on the mounted partition, then on the IFS. This means all files on partition extend or even eclipse files on the IFS. For more information see https://www.qnx.com/developers/docs/8.0/com.qnx.doc.neutrino.sys_arch/topic/proc_Resolving_pathnames.html.

The generated QEMU launch script `run-qemu.sh` attaches a virtual disk `disk-score.qcow2` to the image. If it does not exist, it creates an empty virtual QEMU disk with size of 512MB before launching QEMU.

##### Creating a file system on-line

When starting up the QEMU VM with an empty virtual QEMU disk, no partitions are there. With the following commands you can create a partition and a qnx6fs file system which then gets mounted automatically on following boots:

```bash
# initialize with GUID partition table
pted /dev/hd0 init -g
# Create a partition with 99% disk size and name 'scorefs'
pted /dev/hd0 add -t qnx6fs -p 99 -n scorefs
# Re-read the partition table
mount -e /dev/hd0
# Create QNX6 file system
mkqnx6fs /dev/hd0.qnx6.0
# Reboot to let the partition be mounted automatically
shutdown
```

After reboot you'll see in the startup messages that a partition is found and mounted:

```
[...]
---> Mounting file systems
Mounting root overlay filesystem /dev/hd0.qnx6.0
[...]
```

##### Creating a file system offline

A QNX file system can be created on the host using `mkqnx6fsimg` (see https://www.qnx.com/developers/docs/8.0/com.qnx.doc.neutrino.utilities/topic/m/mkqnx6fsimg.html).

TODO: integrate `mkqnx6fsimg` into `toolchains_qnx`.

#### Configuring custom IP address + host name

During the startup of the VM the network is being set up, *after* mounting the virtual file system. By default host name `qemu-arm64virt` or `qemu-x86_64` and IP address 192.168.120.20/24 is set up. **Before** setting these, the `net-start.sh` script tries to read a file `/boot/etc/settings/network`. By installing such a file on the virtual file system and adding variables one can configure hostname and IP address of the network interface:

```
# /boot/etc/settings/network
IP_ADDRESS_vtnet0="192.168.100.1/24"
HOSTNAME=myqemu
```

> NOTE: This changes only the IP address of the QNX network interface. In order to make the port forwardings of the QEMU user network function correctly you'll have to adapt the QEMU user networking configuration in the `run-qemu.sh` script according to your IP address/subnet.

#### Autostart script

If the file `/opt/score/autostart.sh` exists on the mounted file system, it is executed at the end of the OS image startup sequence.
