#!/bin/bash
# LudOS Steam Wrapper
# Provides proper environment for Steam to run from systemd

set -e

# Ensure we're running as the ludos user
if [ "$(id -u)" != "1000" ]; then
    echo "Error: Steam wrapper must run as ludos user (UID 1000)" >&2
    exit 1
fi

# Set up environment if not already set
export DISPLAY="${DISPLAY:-:0}"
export HOME="${HOME:-/var/home/ludos}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/1000}"
export DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=/run/user/1000/bus}"
export XAUTHORITY="${XAUTHORITY:-/dev/null}"

# NVIDIA environment
export __GLX_VENDOR_LIBRARY_NAME="${__GLX_VENDOR_LIBRARY_NAME:-nvidia}"
export __NV_PRIME_RENDER_OFFLOAD="${__NV_PRIME_RENDER_OFFLOAD:-1}"
export __VK_LAYER_NV_optimus="${__VK_LAYER_NV_optimus:-NVIDIA_only}"
export VK_ICD_FILENAMES="${VK_ICD_FILENAMES:-/usr/share/vulkan/icd.d/nvidia_icd.json}"
export DRI_PRIME="${DRI_PRIME:-1}"
export LD_LIBRARY_PATH="${LD_LIBRARY_PATH:-/usr/lib64:/usr/local/lib64}"

# Steam environment
export STEAM_RUNTIME="${STEAM_RUNTIME:-1}"
export STEAM_RUNTIME_PREFER_HOST_LIBRARIES="${STEAM_RUNTIME_PREFER_HOST_LIBRARIES:-0}"

# Log startup
echo "[$(date)] LudOS Steam Wrapper: Starting Steam"
echo "[$(date)] Display: $DISPLAY"
echo "[$(date)] User: $(whoami) (UID: $(id -u))"

# Launch Steam
exec /usr/bin/steam "$@"
