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

# Configure Sunshine streaming server (Bazzite-style approach)
echo "Configuring Sunshine streaming server..."

# Check if Sunshine was installed during build time
if [ -f /usr/bin/sunshine ]; then
    echo "Sunshine found, configuring service..."
    
    # On rpm-ostree, capabilities must be set by the package itself (can't modify /usr)
    # Check if we're on a mutable system before trying setcap
    if [ ! -f /run/ostree-booted ]; then
        setcap cap_sys_admin+ep /usr/bin/sunshine || echo "Warning: Could not set capabilities for Sunshine"
    else
        echo "Note: Running on rpm-ostree - capabilities should be set by package"
    fi
    
    # Create Sunshine configuration directory for ludos user
    mkdir -p /var/home/ludos/.config/sunshine
    
    # Create Sunshine configuration file
    echo "Creating Sunshine configuration for X11 capture..."
    cat > /var/home/ludos/.config/sunshine/sunshine.conf << 'SUNCONF'
# LudOS Sunshine Configuration
# Optimized for virtual display streaming with NVIDIA Tesla GPU

# Use X11 capture (not KMS)
capture = x11

# Encoder configuration - use NVENC for hardware encoding
encoder = nvenc

# NVENC preset (valid options: default, slow, medium, fast, hp, hq, bd, ll, llhq, lossless)
nvenc_preset = llhq

# NVENC features
nvenc_realtime_hags = disabled
nvenc_vbv_increase = disabled

# Network settings
port = 47989
origin_web_ui_allowed = wan

# General settings
min_log_level = info
SUNCONF
    
    chown -R ludos:ludos /var/home/ludos/.config/sunshine
    
    # Create systemd service if it doesn't exist
    if [ ! -f /etc/systemd/system/sunshine.service ]; then
        echo "Creating Sunshine systemd service..."
        cat > /etc/systemd/system/sunshine.service << 'SUNEOF'
[Unit]
Description=Sunshine Streaming Server
After=network-online.target ludos-gamescope-display.service user@1000.service
Wants=network-online.target ludos-gamescope-display.service

[Service]
Type=simple
User=ludos
Group=ludos
# Use gamescope display (headless mode creates :0 and :1, use :0 for capture)
Environment=HOME=/var/home/ludos
Environment=DISPLAY=:0
Environment=XDG_RUNTIME_DIR=/run/user/1000
# NVIDIA configuration
Environment=__GLX_VENDOR_LIBRARY_NAME=nvidia
Environment=__NV_PRIME_RENDER_OFFLOAD=1
Environment=LD_LIBRARY_PATH=/usr/lib64:/usr/local/lib64
# Give Xwayland time to fully initialize before starting capture
ExecStartPre=/bin/sleep 3
ExecStart=/usr/bin/sunshine
Restart=on-failure
RestartSec=5s
# Required capabilities for GPU access and input capture
AmbientCapabilities=CAP_SYS_ADMIN CAP_SYS_NICE CAP_IPC_LOCK
CapabilityBoundingSet=CAP_SYS_ADMIN CAP_SYS_NICE CAP_IPC_LOCK
# Grant access to DRI devices
SupplementaryGroups=video render input
# Allow access to GPU devices (DRI for display, NVIDIA for CUDA/NVENC)
DeviceAllow=/dev/dri/card0 rw
DeviceAllow=/dev/dri/card1 rw
DeviceAllow=/dev/dri/renderD128 rw
DeviceAllow=/dev/dri/renderD129 rw
# NVIDIA CUDA devices for NVENC hardware encoding
DeviceAllow=/dev/nvidia0 rw
DeviceAllow=/dev/nvidiactl rw
DeviceAllow=/dev/nvidia-modeset rw
DeviceAllow=/dev/nvidia-uvm rw
DeviceAllow=/dev/nvidia-uvm-tools rw
# Input device access for virtual keyboard/mouse/gamepad
DeviceAllow=/dev/uinput rw
DeviceAllow=/dev/input/event* rw
DeviceAllow=char-input rw

[Install]
WantedBy=graphical.target
SUNEOF
        systemctl daemon-reload
    fi
    
    echo "Sunshine configuration completed"
