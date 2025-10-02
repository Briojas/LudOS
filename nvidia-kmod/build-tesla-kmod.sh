#!/bin/bash

# LudOS Tesla NVIDIA kmod Build Script
# Builds Tesla datacenter drivers using RPM Fusion toolset
# POST-INSTALL ONLY - User must download Tesla drivers themselves

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LUDOS_ROOT="$(dirname "$SCRIPT_DIR")"
# TESLA_VERSION is normally set by ludos-tesla-setup from the driver filename
# Default is only used if this script is run directly (not recommended)
TESLA_VERSION="${TESLA_VERSION:-580.82.07}"
BUILD_DIR="${BUILD_DIR:-$SCRIPT_DIR/build}"
SIGN_MODULES="${SIGN_MODULES:-0}"
ENROLL_MOK="${ENROLL_MOK:-0}"
MOK_DIR="${MOK_DIR:-/etc/ludos/secureboot}"
MOK_KEY="${MOK_KEY:-$MOK_DIR/MOK.key}"
MOK_CRT="${MOK_CRT:-$MOK_DIR/MOK.crt}"
MOK_DER="${MOK_DER:-$MOK_DIR/MOK.der}"

echo "=== LudOS Tesla NVIDIA kmod Builder ==="
echo "Tesla Driver Version: $TESLA_VERSION"
echo "Build Directory: $BUILD_DIR"
echo ""

# Check if running on Fedora/bootc system
if ! command -v rpm-ostree >/dev/null 2>&1 && ! grep -q "fedora" /etc/os-release; then
    echo "WARNING: This script is designed for Fedora/bootc systems"
    echo "Continuing anyway..."
fi

## NOTE: MOK enrollment staging occurs AFTER MOK generation below

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

