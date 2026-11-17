# QEMU Images

Bazel definitions for the QEMU images used by the
[S-CORE ITF](https://github.com/eclipse-score/itf) integration test framework.
The definitions were ported from the ITF repository so that other repositories
can depend on them directly.

## Images

| OS name | Base | Architecture |
| --- | --- | --- |
| `ubuntu_x86_64` | Ubuntu 24.04 minimal cloud image | x86_64 |
| `ebclfsa_aarch64` | EB corbos Linux for Safety Applications fastdev image built from the toolkit's packages | aarch64 |
| `ebclfsa_aarch64_prebuild` | EB corbos Linux for Safety Applications fastdev image customized with shared Debian packages | aarch64 |

All images expose `:image`, `:ssh_target_key` and `:qemu_config`.
The ebclfsa images additionally expose `:kernel` for the prebuilt image.

| Target | Content |
| --- | --- |
| `:image` | The customized disk image |
| `:ssh_target_key` | The development SSH private key for the image |
| `:kernel` | The kernel for the EBcLfSA images |
| `:qemu_config` | `qemu_config.json` describing how to run the image, preconfigured with the SSH key path |

`//ebclfsa_aarch64_prebuild` additionally exposes `:vanilla-image`, the
unmodified base disk image.

The generated `:qemu_config` sets
ITF's native `ssh_auth.pkey_path` to the key's runfiles path. Include the key
in the test's `data` alongside the image and configuration:

```starlark
args = [
    "--qemu-config=$(location //<os_name>:qemu_config)",
    "--qemu-kernel=$(location //<os_name>:kernel)",
    "--qemu-rootfs=$(location //<os_name>:image)",
]
data = [
    "//<os_name>:image",
    "//<os_name>:kernel",
    "//<os_name>:qemu_config",
    "//<os_name>:ssh_target_key",
]
```

## Additional disk on /opt

Images mount an additional and optional disk automatically on `/opt`. The ITF QEMU
plugin attaches such a disk when it is passed via `--qemu-disk`.

`//tests:qemu_disk_image` builds an example ext4 disk with
[rules_imagefs](https://github.com/eclipse-score/rules_imagefs):

```starlark
py_itf_test(
    name = "my_test",
    args = [
        "--qemu-config=$(location //<os_name>:qemu_config)",
        "--qemu-disk=$(location //tests:qemu_disk_image)",
        "--qemu-rootfs=$(location //<os_name>:image)",
    ],
    ...
)
```

## Root SSH login

The images permit root SSH login only with a development key.
It must never be used in production.

Login into a running image using the development SSH key:

```console
$ ssh -i  $(bazel cquery --output=files //<os_name>:ssh_target_key) \
  root@169.254.158.190
```

## Usage from another Bazel module

```starlark
# MODULE.bazel
bazel_dep(name = "os_images", version = "1.0")
```

## Building locally

```console
$ sudo apt-get install -y cloud-image-utils qemu-system-arm \
      qemu-system-x86 qemu-utils openssh-client
$ bazel build //<os_name>:image
```

Building the images requires KVM or falls back to slow TCG emulation.

## Testing

Run the image boot and bidirectional ping tests with:

```console
$ bazel test --config=qemu-integration //tests/...
```

## Security note

The EBcLfSA and Ubuntu images use build-generated development SSH
keys for root login with password authentication disabled.
All these images
are meant for integration testing only and must never be used in production.
