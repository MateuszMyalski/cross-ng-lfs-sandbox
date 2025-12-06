# Download the base for the container
FROM ubuntu:22.04 AS base

# Update and download necessary tooling
RUN apt-get update
RUN apt-get upgrade -y
RUN apt-get install -y qemu-system-arm git build-essential gcc g++ gawk \
    bison flex texinfo help2man make libncurses5-dev python3-dev \
    autoconf automake libtool libtool-bin cpio unzip rsync bc device-tree-compiler wget curl

# Set to be a user as we cannot be the root for issuing cross-compilation
RUN useradd -m -u 1000 -s /bin/bash builder && \
    echo "builder ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# CROSSCOMPILER STAGE --------------------------------------------------------------
#  Download crosstool-ng
FROM base AS build-crosstng-env
USER builder
WORKDIR /home/builder

RUN git clone https://github.com/crosstool-ng/crosstool-ng ./crosstool-ng
RUN git -C ./crosstool-ng checkout crosstool-ng-1.26.0

#  Bootstrap the crosstool-ng
WORKDIR /home/builder/crosstool-ng
RUN ./bootstrap
RUN ./configure --enable-local
RUN make -j$(nproc)

#   Configure & build the crosscompiler for selected architecture
COPY defconfig .
RUN ./ct-ng defconfig

RUN ./ct-ng arm-cortexa9_neon-linux-gnueabihf
RUN ./ct-ng build

# KERNEL BUILD STAGE ---------------------------------------------------------------
FROM build-crosstng-env AS build-kernel-env
WORKDIR /home/builder

#  Set crosscompiler path and target architecture
ENV PATH="/home/builder/x-tools/arm-cortexa9_neon-linux-gnueabihf/bin:$PATH"
ENV CROSS_COMPILE=arm-cortexa9_neon-linux-gnueabihf-
ENV ARCH=arm

#  Download Linux kernel
RUN wget cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.17.2.tar.xz
RUN tar xf linux-6.17.2.tar.xz

#  Build kernel
#   Set default config
RUN make -C linux-6.17.2 vexpress_defconfig
#   Build kernel as zImage
RUN make -C linux-6.17.2 zImage -j$(nproc)
#   Build device tree file
RUN make -C linux-6.17.2 dtbs -j$(nproc)

# Build rootfs ---------------------------------------------------------------------
FROM base AS build-rootfs-env
USER builder
WORKDIR /home/builder

COPY --chown=builder:builder --from=build-crosstng-env /home/builder/x-tools /home/builder/x-tools

ENV PATH="/home/builder/x-tools/arm-cortexa9_neon-linux-gnueabihf/bin:$PATH"
ENV CROSS_COMPILE=arm-cortexa9_neon-linux-gnueabihf-
ENV ARCH=arm

RUN mkdir rootfs && cd rootfs && \
    mkdir -p bin dev etc home lib proc sbin sys tmp usr var \
             usr/bin usr/lib usr/sbin var/log

#  Clone, configure and build busybox
RUN git clone git://busybox.net/busybox.git
RUN git -C ./busybox checkout tags/1_36_0

COPY busybox.config busybox/.config
RUN make -C busybox -j
RUN make -C busybox install

#  Copy required libraries
RUN export SYSROOT=$(arm-cortexa9_neon-linux-gnueabihf-gcc -print-sysroot) && \
    cp $SYSROOT/lib/ld-linux-armhf.so.3 rootfs/lib/ && \
    cp $SYSROOT/lib/libm.so.6 rootfs/lib/ && \
    cp $SYSROOT/lib/libresolv.so.2 rootfs/lib/ && \
    cp $SYSROOT/lib/libc.so.6 rootfs/lib/

#  Pack the rootfs
RUN cd rootfs && find . | cpio -H newc -o --owner root:root > ~/initramfs.cpio
RUN gzip -k initramfs.cpio

# (INTERACTIVE) RUNTIME STAGE ------------------------------------------------------
# Prepare for interactive run
FROM base AS runtime
USER builder
WORKDIR /home/builder

ENV PATH="/home/builder/x-tools/arm-cortexa9_neon-linux-gnueabihf/bin:$PATH"
ENV CROSS_COMPILE=arm-cortexa9_neon-linux-gnueabihf-
ENV ARCH=arm

#  We need to copy artifacts from previous stages
COPY --chown=builder:builder --from=build-crosstng-env /home/builder/crosstool-ng /home/builder/crosstool-ng
COPY --chown=builder:builder --from=build-crosstng-env /home/builder/x-tools /home/builder/x-tools
COPY --chown=builder:builder --from=build-kernel-env /home/builder/linux-6.17.2 /home/builder/linux-6.17.2
COPY --chown=builder:builder --from=build-rootfs-env /home/builder/busybox /home/builder/busybox
COPY --chown=builder:builder --from=build-rootfs-env /home/builder/rootfs /home/builder/rootfs
COPY --chown=builder:builder --from=build-rootfs-env /home/builder/initramfs.cpio /home/builder/initramfs.cpio
COPY --chown=builder:builder --from=build-rootfs-env /home/builder/initramfs.cpio.gz /home/builder/initramfs.cpio.gz
COPY ./boot.sh /home/builder/boot.sh

CMD ["/bin/bash"]


