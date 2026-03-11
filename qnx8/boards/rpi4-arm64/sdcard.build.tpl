# cylinders = 1 (partition table) + 256 (boot partition) + 1024 (qnx6fs partition) + 1 (partition table copy)
[cylinders=1282]
[heads=64]
[sectors_per_track=32]
[start_at_cylinder=1]

[partition=1 boot=true  type_guid="ms" name="boot"] "${BOOTFS_IMAGE}"
[partition=2 boot=false type_guid="qnx6" name="scorefs"] "${QNX6FS_IMAGE}"

