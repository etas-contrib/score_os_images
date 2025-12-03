exports_files([
    "common.build",
    "ssh_host_ed25519_key",
    "ssh_host_ed25519_key.pub",
    "ssh_host_rsa_key",
    "ssh_host_rsa_key.pub",
])
 
filegroup(
    name = "common_files",
    srcs = glob(["*"]),
    visibility = [
        "//qnx8/boards/qemu-arm64virt:__pkg__",
        "//qnx8/boards/qemu-x86_64:__pkg__",
    ],
)