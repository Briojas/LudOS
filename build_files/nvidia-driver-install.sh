#!/bin/bash

# NVIDIA Driver Installation Script for LudOS
# This script handles the manual installation of NVIDIA drivers for Tesla P4 and other datacenter GPUs

set -euo pipefail

echo "=== NVIDIA Driver Installation for LudOS ==="
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root (use sudo)"
   exit 1
fi

# Function to detect GPU
detect_gpu() {
    echo "Detecting NVIDIA GPU..."
    lspci | grep -i nvidia || {
        echo "Error: No NVIDIA GPU detected"
        exit 1
    }
    
    GPU_INFO=$(lspci | grep -i nvidia | head -1)
    echo "Found GPU: $GPU_INFO"
    
    if echo "$GPU_INFO" | grep -qi "tesla"; then
        echo "Tesla datacenter GPU detected"
        GPU_TYPE="tesla"
    elif echo "$GPU_INFO" | grep -qi "quadro"; then
        echo "Quadro workstation GPU detected"
        GPU_TYPE="quadro"
    else
        echo "Consumer/Gaming GPU detected"
        GPU_TYPE="consumer"
    fi
}

# Function to install GRID vGPU drivers
install_grid_vgpu_drivers() {
    echo ""
    echo "=== Installing NVIDIA GRID vGPU Drivers ==="
    echo ""
    echo "IMPORTANT: GRID vGPU drivers must be downloaded from NVIDIA Enterprise portal"
    echo "You need a valid NVIDIA Enterprise license to access these drivers"
    echo ""
    echo "Steps to obtain GRID vGPU drivers:"
    echo "1. Log into NVIDIA Enterprise portal: https://nvid.nvidia.com/"
    echo "2. Navigate to Software Downloads > GRID"
    echo "3. Download the Linux KVM package for your GPU generation"
    echo "4. Place the .run file in /opt/nvidia-drivers/"
    echo ""
    
    # Check if GRID driver is present
    GRID_DRIVER=$(find /opt/nvidia-drivers -name "*GRID*Linux*.run" | head -1)
    
    if [[ -z "$GRID_DRIVER" ]]; then
        echo "No GRID driver found in /opt/nvidia-drivers/"
        echo "Please download and place the GRID driver there, then run this script again"
        return 1
    fi
    
    echo "Found GRID driver: $(basename "$GRID_DRIVER")"
    echo "Installing GRID vGPU driver..."
    
    # Make executable and install
    chmod +x "$GRID_DRIVER"
    "$GRID_DRIVER" --silent --dkms --install-libglvnd
    
    echo "GRID vGPU driver installation completed"
    return 0
}

# Function to install Tesla datacenter drivers
install_tesla_drivers() {
    echo ""
    echo "=== Installing Tesla Datacenter Drivers ==="
    echo ""
    echo "IMPORTANT: Tesla drivers must be downloaded from NVIDIA website"
    echo "These drivers do NOT support GRID licensing"
    echo ""
    echo "Steps to obtain Tesla drivers:"
    echo "1. Visit: https://www.nvidia.com/drivers/tesla/"
    echo "2. Select your Tesla GPU model (e.g., Tesla P4)"
    echo "3. Download the Linux 64-bit driver (.rpm or .run file)"
    echo "4. Place the driver file in /var/lib/nvidia-drivers/ or /tmp/"
    echo ""
    
    # Check for RPM package first (preferred for Fedora)
    # Look in multiple locations for driver files
    TESLA_RPM=$(find /var/lib/nvidia-drivers /opt/nvidia-drivers /tmp -name "*nvidia*.rpm" -o -name "*Tesla*.rpm" 2>/dev/null | head -1)
    TESLA_RUN=$(find /var/lib/nvidia-drivers /opt/nvidia-drivers /tmp -name "*Tesla*Linux*.run" -o -name "*NVIDIA-Linux*.run" 2>/dev/null | head -1)
    
    if [[ -n "$TESLA_RPM" ]]; then
        echo "Found Tesla RPM package: $(basename "$TESLA_RPM")"
        echo "Installing Tesla datacenter driver via RPM (recommended for Fedora)..."
        
        # Install RPM package
        dnf install -y "$TESLA_RPM"
        
        echo "Tesla datacenter driver RPM installation completed"
        return 0
        
    elif [[ -n "$TESLA_RUN" ]]; then
        echo "Found Tesla RUN installer: $(basename "$TESLA_RUN")"
        echo "Installing Tesla datacenter driver via RUN installer..."
        
        # Make executable and install
        chmod +x "$TESLA_RUN"
        "$TESLA_RUN" --silent --dkms --install-libglvnd
        
        echo "Tesla datacenter driver RUN installation completed"
        return 0
    else
        echo "No Tesla driver found in /var/lib/nvidia-drivers/, /opt/nvidia-drivers/, or /tmp/"
        echo "Please download and place the Tesla driver (.rpm or .run) in one of these locations, then run this script again"
        echo ""
        echo "Recommended locations (in order of preference):"
        echo "1. /var/lib/nvidia-drivers/ (persistent, writable)"
        echo "2. /tmp/ (temporary, but always writable)"
        echo ""
        echo "For Fedora systems, .rpm packages are recommended:"
        echo "- Better system integration"
        echo "- Automatic dependency handling"
        echo "- Easier updates and removal"
        return 1
    fi
}

