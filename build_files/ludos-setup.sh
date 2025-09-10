#!/bin/bash

# LudOS Post-Installation Setup Script
# Run this script after the first boot to configure NVIDIA GRID licensing and services

set -euo pipefail

echo "=== LudOS Post-Installation Setup ==="

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root (use sudo)"
   exit 1
fi

# Copy NVIDIA GRID configuration template
echo "Setting up NVIDIA GRID licensing configuration..."
if [[ -f /etc/ludos/nvidia-gridd.conf.template ]]; then
    cp /etc/ludos/nvidia-gridd.conf.template /etc/nvidia/gridd.conf
    echo "NVIDIA GRID configuration template copied to /etc/nvidia/gridd.conf"
    echo "Please edit /etc/nvidia/gridd.conf with your license server details"
else
    echo "Warning: NVIDIA GRID configuration template not found"
fi

# Create Sunshine configuration directory
echo "Setting up Sunshine streaming server..."
mkdir -p /etc/sunshine
chown -R sunshine:sunshine /etc/sunshine 2>/dev/null || echo "Note: sunshine user not found, will be created on first run"

# Create Gamescope configuration
echo "Setting up Gamescope virtual display..."
mkdir -p /etc/ludos/gamescope
cat > /etc/ludos/gamescope/default.conf << 'EOF'
# Default Gamescope configuration for LudOS
# Virtual display settings
GAMESCOPE_WIDTH=1920
GAMESCOPE_HEIGHT=1080
GAMESCOPE_REFRESH=60

# Upscaling settings
GAMESCOPE_UPSCALE=1
GAMESCOPE_FILTER=linear

# NVIDIA specific settings
GAMESCOPE_BACKEND=drm
EOF

# Create systemd service for Gamescope
cat > /etc/systemd/system/ludos-gamescope.service << 'EOF'
[Unit]
Description=LudOS Gamescope Virtual Display
After=graphical.target nvidia-gridd.service
Wants=nvidia-gridd.service

[Service]
Type=simple
User=ludos
Group=ludos
Environment=DISPLAY=:1
ExecStart=/usr/bin/gamescope --backend drm --prefer-vk-device /dev/dri/renderD128 --force-grab-cursor --xwayland-count 1 --default-touch-mode 4 --hide-cursor-delay 3000 --fade-out-duration 200 -- steam -gamepadui
Restart=always
RestartSec=5

[Install]
WantedBy=graphical.target
EOF

# Create ludos user for gaming services
echo "Creating ludos user..."
useradd -m -s /bin/bash -G audio,video,input,render ludos 2>/dev/null || echo "ludos user already exists"

# Set up audio for headless operation
echo "Configuring audio system..."
systemctl --global enable pipewire.service
systemctl --global enable pipewire-pulse.service
systemctl --global enable wireplumber.service

# Enable and start services
echo "Enabling LudOS services..."
systemctl daemon-reload
systemctl enable ludos-gamescope.service
systemctl enable sunshine.service

echo ""
echo "=== LudOS Setup Complete ==="
echo ""
echo "Next steps:"
echo "1. Edit /etc/nvidia/gridd.conf with your NVIDIA license server details"
echo "2. Configure Sunshine by accessing the web interface at https://localhost:47990"
echo "3. Reboot the system to start all services"
echo "4. Check service status with: systemctl status ludos-gamescope sunshine nvidia-gridd"
echo ""
echo "For headless operation, connect via Moonlight client to this system's IP address"
