#!/bin/bash
# Check if NVIDIA modules were actually signed during build

set -euo pipefail

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root: sudo $0"
    exit 1
fi

echo "=== NVIDIA Tesla Module Signing Diagnostic ==="
echo ""

KERNEL_VERSION=$(uname -r)
MODULE_DIR="/usr/lib/modules/$KERNEL_VERSION/extra/nvidia-tesla"

if [ ! -d "$MODULE_DIR" ]; then
    echo "❌ NVIDIA Tesla modules not found at $MODULE_DIR"
    exit 1
fi

echo "Kernel Version: $KERNEL_VERSION"
echo "Module Directory: $MODULE_DIR"
echo ""

echo "=== Checking Module Signatures ==="
for ko in "$MODULE_DIR"/nvidia*.ko; do
    module_name=$(basename "$ko")
    echo "Checking: $module_name"
    
    # Check if module has signature
    if modinfo "$ko" | grep -q "sig_id"; then
        echo "  ✅ Module IS signed"
        modinfo "$ko" | grep -E "sig_id|sig_key|signer" | sed 's/^/    /'
    else
        echo "  ❌ Module is NOT signed"
        echo "    This will cause 'Key was rejected by service' on Secure Boot systems"
    fi
    echo ""
done

echo "=== Checking MOK Enrollment ==="
if mokutil --sb-state 2>/dev/null | grep -q "SecureBoot enabled"; then
    echo "✅ Secure Boot is enabled"
    echo ""
    echo "Enrolled MOKs:"
    mokutil --list-enrolled 2>/dev/null | grep -A 3 "LudOS" || echo "  ❌ No LudOS MOK found"
else
    echo "⚠️  Secure Boot is disabled or not supported"
fi

echo ""
echo "=== Checking Build Log ==="
BUILD_LOG="/etc/ludos/nvidia-kmod/build/build.log"
if [ -f "$BUILD_LOG" ]; then
    echo "Looking for signing output in build log..."
    if grep -q "=== Module Signing with MOK ===" "$BUILD_LOG"; then
        echo "✅ Signing section found in build log"
        echo ""
        echo "Signing output from build:"
        grep -A 40 "=== Module Signing with MOK ===" "$BUILD_LOG" | head -50
    else
        echo "❌ Signing section NOT found in build log"
        echo "This means modules were NOT signed during build!"
        echo ""
        echo "Checking if mok_key was defined:"
        grep -i "mok" "$BUILD_LOG" | head -10 || echo "No MOK references found"
    fi
else
    echo "⚠️  Build log not found at $BUILD_LOG"
fi

echo ""
echo "=== Summary ==="
echo "To fix Secure Boot module loading:"
echo "1. Ensure sign-file exists: ls -la /usr/src/kernels/$KERNEL_VERSION/scripts/sign-file"
echo "2. Check if MOK files exist: ls -la /etc/ludos/secureboot/"
echo "3. Review build log: sudo cat $BUILD_LOG | grep -A 50 'Module Signing'"
echo "4. If signing failed, reboot to activate kernel-devel and rebuild"
