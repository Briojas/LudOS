#!/bin/bash

# LudOS Tesla NVIDIA kmod Build Script
# Builds Tesla datacenter drivers using RPM Fusion toolset
# POST-INSTALL ONLY - User must download Tesla drivers themselves

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LUDOS_ROOT="$(dirname "$SCRIPT_DIR")"
TESLA_VERSION="${TESLA_VERSION:-580.82.07}"
BUILD_DIR="${BUILD_DIR:-$SCRIPT_DIR/build}"

echo "=== LudOS Tesla NVIDIA kmod Builder ==="
echo "Tesla Driver Version: $TESLA_VERSION"
echo "Build Directory: $BUILD_DIR"
echo ""

# Check if running on Fedora/bootc system
if ! command -v rpm-ostree >/dev/null 2>&1 && ! grep -q "fedora" /etc/os-release; then
    echo "WARNING: This script is designed for Fedora/bootc systems"
    echo "Continuing anyway..."
fi

# Create build environment
echo "Setting up build environment..."
mkdir -p "$BUILD_DIR"/{BUILD,BUILDROOT,RPMS,SRPMS,SOURCES,SPECS}

# Check build dependencies (should already be installed)
echo "Checking build dependencies..."

# Check for essential commands first
echo "Verifying essential build tools..."
ESSENTIAL_MISSING=()

for cmd in gcc make curl; do
    if ! command -v $cmd >/dev/null 2>&1; then
        ESSENTIAL_MISSING+=("$cmd")
    fi
done