else
    echo "Sunshine not found - attempting post-install using rpm-ostree..."
    
    # Use rpm-ostree for post-install package management (bootc compatible)
    echo "Installing Sunshine using rpm-ostree..."
    
    # Enable COPR repository using rpm-ostree
    if command -v rpm-ostree >/dev/null 2>&1; then
        # Add official LizardByte COPR repository
        curl -s https://copr.fedorainfracloud.org/coprs/lizardbyte/stable/repo/fedora-$(rpm -E %fedora)/lizardbyte-stable-fedora-$(rpm -E %fedora).repo -o /etc/yum.repos.d/lizardbyte-sunshine.repo
        
        # Install Sunshine with official package (capital S)
        # Note: Do NOT use --apply-live if Tesla drivers are manually installed
        # It can cause conflicts with already-loaded kernel modules
        rpm-ostree install -y Sunshine || {
            echo "Warning: rpm-ostree installation failed"
            echo "Sunshine will need to be installed manually after reboot"
            echo "Run: rpm-ostree install Sunshine && systemctl reboot"
        }
        
        echo ""
        echo "IMPORTANT: Sunshine has been staged for installation."
        echo "You MUST reboot for changes to take effect:"
        echo "  sudo systemctl reboot"
    else
        echo "Warning: rpm-ostree not available, Sunshine installation skipped"
        echo "This system may not be using bootc/rpm-ostree"
    fi
fi

# Configure Gamescope Display Service
echo "Setting up Gamescope display service..."
echo ""
echo "The new ludos-gamescope-display.service provides:"
echo "  - Virtual display on :99 (via Gamescope headless mode)"
echo "  - Hardware-accelerated rendering with NVIDIA Tesla GPU"
echo "  - Capturable display for Sunshine streaming"
echo "  - Configurable backends (headless, drm, xvfb)"
echo ""
echo "Manage with: ludos-display <command>"
echo "  Commands: start, stop, status, enable, disable, logs"
echo ""
echo "Default configuration: 1920x1080@60Hz with headless backend (NVIDIA GPU)"
echo ""

# Create ludos user for gaming services
echo "Creating ludos user..."
useradd -m -s /bin/bash -G audio,video,input,render ludos 2>/dev/null || echo "ludos user already exists"

# Set up audio for headless operation
echo "Configuring audio system..."
systemctl --global enable pipewire.service
systemctl --global enable pipewire-pulse.service
systemctl --global enable wireplumber.service

# Enable NVIDIA device setup service (creates /dev/nvidia* nodes)
echo "Enabling NVIDIA device setup service..."
if systemctl list-unit-files nvidia-device-setup.service >/dev/null 2>&1; then
    systemctl enable nvidia-device-setup.service
    systemctl start nvidia-device-setup.service || echo "Warning: Could not start device setup service"
    echo "NVIDIA device setup service enabled"
else
    echo "Warning: nvidia-device-setup.service not found"
fi

# Install and enable NVIDIA GPU persistence mode service
echo "Setting up NVIDIA GPU persistence mode..."
if command -v nvidia-smi >/dev/null 2>&1; then
    # Copy persistence service file
    cp /etc/ludos/nvidia-persistence.service /etc/systemd/system/
    systemctl daemon-reload
    systemctl enable nvidia-persistence.service
    systemctl start nvidia-persistence.service || echo "Warning: Could not start persistence service"
    echo "GPU persistence mode service enabled"
else
    echo "Warning: nvidia-smi not found, skipping GPU persistence setup"
fi

# Enable and start services
echo "Enabling LudOS services..."
systemctl daemon-reload
systemctl enable ludos-gamescope-display.service
echo "Gamescope display service enabled"

# Only enable sunshine service if it exists
if systemctl list-unit-files sunshine.service >/dev/null 2>&1; then
    systemctl enable sunshine.service
    echo "Sunshine service enabled"
else
    echo "Warning: sunshine.service not found - skipping service enablement"
    echo "If Sunshine was installed via rpm-ostree, please reboot and run this script again"
fi

# Enable Steam Big Picture service if it exists
if systemctl list-unit-files steam-bigpicture.service >/dev/null 2>&1; then
    systemctl enable steam-bigpicture.service
    echo "Steam Big Picture service enabled"
else
    echo "Warning: steam-bigpicture.service not found - skipping service enablement"
fi

echo ""
echo "=== LudOS Setup Complete ==="
echo ""
echo "Next steps:"
echo "1. Edit /etc/nvidia/gridd.conf with your NVIDIA license server details"
echo "2. Configure Sunshine by accessing the web interface at https://localhost:47990"
echo "3. Reboot the system to start all services"
echo "4. Check service status with: systemctl status ludos-gamescope-display sunshine nvidia-gridd"
echo ""
echo "Display Management Commands:"
echo "  ludos-display status      - Check display service status"
echo "  ludos-display start       - Start the display"
echo "  ludos-display logs        - View display logs"
echo "  ludos-display set-backend - Change display backend (xvfb/headless/drm)"
echo ""
echo "For headless operation, connect via Moonlight client to this system's IP address"
