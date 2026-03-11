load("@score_rules_imagefs//rules/qnx:ifs.bzl", "qnx_ifs")
load("@score_rules_imagefs//rules/qnx:fatfs.bzl", "fatfs")
load("@score_rules_imagefs//rules/qnx:qnx6fs.bzl", "qnx6fs")
load("@score_rules_imagefs//rules/qnx:diskimage.bzl", "diskimage")

qnx_ifs (
    name = "ifs-rpi4-arm64",
    build_file = "rpi4-arm64.build",
    srcs = ["target.build", 
        "initscript",
        "//qnx8/boards/common:common_files",
        ":bsp_qnx8_rpi4_binaries",
        ] + glob(["*.sh"], exclude=["run-*.sh"]),
    search_roots = ["../../../bazel-out/k8-fastbuild/bin/qnx8/boards/rpi4-arm64/bsp_install"],
    extension = "bin",
)



genrule(
    name = "bsp_qnx8_rpi4_binaries",
    srcs = [
        "@qnx8_bsp_rpi4_src//:all_srcs",
        "@qnx8_bsp_rpi4_src//:Makefile",
    ],
    tools = [
        "@score_qnx_imagefs_toolchain_pkg//:all_files",
        "@score_qnx_imagefs_toolchain_pkg//:mkifs",
    ],
    outs = [
        "bsp_install/aarch64le/boot/sys/startup-bcm2711-rpi4",
        "bsp_install/aarch64le/sbin/devc-serminiuart",
        "bsp_install/aarch64le/sbin/devc-serpl011",
        "bsp_install/aarch64le/sbin/devb-sdmmc-bcm2711",
        "bsp_install/aarch64le/sbin/i2c-bcm2711",
        "bsp_install/aarch64le/bin/gpio-bcm2711",
        "bsp_install/aarch64le/bin/spi-bcm2711",
        "bsp_install/aarch64le/bin/mbox-bcm2711",
        "bsp_install/aarch64le/bin/wdtkick",
    ],
    cmd = """
        # Save absolute output dir before cd'ing into BSP source
        OUTDIR="$$(pwd)/$(RULEDIR)/bsp_install"
        mkdir -p "$$OUTDIR/aarch64le/boot/sys" "$$OUTDIR/aarch64le/sbin" "$$OUTDIR/aarch64le/bin"

        # Set some QNX environment variables used by qcc toolchain of S-CORE.
        export QNX_SHARED_LICENSE_FILE="/opt/score_qnx/license/licenses"

        # Derive BSP source dir from the Makefile location
        BSP_SRC=$$(dirname $(location @qnx8_bsp_rpi4_src//:Makefile))

        # Copy BSP source to a writable location (sandbox sources are read-only,
        # but QNX make needs to write .o files and install/ headers)
        export BSP_DIR="$$(pwd)/_bsp_build"
        echo "Copying BSP sources from $$BSP_SRC to $$BSP_DIR..."
        cp -r "$$BSP_SRC" "$$BSP_DIR"

        # Get QNX_HOST and QNX_TARGET from `qnxsdp-env.sh` which is part of the qnx sdp 
        # and sets up the environment for using qcc.
        # Derive SDP root from the mkifs binary path (a single-file target
        # whose location Bazel can resolve), stripping the known suffix.
        MKIFS_PATH=$$(realpath $(location @score_qnx_imagefs_toolchain_pkg//:mkifs))
        SDP_ROOT=$${MKIFS_PATH%/host/linux/x86_64/usr/bin/mkifs}
        export HOME=/var/tmp
        source "$$SDP_ROOT/qnxsdp-env.sh"
        #export EXTRA_INCVPATH="$$BSP_DIR/install/usr/include"

        cd $$BSP_DIR
        # somehow make hinstall does not function correctly with the sandboxed filesystem, 
        # so we do the headers installation manually here.
        mkdir -p install/usr/include
        # headers to install reside in src/... folders named "public". Copy them.
        find -L src/ -type d -name public -exec cp -vr {}/. install/usr/include/ \\;
        find install 

        # Make the BSP drivers and install them to the output directory. 
        make install #INSTALL_ROOT_nto=$$OUTDIR
        echo "Make command status: $$?"

        # Copy the generated binaries to the expected output paths.
        cp -vr install/aarch64le "$$OUTDIR/"
        # Dump result
        echo "BSP build complete. Output files:"
        find "$$OUTDIR" -type f
    """,
)

fatfs(
    name = "rpi4_bootfs",
    build_file = "bootfs.build",
    srcs = [
        "@rpi4_firmware_files//:rpi4_files",
        "@rpi4_firmware_files//:fixup4.dat",
        "@rpi4_dtb//file",
        ":ifs-rpi4-arm64",
    ],
    # Pass directories to mkfatfsimage via env variables, so that the build file can reference them.
    ext_repo_dir_mapping = {
        "IFS_PATH": "$(location :ifs-rpi4-arm64)",
        "RPI4_FIRMWARE_PATH": "$(location @rpi4_firmware_files//:fixup4.dat)",
        "RPI4_DTB_PATH": "$(location @rpi4_dtb//file)",
    },
    extension = "img",
)

qnx6fs(
    name = "rpi4_qnx6fs",
    build_file = "qnx6fs.build",
    srcs = [
    ],
    extension = "img",
)

diskimage(
    name = "rpi4_sdcard",
    build_file = ":sdcard_build_file",
    srcs = [
        ":rpi4_bootfs",
        ":rpi4_qnx6fs",
    ],
    out = "rpi4_sdcard.img",
    gpt_enabled = True,
)

# Generate the diskimage config file from the template by substituting
# the Bazel output path of the bootfs image. diskimage requires an actual
# file path (no search-path or env-var support), so we bake it in.
genrule(
    name = "sdcard_build_file",
    srcs = [
        "sdcard.build.tpl",
        ":rpi4_bootfs",
        ":rpi4_qnx6fs",
    ],
    outs = ["sdcard.build"],
    cmd = "sed 's|$${BOOTFS_IMAGE}|$(location :rpi4_bootfs)|g;s|$${QNX6FS_IMAGE}|$(location :rpi4_qnx6fs)|g' $(location sdcard.build.tpl) > $@",
)