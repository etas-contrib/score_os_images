# AutoSD examples

This directory is a standalone Bazel module that consumes `score_os_images` as an
external dependency, the same way a downstream project would. See
[MODULE.bazel](./MODULE.bazel): `local_path_override` points at this repository,
a real project would depend on a released version instead. Run all commands from
this directory.

## Add a C program to the AutoSD image

[BUILD.bazel](./BUILD.bazel) shows how to extend the prebuilt AutoSD bootc image
(`@score_os_images//score/os/autosd:image_bootc`) with your own software:

1. `:hello` builds [hello.c](./hello.c) with `cc_binary`.
2. `:hello_layer` packs the binary as `/usr/bin/hello` into a layer, and `:image`
   stacks that layer on top of the AutoSD bootc image with `oci_image`.
3. `:archive` packs the resulting image into an oci-archive with `pkg_oci`.

```console
$ cd examples/autosd
$ bazel build //:archive
$ podman load -i bazel-bin/archive.oci
$ podman run --rm <image-id> hello
Hello from S-CORE on AutoSD!
```

The program is built with the host C toolchain, so the target architecture and
glibc version of the host must be compatible with the AutoSD image.

## Test the program in QEMU

[tests/](./tests) boots the prebuilt AutoSD disk image in QEMU with
[ITF](https://github.com/eclipse-score/itf), uploads `:archive`, switches to it
with `bootc switch`, reboots and runs `hello`:

```console
$ bazel test --config=qemu-integration //tests:hello_qemu_test
```

This requires KVM, `qemu-system-x86_64` and OVMF on the host.
