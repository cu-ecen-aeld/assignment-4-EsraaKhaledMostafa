#!/bin/bash
# manual-linux.sh
# Script to build kernel and rootfs for ARM64 QEMU
# Author: Modified for Assignment 3

set -e
set -u

# ============================================
# CLEAN ENVIRONMENT - NO VISTA TOOLS
# ============================================
export PATH=/usr/bin:/bin:/usr/local/bin:/usr/sbin:/sbin:/usr/local/sbin

# Add ARM toolchain and QEMU
export ARM_TOOLCHAIN=/esd/bata_esd2/esrmosp7/EmbeddedLinuxCourse/toolchain/gcc-arm-10.3-2021.07-x86_64-aarch64-none-linux-gnu
export QEMU_PATH=/esd/bata_esd2/esrmosp7/qemu
export PATH=${ARM_TOOLCHAIN}/bin:${QEMU_PATH}/bin:${PATH}

# Explicitly set host compiler
export HOSTCC=/usr/bin/gcc
export HOSTCXX=/usr/bin/g++
export CC=/usr/bin/gcc
export CXX=/usr/bin/g++

# ============================================
# CONFIGURATION
# ============================================
KERNEL_REPO=git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git
KERNEL_VERSION=v5.15.163
BUSYBOX_VERSION=1_33_1
FINDER_APP_DIR=$(realpath $(dirname $0))
ARCH=arm64
CROSS_COMPILE=aarch64-none-linux-gnu-

# ============================================
# PARSE ARGUMENTS
# ============================================
if [ $# -lt 1 ]; then
    OUTDIR=/tmp/aeld
    echo "Using default directory ${OUTDIR} for output"
else
    OUTDIR=$(realpath $1)
    echo "Using passed directory ${OUTDIR} for output"
fi

# ============================================
# CREATE OUTPUT DIRECTORY
# ============================================
echo "Creating output directory ${OUTDIR}"
mkdir -p ${OUTDIR}

if [ ! -d "${OUTDIR}" ]; then
    echo "ERROR: Failed to create directory ${OUTDIR}"
    exit 1
fi

cd "${OUTDIR}"

# ============================================
# VERIFY TOOLCHAIN
# ============================================
echo "============================================"
echo "Verifying build environment..."
echo "============================================"
echo "Host GCC: $(which gcc)"
gcc --version | head -1

if ! command -v ${CROSS_COMPILE}gcc &> /dev/null; then
    echo "ERROR: ${CROSS_COMPILE}gcc not found in PATH"
    exit 1
fi

echo "Cross-compiler: $(which ${CROSS_COMPILE}gcc)"
${CROSS_COMPILE}gcc --version | head -1
echo "============================================"

# ============================================
# BUILD KERNEL - FAST SHALLOW CLONE
# ============================================
if [ ! -d "${OUTDIR}/linux-stable" ]; then
    echo "============================================"
    echo "Cloning Linux kernel ${KERNEL_VERSION}..."
    echo "This will take a few minutes..."
    echo "============================================"
    
    # Try direct tag clone first (fastest)
    if git clone --depth 1 --single-branch --branch ${KERNEL_VERSION} ${KERNEL_REPO} linux-stable 2>/dev/null; then
        echo "Successfully cloned kernel at tag ${KERNEL_VERSION}"
    else
        echo "Direct tag clone not supported, using alternative method..."
        # Clone with minimal history
        git clone --depth 1 ${KERNEL_REPO} linux-stable
        cd ${OUTDIR}/linux-stable
        
        # Fetch the specific tag
        echo "Fetching tag ${KERNEL_VERSION}..."
        git fetch --depth 1 origin tag ${KERNEL_VERSION}
        
        # Checkout the tag
        echo "Checking out ${KERNEL_VERSION}..."
        git checkout ${KERNEL_VERSION}
        cd ${OUTDIR}
    fi
else
    echo "Linux kernel repository already exists at ${OUTDIR}/linux-stable"
    cd ${OUTDIR}/linux-stable
    
    # Ensure we have the correct version
    CURRENT_VERSION=$(git describe --tags 2>/dev/null || echo "unknown")
    if [ "$CURRENT_VERSION" != "${KERNEL_VERSION}" ]; then
        echo "Current version: $CURRENT_VERSION"
        echo "Switching to ${KERNEL_VERSION}..."
        
        # Check if tag exists locally
        if ! git rev-parse ${KERNEL_VERSION} >/dev/null 2>&1; then
            echo "Fetching tag ${KERNEL_VERSION}..."
            git fetch --depth 1 origin tag ${KERNEL_VERSION}
        fi
        
        git checkout ${KERNEL_VERSION}
    else
        echo "Already on correct version: ${KERNEL_VERSION}"
    fi
    cd ${OUTDIR}
fi

# Build kernel if Image doesn't exist
if [ ! -e ${OUTDIR}/linux-stable/arch/${ARCH}/boot/Image ]; then
    cd ${OUTDIR}/linux-stable
    
    echo "============================================"
    echo "Building Linux kernel..."
    echo "============================================"
    
    echo "Deep cleaning kernel build tree..."
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} mrproper
    
    echo "Configuring kernel for ${ARCH}..."
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} HOSTCC=${HOSTCC} defconfig
    
    echo "Building kernel image (this will take several minutes)..."
    make -j$(nproc) ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} HOSTCC=${HOSTCC} all
    
    echo "Building device tree..."
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} HOSTCC=${HOSTCC} dtbs
    
    echo "Kernel build complete!"
else
    echo "Kernel Image already exists, skipping build"
fi

echo "Copying kernel Image to ${OUTDIR}"
cp ${OUTDIR}/linux-stable/arch/${ARCH}/boot/Image ${OUTDIR}/

