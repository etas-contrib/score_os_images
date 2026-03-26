load("@score_rules_imagefs//rules/qnx:ifs.bzl", "qnx_ifs")

qnx_ifs (
    name = "ifs-qemu-x86_64",
    build_file = "qemu-x86_64.build",
    srcs = ["target.build", 
        "initscript",
        "//qnx8/boards/common:common_files"] + glob(["*.sh"], exclude=["run-*.sh"]),
    extension = "bin",
    visibility = ["//visibility:public"],
)

genrule(
    name = "qemu-runscript",
    srcs = [
        "run-qemu-x86_64.sh",
    ],
    outs = [
        "run-qemu.sh",
    ],
    cmd = """
        cp $(execpath run-qemu-x86_64.sh) $(execpath run-qemu.sh)
    """,
    visibility = ["//visibility:public"],
)

sh_binary(
    name = "run",
    srcs = ["run-qemu.sh"],
    data = [":ifs-qemu-x86_64"],
    args = ["$(location :ifs-qemu-x86_64)"],
)
