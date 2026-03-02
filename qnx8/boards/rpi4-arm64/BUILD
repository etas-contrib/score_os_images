load("@score_toolchains_qnx//rules/fs:ifs.bzl", "qnx_ifs")
# load("@score_rules_imagefs//rules/qnx:ifs.bzl", "qnx_ifs")

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
        "@toolchains_qnx_sdp//:all_files",
        "@toolchains_qnx_sdp//:qcc",
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
        # qcc is at host/linux/x86_64/usr/bin/qcc, so QNX_HOST is 3 levels up
        QCC_PATH=$$(realpath $(location @toolchains_qnx_sdp//:qcc))
        export HOME=/var/tmp
        SDP_ROOT=$$(dirname $$(dirname $$(dirname $$(dirname $$(dirname $$(dirname $$QCC_PATH))))))
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

genrule(
    name = "qnx8_rpi4_bootpartition_image",
    srcs = [
        "@rpi4_firmware_files//:rpi4_files",
        "@rpi4_dtb//file",
        ":ifs-rpi4-arm64",
        ":boot_partition.build",
    ],
    tools = [
        "@toolchains_qnx_sdp//:all_files",
        "@toolchains_qnx_sdp//:mkifs",
    ],
    outs = ["rpi4_boot_partition.img"],
    cmd = """
# Run mkfatfsimage to create the RPI4 boot partition image
MKFS_PATH=$$(dirname $(location @toolchains_qnx_sdp//:mkifs))
MKFATFSIMAGE="$$MKFS_PATH/mkfatfsimage"

# Get the firmware directory from the first file in the filegroup
FW_FILES=($(rootpaths @rpi4_firmware_files//:rpi4_files))
FW_DIR=$$(dirname $${FW_FILES[0]})

$$MKFATFSIMAGE -v $(location :boot_partition.build) \
    -r $(location :ifs-rpi4-arm64) \
    -r $$FW_DIR \
    -r $(location @rpi4_dtb//file) \
    . rpi4_boot_partition.img
""",
)

genrule(
    name = "qnx8_rpi4_sdcard_image",
    srcs = [
        ":qnx8_rpi4_bootpartition_image",
    ],
    tools = [
        "@toolchains_qnx_sdp//:all_files",
    ],
    outs = [
        "rpi4_sdcard.img",
    ],
    cmd = """
        echo "This genrule is a placeholder for generating the SD card image. 
        You can implement the image generation logic here, using the BSP binaries built in the previous genrule."
    """,
)