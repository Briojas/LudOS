#!/bin/bash
# Sign already-installed NVIDIA modules with MOK
# Run this after rpm-ostree install to sign modules in the overlay

set -euo pipefail

MOK_KEY="/etc/ludos/secureboot/MOK.priv"
MOK_CRT="/etc/ludos/secureboot/MOK.crt"

if [ "$EUID" -ne 0 ]; then
    echo "ERROR: This script must be run as root"
    exit 1
fi

if [ ! -f "$MOK_KEY" ] || [ ! -f "$MOK_CRT" ]; then
    echo "ERROR: MOK key/certificate not found at $MOK_KEY and $MOK_CRT"
    echo "Generate MOK first with ludos-tesla-setup"
    exit 1
fi

KERNEL_VERSION=$(uname -r)
MODULE_DIR="/usr/lib/modules/$KERNEL_VERSION/extra/nvidia-tesla"
SIGN_FILE="/usr/src/kernels/$KERNEL_VERSION/scripts/sign-file"

# Check for sign-file
if [ ! -x "$SIGN_FILE" ]; then
    echo "ERROR: sign-file not found at $SIGN_FILE"
    echo "Install kernel-devel: sudo rpm-ostree install kernel-devel"
    exit 1
fi

if [ ! -d "$MODULE_DIR" ]; then
    echo "ERROR: NVIDIA Tesla modules not found at $MODULE_DIR"
    exit 1
fi

echo "=== Signing NVIDIA Tesla Modules ==="
echo "Kernel: $KERNEL_VERSION"
echo "Modules: $MODULE_DIR"
echo "MOK Key: $MOK_KEY"
echo ""

# Create writable copy of modules
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

cp -a "$MODULE_DIR"/*.ko "$TEMP_DIR/"

# Sign each module
for ko in "$TEMP_DIR"/nvidia*.ko; do
    module_name=$(basename "$ko")
    echo "Signing $module_name..."
    
    if "$SIGN_FILE" sha256 "$MOK_KEY" "$MOK_CRT" "$ko"; then
        echo "  ✅ Signed successfully"
        
        # Copy signed module back (this requires writable overlay)
        cp -f "$ko" "$MODULE_DIR/$module_name"
    else
        echo "  ❌ Signing failed"
        exit 1
    fi
done

echo ""
echo "=== Verifying Signatures ==="
for ko in "$MODULE_DIR"/nvidia*.ko; do
    module_name=$(basename "$ko")
    if modinfo "$ko" | grep -q "sig_id"; then
        echo "  ✅ $module_name: Signed"
    else
        echo "  ❌ $module_name: NOT signed"
    fi
done

echo ""
echo "✅ All modules signed successfully!"
echo "Run 'sudo depmod -a' to update module dependencies"
echo "Then reboot to load signed modules"
