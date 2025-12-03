load("@score_toolchains_qnx//rules/fs:ifs.bzl", "qnx_ifs")

qnx_ifs (
    name = "ifs-qemu-arm64virt",
    build_file = "qemu-arm64virt.build",
    srcs = ["target.build", 
        "initscript",
        "//qnx8/boards/common:common_files"] + glob(["*.sh"], exclude=["run-*.sh"]),
    extension = "bin",
)

genrule(
    name = "qemu-runscript",
    srcs = [
        "run-qemu-arm64virt.sh",
    ],
    outs = [
        "run-qemu.sh",
    ],
    cmd = """
        cp $(execpath run-qemu-arm64virt.sh) $(execpath run-qemu.sh)
    """,
    visibility = ["//visibility:public"],
)
