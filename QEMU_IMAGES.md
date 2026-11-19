# QEMU Images

Bazel definitions for the QEMU images used by the
[S-CORE ITF](https://github.com/eclipse-score/itf) integration test framework.
The definitions were ported from the ITF repository so that other repositories
can depend on them directly.

## Images

| OS name | Base | Architecture |
| --- | --- | --- |
| `ubuntu_x86_64` | Ubuntu 24.04 minimal cloud image | x86_64 |
| `ebclfsa_aarch64` | EB corbos Linux for Safety Applications built from the toolkit's packages | aarch64 |
| `ebclfsa_aarch64_prebuild` | Makro for downloading and customizing the prebuilt EBcLfSA image | aarch64 |

All images expose `:image`, `:ssh_target_key` and `:qemu_config`.
Both EBcLfSA variants additionally expose `:kernel`.

| Target | Content |
| --- | --- |
| `:image` | The customized disk image |
| `:ssh_target_key` | The development SSH private key for the image |
| `:kernel` | The kernel for the EBcLfSA images |
| `:qemu_config` | `qemu_config.json` describing how to run the image, preconfigured with the SSH key path |

`ebclfsa_aarch64_prebuild()` additionally exposes `:vanilla-image`, the
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

## Networking

The primary network interface keeps the static `169.254.158.190/16` address
used by the ITF QEMU configuration and also requests an IPv4 address via DHCP.
When a DHCP server supplies a default gateway, it takes precedence over the
static `169.254.21.88` gateway. Without DHCP, the static configuration remains
available for the ITF tap network.

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

## EBcLfSA release archive contract

The archive must be a flat tar.gz release archive with exactly one `.wic` file,
one matching `*-vmlinux` file, and one matching `*-ssh-target-key` file. For an
image named `score-image.wic`, the other required names are
`score-image-vmlinux` and `score-image-ssh-target-key`. Additional metadata
files are allowed at the archive root; nested paths, unsafe paths, links, and
ambiguous or mismatched image/kernel/key files are rejected.
The key may be omitted when the macro is given an explicit `ssh_target_key`.

## Usage from another Bazel module

Add `os_images` to the consumer's `MODULE.bazel`, selecting a published version
that contains the image targets and macro described below. The ITF test examples
also require a direct dependency on `score_itf`:

```starlark
# MODULE.bazel
bazel_dep(name = "os_images", version = "<os_images_version>")
bazel_dep(name = "score_itf", version = "<score_itf_version>")
```

### EBcLfSA aarch64

Pin the release archive independently in the consumer's `MODULE.bazel`. This
keeps the large base image version choice independent of the `os_images`
module version and makes the download reproducible. For example, using the
QEMU release archive pinned by this repository:

```starlark
# MODULE.bazel
http_file = use_repo_rule("@bazel_tools//tools/build_defs/repo:http.bzl", "http_file")

http_file(
    name = "ebclfsa_release_archive",
    downloaded_file_path = "score-image-trixie-ebclfsa-ebcl-qemuarm64.tar.gz",
    sha256 = "<hash>",
    urls = ["https://github.com/eclipse-score/os_images/releases/download/<os_images_version>/score-image-trixie-ebclfsa-ebcl-qemuarm64.tar.gz"],
)
```

Instantiate the macro in a consumer package, for example `qemu/BUILD.bazel`:

```starlark
load("@os_images//ebclfsa_aarch64_prebuild:defs.bzl", "ebclfsa_aarch64_prebuild")

ebclfsa_aarch64_prebuild(
    base_image = "@ebclfsa_release_archive//file",
)
```

This defines `//qemu:image`, `//qemu:vanilla-image`, `//qemu:kernel`,
`//qemu:qemu_config`, and `//qemu:ssh_target_key`. Without extra packages,
`image` is the unmodified `vanilla-image`. To customize it, pass `packages` as
a list of labels for compatible Debian packages, in dependency order (least
dependent first). Customization boots the image with QEMU and installs the
packages. If the archive has no bundled key, pass `ssh_target_key` as a label
for the private key already authorized by the image.

An ITF test in another package can use the generated targets as follows;
`test_example.py` is the consumer's test:

```starlark
# tests/BUILD.bazel
load("@score_itf//:defs.bzl", "py_itf_test")

py_itf_test(
    name = "ebclfsa_test",
    srcs = ["test_example.py"],
    args = [
        "--qemu-config=$(location //qemu:qemu_config)",
        "--qemu-kernel=$(location //qemu:kernel)",
        "--qemu-rootfs=$(location //qemu:image)",
    ],
    data = [
        "//qemu:image",
        "//qemu:kernel",
        "//qemu:qemu_config",
        "//qemu:ssh_target_key",
    ],
    plugins = ["@score_itf//score/itf/plugins:qemu_plugin"],
)
```

Alternatively, use `@os_images//ebclfsa_aarch64:image`,
`@os_images//ebclfsa_aarch64:kernel`, `@os_images//ebclfsa_aarch64:qemu_config`,
and `@os_images//ebclfsa_aarch64:ssh_target_key` to build the EBcLfSA image
from scratch; see the [build requirements](./ebclfsa_aarch64/README.md#requirements).

### Ubuntu x86_64

The Ubuntu targets can be referenced directly; `os_images` pins the underlying
cloud image in its own module. No archive declaration or image macro is needed
in the consumer:

```starlark
# tests/BUILD.bazel
load("@score_itf//:defs.bzl", "py_itf_test")

py_itf_test(
    name = "ubuntu_test",
    srcs = ["test_example.py"],
    args = [
        "--qemu-config=$(location @os_images//ubuntu_x86_64:qemu_config)",
        "--qemu-rootfs=$(location @os_images//ubuntu_x86_64:image)",
    ],
    data = [
        "@os_images//ubuntu_x86_64:image",
        "@os_images//ubuntu_x86_64:qemu_config",
        "@os_images//ubuntu_x86_64:ssh_target_key",
    ],
    plugins = ["@score_itf//score/itf/plugins:qemu_plugin"],
)
```

Unlike EBcLfSA, Ubuntu does not expose a separate kernel target. Both examples
include the private key in `data` because the QEMU configuration references its
runfiles path. Building or running the images requires the corresponding QEMU
emulator and host tools; see [Building locally](#building-locally). Run either
example with the ITF QEMU wrapper:

```console
$ bazel test --run_under=@score_itf//scripts:run_under_qemu //tests:ebclfsa_test
$ bazel test --run_under=@score_itf//scripts:run_under_qemu //tests:ubuntu_test
```

## Building locally

```console
$ sudo apt-get install -y cloud-image-utils qemu-system-arm \
      qemu-system-x86 qemu-utils openssh-client
$ bazel build //<os_name>:image
```

Building the images requires KVM or falls back to slow TCG emulation.

## Testing

Run the image boot, DHCP, and bidirectional ping tests with:

```console
$ bazel test --config=qemu-integration //tests/...
```

## Security note

The EBcLfSA and Ubuntu images use build-generated development SSH
keys for root login with password authentication disabled.
All these images
are meant for integration testing only and must never be used in production.