# Function to configure driver for virtual display support
configure_virtual_display_support() {
    echo ""
    echo "=== Configuring Virtual Display Support ==="
    
    # For GRID vGPU drivers: Use native virtual display capabilities
    # For Tesla drivers: Enable DRM modeset for potential Gamescope use
    if [[ "$1" == "grid" ]]; then
        echo "GRID vGPU drivers provide native virtual display support"
        echo "Virtual displays will be managed through vGPU profiles (Q-series/B-series)"
        echo "No additional configuration needed - GRID handles virtual displays natively"
    else
        echo "Tesla drivers: Enabling DRM modeset for Gamescope compatibility"
        if ! grep -q "nvidia_drm.modeset=1" /etc/kernel/cmdline; then
            echo "nvidia_drm.modeset=1" >> /etc/kernel/cmdline
            echo "Added nvidia_drm.modeset=1 to kernel cmdline"
        else
            echo "nvidia_drm.modeset=1 already configured"
        fi
        
        # Update initramfs
        dracut -f
        
        echo "Tesla drivers configured for Gamescope virtual display support"
    fi
}

# Function to verify installation
verify_installation() {
    echo ""
    echo "=== Verifying Installation ==="
    
    # Check if nvidia module is loaded
    if lsmod | grep -q nvidia; then
        echo "✓ NVIDIA kernel module loaded"
    else
        echo "✗ NVIDIA kernel module not loaded"
        echo "  Reboot may be required"
    fi
    
    # Check nvidia-smi
    if command -v nvidia-smi >/dev/null 2>&1; then
        echo "✓ nvidia-smi available"
        nvidia-smi || echo "  nvidia-smi failed (reboot may be required)"
    else
        echo "✗ nvidia-smi not found"
    fi
    
    # Check for GRID licensing support
    if [[ -f /usr/bin/nvidia-gridd ]]; then
        echo "✓ GRID licensing daemon available"
    else
        echo "✗ GRID licensing daemon not found (Tesla drivers don't include GRID support)"
    fi
}

# Main installation flow
main() {
    detect_gpu
    
    echo ""
    echo "Driver Installation Options:"
    echo "1. GRID vGPU drivers (supports GRID licensing, virtualization)"
    echo "2. Tesla datacenter drivers (bare metal only, no GRID licensing)"
    echo "3. Exit"
    echo ""
    
    read -p "Choose installation type (1-3): " choice
    
    case $choice in
        1)
            if install_grid_vgpu_drivers; then
                configure_virtual_display_support "grid"
                verify_installation
                echo ""
                echo "GRID vGPU driver installation completed!"
                echo "Next steps:"
                echo "1. Reboot the system"
                echo "2. Configure GRID licensing in /etc/nvidia/gridd.conf"
                echo "3. Start nvidia-gridd service"
                echo "4. Configure vGPU profiles (Q-series/B-series) for virtual displays"
                echo "5. GRID vGPU will provide native virtual display support"
            fi
            ;;
        2)
            if install_tesla_drivers; then
                configure_virtual_display_support "tesla"
                verify_installation
                echo ""
                echo "Tesla datacenter driver installation completed!"
                echo "Note: GRID licensing is NOT available with Tesla drivers"
                echo "Next steps:"
                echo "1. Reboot the system"
                echo "2. Verify nvidia-smi works"
                echo "3. Use Gamescope for virtual display creation (Tesla drivers don't have native virtual displays)"
            fi
            ;;
        3)
            echo "Installation cancelled"
            exit 0
            ;;
        *)
            echo "Invalid choice"
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
