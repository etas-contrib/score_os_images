# OS images 

This module creates OS images intended for testing S-CORE software:

* bootable [QNX IFS images using the QNX 8 SDP](qnx8/README.md).
* bootable Linux image: TODO

**Why do we need OS images?**

The basic idea is to have modular OS images for *testing* and *verifying* S-CORE binaries. Main purposes:

* re-usable for multiple use cases: unit-, component-, binary- and system tests and demonstrations
* stuffed with common OS utilities: shell-, file-, test utilities
* no need for rebuilding OS images to match the use case - use cases are realized by a separate partition image created by the user/tester which is attached at OS boot time and is containing files required for the use case.

**Features**:

* Launches `sshd` service for remote control (user `root`, empty password by default).
* Supports attaching a user-created file system to `/` (root) in case of QNX. Linux: TODO. By placing some files on this file system the user can make these adaptions:
  * Configure hostname and network IP address.
  * Add an autostart script launched at the end of the OS startup to start arbitrary tasks.

=> users can focus on creating the file system with content to match their use cases and *use* the OS image of their choice.

