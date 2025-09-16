#!/bin/bash

set -ouex pipefail

### LudOS - Headless Gaming VM Build Script
### Installs NVIDIA datacenter drivers, Gamescope, Sunshine, and gaming components

echo "Starting LudOS build process..."

### System packages and dependencies
echo "Installing base system packages..."
dnf5 install -y \
    tmux \
    htop \
    curl \
    wget \
    git \
    kernel-devel \
    kernel-headers \
    dkms \
    gcc \
    make

# Configure kernel parameters for bootc systems
echo "Configuring kernel parameters to fix boot issues..."

# Create kernel cmdline with comprehensive boot fixes
mkdir -p /etc/kernel
cat > /etc/kernel/cmdline << 'EOF'
audit=0 quiet loglevel=3 systemd.show_status=0 rd.systemd.show_status=0 plymouth.enable=0 systemd.mask=systemd-remount-fs.service rw
EOF

# Also configure traditional GRUB as fallback
mkdir -p /etc/default
echo 'GRUB_CMDLINE_LINUX_DEFAULT="audit=0 quiet loglevel=3 systemd.show_status=0 rd.systemd.show_status=0 plymouth.enable=0 systemd.mask=systemd-remount-fs.service rw"' >> /etc/default/grub

# Disable problematic services at build time
systemctl mask systemd-remount-fs.service || true
systemctl mask plymouth-start.service || true

# Fix filesystem mount issues that cause systemd-remount-fs.service to fail
echo "Configuring filesystem fixes..."

# Ensure proper fstab configuration for bootc systems
cat >> /etc/fstab << 'EOF'
# LudOS filesystem configuration
tmpfs /tmp tmpfs defaults,noatime,mode=1777 0 0
tmpfs /var/tmp tmpfs defaults,noatime,mode=1777 0 0
EOF

# Create systemd override to prevent remount failures
mkdir -p /etc/systemd/system/systemd-remount-fs.service.d
cat > /etc/systemd/system/systemd-remount-fs.service.d/override.conf << 'EOF'
[Unit]
ConditionPathExists=!/etc/ludos-skip-remount

[Service]
ExecStart=
ExecStart=/bin/true
EOF

# Create skip file to disable remount service
touch /etc/ludos-skip-remount

# Install minimal X11/Wayland support for Gamescope (no desktop environment)
echo "Installing minimal graphics support for headless gaming..."
dnf5 install -y \
    mesa-dri-drivers \
    mesa-vulkan-drivers \
    xorg-x11-server-Xwayland

### NVIDIA Driver Installation Strategy
echo "Setting up NVIDIA driver installation..."

# Note: NVIDIA GRID vGPU drivers must be manually installed
# They are not available in public repositories due to licensing restrictions
# 
# For Tesla P4 and other datacenter GPUs, you have two options:
# 1. GRID vGPU drivers (for virtualized GPU with licensing) - RECOMMENDED
# 2. Tesla datacenter drivers (for bare metal, no GRID licensing)
#
# This script prepares the system but requires manual driver installation
# See /etc/ludos/nvidia-driver-install.sh for installation instructions

# Install driver dependencies
echo "Installing NVIDIA driver dependencies..."
dnf5 install -y \
    kernel-devel-$(uname -r) \
    kernel-headers \
    gcc \
    make \
    dkms \
    acpid \
    libglvnd-glx \
    libglvnd-opengl \
    libglvnd-devel

# Create directory for manual driver installation in writable location
mkdir -p /var/lib/nvidia-drivers
chmod 755 /var/lib/nvidia-drivers
chown root:root /var/lib/nvidia-drivers

### Install gaming and streaming components
echo "Installing gaming components..."

# Enable RPM Fusion for Steam
dnf5 install -y \
    https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
    https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

# Install gaming components
dnf5 install -y \
    gamescope \
    steam \
    pipewire \
    pipewire-alsa \
    pipewire-pulseaudio \
    wireplumber

# Install Sunshine streaming server at build time (official LizardByte approach)
echo "Installing Sunshine streaming server..."

# Install COPR support for dnf5
dnf5 install -y 'dnf5-command(copr)'

# Enable official LizardByte COPR repository for Sunshine
echo "Enabling official LizardByte COPR repository..."
dnf5 copr enable -y lizardbyte/stable

# Install Sunshine with official package (should resolve dependency issues)
if dnf5 install -y Sunshine; then
    echo "Sunshine installed successfully!"
    
    # Set up Sunshine capabilities for KMS capture
    if [ -f /usr/bin/sunshine ]; then
        setcap cap_sys_admin+ep /usr/bin/sunshine || echo "Warning: Could not set capabilities for Sunshine"
    fi
    
    # Disable sunshine service by default (will be enabled by setup script)
    systemctl disable sunshine.service || true
else
    echo "Warning: Sunshine installation failed, will be handled in post-install setup"
fi

### Create NVIDIA GRID licensing configuration directory
echo "Setting up NVIDIA GRID licensing..."
mkdir -p /etc/nvidia

### Configure kernel parameters for NVIDIA and Gamescope
echo "Configuring kernel parameters..."
echo "nvidia_drm.modeset=1" >> /etc/kernel/cmdline

### Enable required services
echo "Enabling system services..."
systemctl enable podman.socket
systemctl enable nvidia-gridd.service || echo "Warning: nvidia-gridd service not found (will be available after driver installation)"
# Note: sunshine.service will be enabled during ludos-setup.sh after Sunshine installation

### Create LudOS configuration directory and copy setup files
mkdir -p /etc/ludos
cp /ctx/nvidia-gridd.conf.template /etc/ludos/
cp /ctx/ludos-setup.sh /etc/ludos/
cp /ctx/nvidia-driver-install.sh /etc/ludos/
cp /ctx/ludos-sunshine-setup /usr/local/bin/
chmod +x /etc/ludos/ludos-setup.sh
chmod +x /etc/ludos/nvidia-driver-install.sh
chmod +x /usr/local/bin/ludos-sunshine-setup

echo "LudOS build process completed successfully!"