# ============================================
# CREATE ROOTFS STRUCTURE
# ============================================
echo "Creating root filesystem"
cd "${OUTDIR}"

if [ -d "${OUTDIR}/rootfs" ]; then
    echo "Deleting existing rootfs directory"
    sudo rm -rf ${OUTDIR}/rootfs
fi

echo "Creating rootfs directory structure"
mkdir -p ${OUTDIR}/rootfs
cd ${OUTDIR}/rootfs

# Create standard Linux directory structure
mkdir -p bin dev etc home lib lib64 proc sbin sys tmp usr var
mkdir -p usr/bin usr/lib usr/sbin
mkdir -p var/log
mkdir -p home/conf

# ============================================
# BUILD BUSYBOX
# ============================================
cd "${OUTDIR}"

if [ ! -d "${OUTDIR}/busybox" ]; then
    echo "Cloning BusyBox"
    git clone git://busybox.net/busybox.git
    cd busybox
    git checkout ${BUSYBOX_VERSION}
else
    cd busybox
fi

echo "Configuring BusyBox"
make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} distclean
make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} defconfig

echo "Building BusyBox"
make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} HOSTCC=${HOSTCC}

echo "Installing BusyBox to rootfs"
make CONFIG_PREFIX=${OUTDIR}/rootfs ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} install

# ============================================
# ADD LIBRARY DEPENDENCIES
# ============================================
echo "Adding library dependencies"
cd ${OUTDIR}/rootfs

SYSROOT=$(${CROSS_COMPILE}gcc -print-sysroot)
echo "Sysroot: ${SYSROOT}"

# Copy program interpreter
echo "Copying program interpreter"
cp -L ${SYSROOT}/lib/ld-linux-aarch64.so.1 lib/

# Copy shared libraries
echo "Copying shared libraries"
cp -L ${SYSROOT}/lib64/libm.so.6 lib64/
cp -L ${SYSROOT}/lib64/libresolv.so.2 lib64/
cp -L ${SYSROOT}/lib64/libc.so.6 lib64/

# ============================================
# BUILD WRITER APPLICATION
# ============================================
echo "Building writer application"
cd ${FINDER_APP_DIR}
make clean
make CROSS_COMPILE=${CROSS_COMPILE}

# ============================================
# COPY FINDER SCRIPTS AND FILES
# ============================================
echo "Copying finder scripts and executables to rootfs"

# Copy executables and scripts
cp ${FINDER_APP_DIR}/writer ${OUTDIR}/rootfs/home/
cp ${FINDER_APP_DIR}/finder.sh ${OUTDIR}/rootfs/home/
cp ${FINDER_APP_DIR}/finder-test.sh ${OUTDIR}/rootfs/home/
cp ${FINDER_APP_DIR}/autorun-qemu.sh ${OUTDIR}/rootfs/home/

# Copy configuration files
cp ${FINDER_APP_DIR}/conf/username.txt ${OUTDIR}/rootfs/home/conf/
cp ${FINDER_APP_DIR}/conf/assignment.txt ${OUTDIR}/rootfs/home/conf/

# Modify finder-test.sh to reference conf/assignment.txt
echo "Modifying finder-test.sh to use conf/assignment.txt"
cd ${OUTDIR}/rootfs/home
sed -i 's|../conf/assignment.txt|conf/assignment.txt|g' finder-test.sh

# Make scripts executable
chmod +x finder.sh finder-test.sh autorun-qemu.sh writer

# ============================================
# CREATE INITRAMFS - CORRECTED VERSION
# ============================================
echo "============================================"
echo "Creating initramfs with correct structure"
echo "============================================"

# Use /tmp for device node creation (works on NFS)
TEMP_ROOTFS=/tmp/rootfs_build_$$

# Clean up any previous temp directory
echo "Cleaning up any previous temporary directories..."
sudo rm -rf ${TEMP_ROOTFS}

# Copy rootfs to /tmp (local filesystem where mknod works)
echo "Copying rootfs to ${TEMP_ROOTFS}..."
cp -a ${OUTDIR}/rootfs ${TEMP_ROOTFS}

# CRITICAL: Change directory INTO the temporary rootfs
cd ${TEMP_ROOTFS}

# Create device nodes
echo "Creating device nodes..."
sudo mknod -m 666 dev/null c 1 3
sudo mknod -m 600 dev/console c 5 1

# Set ownership to root
echo "Setting ownership to root..."
sudo chown -R root:root *

# Create initramfs archive
echo "Creating initramfs.cpio.gz..."
find . -print0 | cpio --null -ov --format=newc 2>/dev/null | gzip -9 > ${OUTDIR}/initramfs.cpio.gz

# Return to safe directory before cleanup
cd /

# Clean up temporary directory
echo "Cleaning up temporary rootfs..."
sudo rm -rf ${TEMP_ROOTFS}

# ============================================
# VERIFY INITRAMFS
# ============================================
if [ ! -f ${OUTDIR}/initramfs.cpio.gz ]; then
    echo "ERROR: initramfs.cpio.gz was not created!"
    exit 1
fi

INITRAMFS_SIZE=$(du -h ${OUTDIR}/initramfs.cpio.gz | cut -f1)
echo "✓ initramfs.cpio.gz created (${INITRAMFS_SIZE})"

echo ""
echo "============================================"
echo "Build completed successfully!"
echo "============================================"
echo "Output directory: ${OUTDIR}"
echo "Kernel Image: ${OUTDIR}/Image"
echo "Initramfs: ${OUTDIR}/initramfs.cpio.gz (${INITRAMFS_SIZE})"
echo "============================================"
