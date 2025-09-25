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
systemctl mask akmods-keygen@akmods-keygen.service || true

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

### Enable RPM Fusion repositories (required for Steam, NVIDIA drivers, etc.)
echo "Enabling RPM Fusion repositories..."
dnf5 install -y \
    https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
    https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

### Install gaming and streaming components
echo "Installing gaming components..."

# Install Gamescope for virtual display (essential for headless gaming)
echo "Installing Gamescope virtual display manager..."
dnf5 install -y gamescope

# Install Steam and gaming dependencies (requires RPM Fusion)
echo "Installing Steam and gaming dependencies..."
dnf5 install -y \
    steam \
    gamemode

### LudOS NVIDIA Driver Strategy:
# 1. Install minimal OpenGL infrastructure only (no NVIDIA drivers)
# 2. Provide Tesla kmod build tools for post-install use
# 3. Tesla drivers installed via ludos-tesla-setup during deployment
# 4. Focus on datacenter/Tesla GPUs for headless gaming

echo "Installing graphics infrastructure..."

# Install OpenGL libraries only (Tesla drivers will provide NVIDIA components)
echo "Installing OpenGL infrastructure..."
dnf5 install -y \
    libglvnd-glx \
    libglvnd-opengl \
    libglvnd-devel

# Install Tesla kmod build dependencies for post-install use
echo "Installing Tesla kmod build dependencies..."
dnf5 install -y \
    rpm-build \
    kernel-devel \
    kernel-headers \
    gcc \
    make \
    wget2-wget \
    curl \
    xz \
    kmodtool \
    pciutils

# Create LudOS configuration directory early
mkdir -p /etc/ludos

# Create driver status file (no drivers installed yet)
echo "NO_DRIVERS_INSTALLED=true" > /etc/ludos/nvidia-driver-status
echo "DRIVER_TYPE=none" >> /etc/ludos/nvidia-driver-status

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
        /usr/sbin/setcap cap_sys_admin+ep /usr/bin/sunshine || echo "Warning: Could not set capabilities for Sunshine"
    fi
    
    # Disable sunshine service by default (will be enabled by setup script)
    if systemctl list-unit-files sunshine.service >/dev/null 2>&1; then
        systemctl disable sunshine.service || true
    else
        echo "Note: sunshine.service will be configured during post-install setup"
    fi
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

### Copy LudOS setup files (directory already created above)
cp /ctx/nvidia-gridd.conf.template /etc/ludos/
cp /ctx/ludos-setup.sh /etc/ludos/
cp /ctx/nvidia-driver-install.sh /etc/ludos/
cp /ctx/ludos-sunshine-setup /usr/local/bin/
cp /ctx/ludos-tesla-setup /usr/local/bin/

# Copy nvidia-kmod directory if it exists
if [ -d /ctx/nvidia-kmod ]; then
    cp -r /ctx/nvidia-kmod /etc/ludos/nvidia-kmod
else
    echo "Warning: nvidia-kmod directory not found in build context"
    echo "Tesla driver build tools will not be available"
fi
chmod +x /etc/ludos/ludos-setup.sh
chmod +x /etc/ludos/nvidia-driver-install.sh
chmod +x /usr/local/bin/ludos-sunshine-setup
chmod +x /usr/local/bin/ludos-tesla-setup

# Make Tesla build script executable if it exists
if [ -f /etc/ludos/nvidia-kmod/build-tesla-kmod.sh ]; then
    chmod +x /etc/ludos/nvidia-kmod/build-tesla-kmod.sh
fi

echo "LudOS build process completed successfully!"
