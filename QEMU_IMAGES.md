# QEMU Images

Bazel definitions for the QEMU images used by the
[S-CORE ITF](https://github.com/eclipse-score/itf) integration test framework.
The definitions were ported from the ITF repository so that other repositories
can depend on them directly.

## Images

| Package | Base | Architecture |
| --- | --- | --- |
| `//ubuntu_x86_64` | Ubuntu 24.04 minimal cloud image | x86_64 |
| `//ebclfsa_aarch64` | EB corbos Linux for Safety Applications fastdev image built from the toolkit's packages | aarch64 |
| `//ebclfsa_aarch64_prebuild` | EB corbos Linux for Safety Applications fastdev image customized with shared Debian packages | aarch64 |

All images expose `:image` and `:qemu_config`:
The ebclfsa images additionally expose `:kernel` for the prebuilt image.

| Target | Content |
| --- | --- |
| `:image` | The customized disk image |
| `:kernel` | The kernel for the EBcLfSA images |
| `:qemu_config` | `qemu_config.json` describing how to run the image |

`//ebclfsa_aarch64_prebuild` additionally exposes `:vanilla-image`, the
unmodified base disk image.

The image targets are tagged `manual`, since building them boots QEMU and needs
the base images to be downloaded.

## Additional disk on /opt

Both images mount an additional disk automatically on `/opt`. The ITF QEMU
plugin attaches such a disk when it is passed via `--qemu-disk`; it always shows
up as the second virtio block device `/dev/vdb`. The `fstab` entry uses `nofail`,
so the images keep booting when no additional disk is attached.

`//tests:qemu_disk_image` builds an example ext4 disk with
[rules_imagefs](https://github.com/eclipse-score/rules_imagefs):

```starlark
py_itf_test(
    name = "my_test",
    args = [
        "--qemu-config=$(location //ubuntu_x86_64:qemu_config)",
        "--qemu-disk=$(location //tests:qemu_disk_image)",
        "--qemu-rootfs=$(location //ubuntu_x86_64:image)",
    ],
    ...
)
```

## Build scripts

All the image build scripts are located in the `//scripts` package.
They can be used to build your own images.

## Usage from another Bazel module

```starlark
# MODULE.bazel
bazel_dep(name = "os_images", version = "1.0")
```

## Building locally

```console
$ sudo apt-get install -y cloud-image-utils qemu-system-arm \
      qemu-system-x86 qemu-utils sshpass
$ bazel build //ubuntu_x86_64:image
$ bazel build //ebclfsa_aarch64_prebuild:image
```

Building the images requires KVM or falls back to slow TCG emulation.

## Testing

Run the image boot and bidirectional ping tests with:

```console
$ bazel test --config=qemu-integration //tests/...
```

## Security note

The resulting images permit passwordless root SSH login. They are meant for
integration testing only and must never be used in production.
