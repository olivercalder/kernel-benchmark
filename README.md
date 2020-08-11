# kernel-benchmark

Scripts to compare the performance of minimal Rust kernel running in a VM, a minimal Linux kernel running in a VM, a Docker container, and a Linux process.

## Rust kernel

The Rust kernel is based upon the excellent blog by Philipp Oppermann, which can be found [here](https://os.phil-opp.com). Function calls can be added in the `kernel_main` function before the call to `executor.run()`, which does not return.

- To download build the Rust kernel, execute `build_rust.sh`
- To run the kernel in qemu, execute `start_rust.sh`

## Linux kernel

The Linux kernel is pulled from the 5.8 release [here](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git), and built using `debootstrap` to Debian 10, roughly based on the instructions [here](https://www.collabora.com/news-and-blog/blog/2017/01/16/setting-up-qemu-kvm-for-kernel-development/). Any files in the disk image must be modified in the chroot environment prior to booting. _NOTE: it may be necessary to install `libelf-dev` and `libssl-dev` before the Linux kernel can be compiled._

- To download and build the Linux kernel and accompanying disk image, execute `build_linux.sh`
- To modify files on the disk image, execute `edit_img.sh`
- To run the kernel in qemu, execute `start_linux.sh`
- To run the kernel in qemu with kvm enabled, execute `start_kvm_linux.sh`

## Container

Coming soon...

## Linux process

Coming soon...
