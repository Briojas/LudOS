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
    
    # Create Sunshine configuration directory
    mkdir -p /etc/sunshine
    chown -R sunshine:sunshine /etc/sunshine 2>/dev/null || echo "Note: sunshine user not found, will be created on first run"
    
    # Create systemd service if it doesn't exist
    if [ ! -f /etc/systemd/system/sunshine.service ]; then
        echo "Creating Sunshine systemd service..."
        cat > /etc/systemd/system/sunshine.service << 'SUNEOF'
[Unit]
Description=Sunshine Streaming Server
After=network-online.target ludos-gamescope.service user@1000.service
Wants=network-online.target ludos-gamescope.service

[Service]
Type=simple
User=ludos
Group=ludos
# Use same display as gamescope (:99)
Environment=HOME=/var/home/ludos
Environment=DISPLAY=:99
Environment=XDG_RUNTIME_DIR=/run/user/1000
# NVIDIA configuration
Environment=__GLX_VENDOR_LIBRARY_NAME=nvidia
Environment=LD_LIBRARY_PATH=/usr/lib64:/usr/local/lib64
ExecStart=/usr/bin/sunshine
Restart=on-failure
RestartSec=5s
# Required capabilities for GPU access and input capture
AmbientCapabilities=CAP_SYS_ADMIN CAP_SYS_NICE CAP_IPC_LOCK
CapabilityBoundingSet=CAP_SYS_ADMIN CAP_SYS_NICE CAP_IPC_LOCK
# Grant access to DRI devices
SupplementaryGroups=video render input

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
Description=LudOS Gamescope Virtual Display with Steam
After=nvidia-device-setup.service graphical.target
Wants=nvidia-device-setup.service
# Wait for user session to be ready
After=user@1000.service
Wants=user@1000.service

[Service]
Type=simple
User=ludos
Group=ludos
# Use Gamescope's built-in headless mode on display :99
Environment=DISPLAY=:99
Environment=XDG_RUNTIME_DIR=/run/user/1000
# NVIDIA configuration
Environment=__GLX_VENDOR_LIBRARY_NAME=nvidia
Environment=VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/nvidia_icd.json
Environment=__NV_PRIME_RENDER_OFFLOAD=1
Environment=__VK_LAYER_NV_optimus=NVIDIA_only
# Gamescope with headless backend (requires no X server)
# Use --prefer-vk-device to select NVIDIA GPU explicitly
ExecStart=/usr/bin/gamescope --headless -w 1920 -h 1080 -W 1920 -H 1080 -r 60 --prefer-vk-device /dev/dri/card1 -- steam -gamepadui
Restart=on-failure
RestartSec=10
# Grant GPU access
SupplementaryGroups=video render input

[Install]
WantedBy=graphical.target
EOF

echo ""
echo "Gamescope service configured for headless gaming:"
echo "  - Xvfb provides virtual X server on :99"
echo "  - Gamescope runs Steam Big Picture with Tesla GPU acceleration"
echo "  - Sunshine streams the gamescope display to Moonlight clients"
echo ""

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

# Only enable sunshine service if it exists
if systemctl list-unit-files sunshine.service >/dev/null 2>&1; then
    systemctl enable sunshine.service
    echo "Sunshine service enabled"
else
    echo "Warning: sunshine.service not found - skipping service enablement"
    echo "If Sunshine was installed via rpm-ostree, please reboot and run this script again"
fi

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
