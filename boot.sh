#!/usr/bin/env bash
cd linux-6.17.2
qemu-system-arm -m 256M \
                -nographic \
                -M vexpress-a9 \
                -kernel arch/arm/boot/zImage \
                -append "console=ttyAMA0 rdinit=/bin/sh" \
                -dtb arch/arm/boot/dts/arm/vexpress-v2p-ca9.dtb \
                -initrd ~/initramfs.cpio.gz