# Optional: prepare Secure Boot signing
if [ "$SIGN_MODULES" = "1" ]; then
    echo "Secure Boot: signing of NVIDIA modules is ENABLED"
    # Ensure prerequisites
    MISSING_SB=()
    command -v openssl >/dev/null 2>&1 || MISSING_SB+=(openssl)
    command -v mokutil >/dev/null 2>&1 || MISSING_SB+=(mokutil)
    if [ ${#MISSING_SB[@]} -gt 0 ]; then
        echo "Missing Secure Boot tools: ${MISSING_SB[*]}"
        echo "Installing via rpm-ostree..."
        rpm-ostree install --apply-live "${MISSING_SB[@]}" || {
            echo "Failed to install Secure Boot tools"; exit 1; }
    fi
    # Ensure kernel-devel present (for sign-file)
    KERNEL_VERSION=$(uname -r)
    SIGN_FILE_PATH="/usr/src/kernels/$KERNEL_VERSION/scripts/sign-file"
    
    if [ ! -x "$SIGN_FILE_PATH" ]; then
        echo "sign-file not found at $SIGN_FILE_PATH"
        echo "Installing kernel-devel package..."
        
        if rpm-ostree install --apply-live kernel-devel; then
            echo "kernel-devel installed"
            
            # Verify sign-file now exists
            if [ ! -x "$SIGN_FILE_PATH" ]; then
                echo ""
                echo "❌ ERROR: sign-file still not available after kernel-devel installation"
                echo "This can happen on rpm-ostree systems where --apply-live doesn't"
                echo "immediately populate /usr/src/kernels."
                echo ""
                echo "SOLUTION:"
                echo "1. The kernel-devel package has been staged"
                echo "2. Reboot to activate it: sudo systemctl reboot"
                echo "3. After reboot, run this command again:"
                echo "   sudo ludos-tesla-setup install-tesla --secure-boot <driver.run>"
                echo ""
                exit 1
            fi
            echo "✅ sign-file is now available at $SIGN_FILE_PATH"
        else
            echo "Failed to install kernel-devel"
            exit 1
        fi
    else
        echo "✅ sign-file found at $SIGN_FILE_PATH"
    fi
    # Create persistent MOK if missing
    MOK_NEWLY_CREATED=false
    if [ ! -f "$MOK_KEY" ] || [ ! -f "$MOK_CRT" ]; then
        echo "Creating MOK under $MOK_DIR"
        mkdir -p "$MOK_DIR"
        openssl req -new -x509 -newkey rsa:2048 -nodes -days 36500 \
          -subj "/CN=LudOS NVIDIA Module Signing/" \
          -keyout "$MOK_KEY" -out "$MOK_CRT"
        # Convert certificate to DER for sign-file and mokutil
        openssl x509 -in "$MOK_CRT" -outform DER -out "$MOK_DER"
        echo "MOK generated: $MOK_CRT (PEM) and $MOK_DER (DER)"
        MOK_NEWLY_CREATED=true
    else
        # Ensure DER exists
        if [ ! -f "$MOK_DER" ]; then
            openssl x509 -in "$MOK_CRT" -outform DER -out "$MOK_DER"
        fi
        echo "Using existing MOK: $MOK_CRT (PEM) and $MOK_DER (DER)"
    fi
    
    # Stage MOK enrollment if newly created or not yet enrolled
    if [ "$MOK_NEWLY_CREATED" = "true" ] || [ "$ENROLL_MOK" = "1" ]; then
        echo ""
        echo "============================================"
        echo "MOK Enrollment Required for Secure Boot"
        echo "============================================"
        echo ""
        echo "To load signed NVIDIA modules on Secure Boot systems, you must"
        echo "enroll the Machine Owner Key (MOK) into your system firmware."
        echo ""
        echo "You will be prompted to create a one-time enrollment password."
        echo "This password will be used ONCE during the enrollment process"
        echo "on the next boot. You can use a simple password like '12345678'."
        echo ""
        echo "After reboot, a blue MOK Manager screen will appear. Follow these steps:"
        echo "  1. Select 'Enroll MOK'"
        echo "  2. Select 'Continue'"
        echo "  3. Select 'Yes'"
        echo "  4. Enter the password you set below"
        echo "  5. Reboot"
        echo ""
        
        # Import MOK (will prompt for password)
        if mokutil --import "$MOK_DER"; then
            echo ""
            echo "✅ MOK enrollment staged successfully!"
            echo "⚠️  IMPORTANT: Remember the password you just entered."
            echo "    You will need it on the blue MOK Manager screen after reboot."
            echo ""
        else
            echo ""
            echo "❌ ERROR: Failed to stage MOK enrollment"
            echo "You may need to run this manually:"
            echo "  sudo mokutil --import $MOK_DER"
            exit 1
        fi
    fi
fi

# Copy spec files and patches
echo "Copying spec files and patches..."
# Use simplified spec that doesn't require kmodtool metadata
if [ -f "$SCRIPT_DIR/nvidia-tesla-kmod-simple.spec" ]; then
    echo "Using simplified kmod spec (no kmodtool dependency)"
    cp "$SCRIPT_DIR/nvidia-tesla-kmod-simple.spec" "$BUILD_DIR/SPECS/nvidia-tesla-kmod.spec"
else
    cp "$SCRIPT_DIR/nvidia-tesla-kmod.spec" "$BUILD_DIR/SPECS/"
fi
cp "$SCRIPT_DIR/nvidia-tesla-utils.spec" "$BUILD_DIR/SPECS/"
cp "$SCRIPT_DIR/nvidia-kmodtool-excludekernel-filterfile" "$BUILD_DIR/SOURCES/"
cp "$SCRIPT_DIR/make_modeset_default.patch" "$BUILD_DIR/SOURCES/"
cp "$SCRIPT_DIR/ludos-tesla-optimizations.patch" "$BUILD_DIR/SOURCES/"
cp "$SCRIPT_DIR/nvidia-kmod-noopen-checks" "$BUILD_DIR/SOURCES/"
cp "$SCRIPT_DIR/nvidia-kmod-noopen-pciids.txt" "$BUILD_DIR/SOURCES/"
# Service for creating NVIDIA device nodes at boot (used by utils spec)
if [ -f "$SCRIPT_DIR/nvidia-device-setup.service" ]; then
    cp "$SCRIPT_DIR/nvidia-device-setup.service" "$BUILD_DIR/SOURCES/"
fi

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

# Prepare rpmbuild defines for optional module signing
SIGN_DEFINES=()
if [ "$SIGN_MODULES" = "1" ]; then
    SIGN_DEFINES=(--define "mok_key $MOK_KEY" --define "mok_crt $MOK_DER")
fi

if rpmbuild --define "_topdir $BUILD_DIR" \
         --define "version $TESLA_VERSION" \
         --define "kernels $KERNEL_VERSION" \
         --define "kernel_version $KERNEL_VERSION" \
         --define "kernel_release $KERNEL_RELEASE" \
         --define "kernel_base $KERNEL_BASE" \
         --define "kernel_dist $KERNEL_DIST" \
         ${SIGN_DEFINES[@]+"${SIGN_DEFINES[@]}"} \
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
    kmod_example=$(find "$RPM_DIR" \( -name 'kmod-nvidia-tesla-*.rpm' -o -name 'nvidia-tesla-kmod-*.rpm' \) -print -quit)
    if [ -n "$kmod_example" ]; then
        echo "sudo rpm-ostree install \"$kmod_example\""
    else
        echo "(kmod RPM not located; see package list above)"
    fi
    echo ""
    echo "Or for traditional systems:"
    first_rpm=$(find "$RPM_DIR" -name '*.rpm' -print -quit)
    if [ -n "$first_rpm" ]; then
        echo "sudo dnf install \"$first_rpm\""
    else
        echo "(RPM not located; see package list above)"
    fi
else
    echo ""
    echo "=== Build Failed! ==="
    echo "Check build logs for errors"
    exit 1
fi

echo "Tesla kmod build completed successfully!"
