#!/bin/bash

# LudOS Steam Service Hotfix
# Adds Steam Big Picture service to existing deployment

set -euo pipefail

echo "=== LudOS Steam Service Hotfix ==="
echo ""
echo "This adds Steam Big Picture mode service to your LudOS deployment"
echo ""

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    echo "ERROR: Do not run this script as root. Run as your normal user."
    exit 1
fi

echo "[1/4] Creating Steam Big Picture systemd service..."
sudo tee /etc/systemd/system/steam-bigpicture.service > /dev/null << 'STEAMSERVICE'
[Unit]
Description=Steam Big Picture Mode
Documentation=https://store.steampowered.com/bigpicture
After=ludos-gamescope-display.service user@1000.service
Wants=ludos-gamescope-display.service user@1000.service
# Start after Gamescope display is ready
Requires=ludos-gamescope-display.service

[Service]
Type=simple
User=ludos
Group=ludos

# Use Gamescope's primary display
Environment=DISPLAY=:0
Environment=HOME=/var/home/ludos
Environment=XDG_RUNTIME_DIR=/run/user/1000

# NVIDIA environment
Environment=__GLX_VENDOR_LIBRARY_NAME=nvidia
Environment=__NV_PRIME_RENDER_OFFLOAD=1
Environment=__VK_LAYER_NV_optimus=NVIDIA_only
Environment=LD_LIBRARY_PATH=/usr/lib64:/usr/local/lib64

# Steam environment
Environment=STEAM_RUNTIME=1
Environment=STEAM_RUNTIME_PREFER_HOST_LIBRARIES=0

# Wait for Gamescope display to fully initialize
ExecStartPre=/bin/sleep 5

# Launch Steam in Big Picture mode
# Use -gamepadui for the newer Big Picture interface
ExecStart=/usr/bin/steam -gamepadui -fulldesktopres

# Restart if Steam crashes
Restart=on-failure
RestartSec=10s

# Grant GPU access
SupplementaryGroups=video render input audio

# Allow access to DRI devices (GPU)
DeviceAllow=/dev/dri/card0 rw
DeviceAllow=/dev/dri/card1 rw
DeviceAllow=/dev/dri/renderD128 rw
DeviceAllow=/dev/dri/renderD129 rw

# Allow access to NVIDIA devices
DeviceAllow=/dev/nvidia0 rw
DeviceAllow=/dev/nvidia1 rw
DeviceAllow=/dev/nvidiactl rw
DeviceAllow=/dev/nvidia-modeset rw
DeviceAllow=/dev/nvidia-uvm rw
DeviceAllow=/dev/nvidia-uvm-tools rw

# Input device access
DeviceAllow=/dev/uinput rw
DeviceAllow=/dev/input/event* rw
DeviceAllow=char-input rw

[Install]
WantedBy=graphical.target
STEAMSERVICE

echo "[2/4] Creating ludos-steam management command..."
sudo tee /usr/local/bin/ludos-steam > /dev/null << 'STEAMCMD'
#!/bin/bash

# LudOS Steam Management Command

set -euo pipefail

SERVICE_NAME="steam-bigpicture.service"

case "${1:-}" in
    start)
        echo "Starting Steam Big Picture..."
        sudo systemctl start "$SERVICE_NAME"
        sleep 3
        echo "Steam should now be visible in Moonlight stream"
        ;;
    stop)
        echo "Stopping Steam..."
        sudo systemctl stop "$SERVICE_NAME"
        ;;
    restart)
        echo "Restarting Steam..."
        sudo systemctl restart "$SERVICE_NAME"
        ;;
    status)
        systemctl status "$SERVICE_NAME" --no-pager -l
        ;;
    enable)
        echo "Enabling Steam auto-start..."
        sudo systemctl enable "$SERVICE_NAME"
        ;;
    disable)
        echo "Disabling Steam auto-start..."
        sudo systemctl disable "$SERVICE_NAME"
        ;;
    logs)
        journalctl -u "$SERVICE_NAME" -n 50 --no-pager
        ;;
    *)
        echo "Usage: ludos-steam {start|stop|restart|status|enable|disable|logs}"
        echo ""
        echo "Commands:"
        echo "  start    - Start Steam Big Picture"
        echo "  stop     - Stop Steam"
        echo "  restart  - Restart Steam"
        echo "  status   - Show service status"
        echo "  enable   - Enable auto-start on boot"
        echo "  disable  - Disable auto-start"
        echo "  logs     - View Steam logs"
        exit 1
        ;;
esac
STEAMCMD

sudo chmod +x /usr/local/bin/ludos-steam

echo "[3/4] Reloading systemd and enabling service..."
sudo systemctl daemon-reload
sudo systemctl enable steam-bigpicture.service

echo "[4/4] Starting Steam Big Picture..."
sudo systemctl start steam-bigpicture.service

echo ""
echo "=== Hotfix Complete ==="
echo ""
echo "Waiting for Steam to start..."
sleep 10

echo ""
echo "Service status:"
systemctl status steam-bigpicture.service --no-pager -l || true

echo ""
echo "Checking for Steam process:"
if pgrep -u ludos steam; then
    echo "✓ Steam is running!"
    echo ""
    echo "✓ Check your Moonlight stream - you should now see Steam Big Picture!"
else
    echo "✗ Steam is not running yet"
    echo ""
    echo "Check logs with:"
    echo "  ludos-steam logs"
    echo "  journalctl -u steam-bigpicture.service -f"
fi

echo ""
echo "Steam management commands:"
echo "  ludos-steam start    - Start Steam"
echo "  ludos-steam stop     - Stop Steam"
echo "  ludos-steam status   - Check status"
echo "  ludos-steam logs     - View logs"
echo ""
echo "Steam is configured to auto-start on boot."
echo "If you see Steam in your Moonlight stream, you're all set!"