if [ ${#ESSENTIAL_MISSING[@]} -gt 0 ]; then
    echo "ERROR: Essential build tools missing: ${ESSENTIAL_MISSING[*]}"
    echo "This indicates a serious system configuration issue"
    exit 1
fi

# Check for kernel development packages (these are the most likely to be missing)
KERNEL_MISSING=()
if ! rpm -q kernel-devel >/dev/null 2>&1; then
    KERNEL_MISSING+=("kernel-devel")
fi
if ! rpm -q kernel-headers >/dev/null 2>&1; then
    KERNEL_MISSING+=("kernel-headers")
fi

# Install only kernel packages if missing (avoid rpm-ostree conflicts)
if [ ${#KERNEL_MISSING[@]} -gt 0 ]; then
    echo "Missing kernel development packages: ${KERNEL_MISSING[*]}"
    echo "Installing via rpm-ostree..."
    rpm-ostree install --apply-live "${KERNEL_MISSING[@]}" || {
        echo "Failed to install kernel packages"
        echo "You may need to reboot and try again"
        exit 1
    }
fi

# Check wget availability (informational only - spec file has curl fallback)
if ! command -v wget >/dev/null 2>&1; then
    echo "Note: wget command not available (using curl fallback in build)"
fi

echo "All required build dependencies are available"

# Copy spec files and patches
echo "Copying spec files and patches..."
cp "$SCRIPT_DIR/nvidia-tesla-kmod.spec" "$BUILD_DIR/SPECS/"
cp "$SCRIPT_DIR/nvidia-tesla-utils.spec" "$BUILD_DIR/SPECS/"
cp "$SCRIPT_DIR/nvidia-kmodtool-excludekernel-filterfile" "$BUILD_DIR/SOURCES/"
cp "$SCRIPT_DIR/make_modeset_default.patch" "$BUILD_DIR/SOURCES/"
cp "$SCRIPT_DIR/ludos-tesla-optimizations.patch" "$BUILD_DIR/SOURCES/"
cp "$SCRIPT_DIR/nvidia-kmod-noopen-checks" "$BUILD_DIR/SOURCES/"
cp "$SCRIPT_DIR/nvidia-kmod-noopen-pciids.txt" "$BUILD_DIR/SOURCES/"

# Check for Tesla driver (user must provide)
echo "Checking for Tesla driver $TESLA_VERSION..."
TESLA_FILE="$BUILD_DIR/SOURCES/NVIDIA-Linux-x86_64-$TESLA_VERSION.run"

if [ ! -f "$TESLA_FILE" ]; then
    echo "ERROR: Tesla driver not found at $TESLA_FILE"
    echo ""
    echo "NVIDIA LICENSING COMPLIANCE:"
    echo "Tesla datacenter drivers must be downloaded by the end user."
    echo "LudOS cannot redistribute NVIDIA proprietary drivers."
    echo ""
    echo "Please download the Tesla driver manually:"
    echo "1. Visit: https://www.nvidia.com/Download/index.aspx"
    echo "2. Select: Tesla / Linux 64-bit / $TESLA_VERSION"
    echo "3. Download: NVIDIA-Linux-x86_64-$TESLA_VERSION.run"
    echo "4. Place in: $BUILD_DIR/SOURCES/"
    echo "5. Re-run this script"
    echo ""
    echo "Alternative: Use environment variable to specify driver location:"
    echo "TESLA_DRIVER_PATH=/path/to/driver.run $0"
    exit 1
fi

echo "Found Tesla driver: $TESLA_FILE"

# Extract and create tarball
echo "Extracting Tesla driver..."
cd "$BUILD_DIR/SOURCES"

# Clean up any previous extraction attempts
if [ -d "nvidia-tesla-driver-$TESLA_VERSION" ]; then
    echo "Removing previous extraction directory..."
    rm -rf "nvidia-tesla-driver-$TESLA_VERSION"
fi

# Extract Tesla driver
echo "Running NVIDIA installer extraction..."
if sh "NVIDIA-Linux-x86_64-$TESLA_VERSION.run" --extract-only --target "nvidia-tesla-driver-$TESLA_VERSION/" 2>&1 | tee "$BUILD_DIR/extraction.log"; then
    echo "Tesla driver extracted successfully"
else
    echo "ERROR: Failed to extract Tesla driver"
    echo "Extraction log saved to: $BUILD_DIR/extraction.log"
    cat "$BUILD_DIR/extraction.log"
    exit 1
fi

echo "Creating Tesla driver tarball..."
tar -cJf "nvidia-tesla-driver-$TESLA_VERSION.tar.xz" "nvidia-tesla-driver-$TESLA_VERSION/"

# Get current kernel version
KERNEL_VERSION=$(uname -r)
KERNEL_RELEASE=$(echo "$KERNEL_VERSION" | cut -d'-' -f2-)
KERNEL_BASE=$(echo "$KERNEL_VERSION" | cut -d'-' -f1)
KERNEL_DIST=$(echo "$KERNEL_VERSION" | sed 's/.*\(\.[a-z][a-z0-9]*[0-9]\).*/\1/')

echo "Building for kernel: $KERNEL_VERSION"
echo "Kernel base: $KERNEL_BASE"
echo "Kernel release: $KERNEL_RELEASE"
echo "Kernel dist: $KERNEL_DIST"

# Build the RPM
echo "Building Tesla kmod RPM..."
echo "Using kernel version: $KERNEL_VERSION"
echo "Build log will be saved to: $BUILD_DIR/build.log"

if rpmbuild --define "_topdir $BUILD_DIR" \
         --define "version $TESLA_VERSION" \
         --define "kernel_version $KERNEL_VERSION" \
         --define "kernel_release $KERNEL_RELEASE" \
         --define "kernel_base $KERNEL_BASE" \
         --define "kernel_dist $KERNEL_DIST" \
         -bb "$BUILD_DIR/SPECS/nvidia-tesla-kmod.spec" 2>&1 | tee "$BUILD_DIR/build.log"; then
    echo "RPM build completed successfully"
else
    echo "ERROR: RPM build failed"
    echo "Build log saved to: $BUILD_DIR/build.log"
    echo "Last 20 lines of build log:"
    tail -20 "$BUILD_DIR/build.log"
    exit 1
fi

echo "Building Tesla user-space utilities RPM..."
echo "Utilities build log will be saved to: $BUILD_DIR/utils-build.log"

if rpmbuild --define "_topdir $BUILD_DIR" \
         --define "version $TESLA_VERSION" \
         -bb "$BUILD_DIR/SPECS/nvidia-tesla-utils.spec" 2>&1 | tee "$BUILD_DIR/utils-build.log"; then
    echo "Tesla utilities RPM build completed successfully"
else
    echo "ERROR: Tesla utilities RPM build failed"
    echo "Utilities build log saved to: $BUILD_DIR/utils-build.log"
    echo "Last 20 lines of utilities build log:"
    tail -20 "$BUILD_DIR/utils-build.log"
    exit 1
fi

# Check build results
RPM_DIR="$BUILD_DIR/RPMS"
if [ -d "$RPM_DIR" ] && [ "$(find "$RPM_DIR" -name '*.rpm' | wc -l)" -gt 0 ]; then
    echo ""
    echo "=== Build Successful! ==="
    echo "Tesla kmod packages built:"
    find "$RPM_DIR" -name '*.rpm' -exec basename {} \;
    echo ""
    echo "Installation command (kmods only):"
    echo "sudo rpm-ostree install $(find \"$RPM_DIR\" -name '*nvidia-tesla-kmod*.rpm' | head -1)"
    echo ""
    echo "Or for traditional systems:"
    echo "sudo dnf install $(find "$RPM_DIR" -name '*.rpm' | head -1)"
else
    echo ""
    echo "=== Build Failed! ==="
    echo "Check build logs for errors"
    exit 1
fi

echo "Tesla kmod build completed successfully!"
