# LudOS Build Instructions

## Overview
LudOS is a headless gaming VM image built on Fedora 42 with NVIDIA datacenter GPU support, Gamescope virtual display, and Sunshine streaming server for remote gaming via Moonlight clients.

## Prerequisites

### Required Build Tools
Install these tools on your build system:

#### Linux (Fedora/RHEL/CentOS)
```bash
# Install Podman and build tools
sudo dnf install -y podman buildah just git

# Install bootc-image-builder for disk image creation
sudo dnf install -y bootc-image-builder
```

#### Linux (Ubuntu/Debian)
```bash
# Install Podman and build tools
sudo apt update
sudo apt install -y podman buildah git

# Install just
curl --proto '=https' --tlsv1.2 -sSf https://just.systems/install.sh | bash -s -- --to /usr/local/bin

# Install bootc-image-builder
# Follow instructions at: https://osbuild.org/docs/bootc/
```

#### macOS
```bash
# Install Homebrew if not already installed
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install required tools
brew install podman just git
```

#### Windows
```powershell
# Install using winget
winget install RedHat.Podman
winget install casey.just
winget install Git.Git

# Or use WSL2 with Linux instructions above
```

### System Requirements
- **RAM**: Minimum 8GB, recommended 16GB+ for building
- **Storage**: At least 50GB free space for build artifacts
- **Network**: Internet connection for downloading packages
- **Privileges**: Root/sudo access for container operations

## Building the Container Image

### 1. Clone and Setup
```bash
git clone <your-ludos-repo-url>
cd LudOS

# Verify just configuration
just --list
```

### 2. Build Container Image
```bash
# Build the LudOS container image
just build

# Or build with specific tag
just build ludos latest
```

### 3. Test the Build
```bash
# Check if image was created successfully
podman images | grep ludos

# Inspect the image
podman inspect localhost/ludos:latest
```

## Creating Bootable Images

### 1. Build QCOW2 VM Image
```bash
# Build QCOW2 image for virtual machines
just build-qcow2

# Output will be in: output/qcow2/disk.qcow2
```

### 2. Build ISO Image
```bash
# Build ISO for bare metal installation
just build-iso

# Output will be in: output/bootiso/install.iso
```

### 3. Build RAW Image
```bash
# Build raw disk image
just build-raw

# Output will be in: output/raw/disk.raw
```

## Deployment Options

### Option 1: Virtual Machine (Recommended for Testing)
```bash
# Run VM with built-in web interface
just run-vm-qcow2

# VM will be accessible at http://localhost:8006
# GPU passthrough required for NVIDIA functionality
```

### Option 2: Bare Metal Installation
1. Flash the ISO to USB drive:
   ```bash
   sudo dd if=output/bootiso/install.iso of=/dev/sdX bs=4M status=progress
   ```
2. Boot from USB and follow installation prompts
3. Ensure NVIDIA GPU is present and supported

### Option 3: Cloud/Hypervisor Deployment
1. Upload QCOW2 image to your hypervisor
2. Create VM with:
   - **CPU**: 4+ cores
   - **RAM**: 8GB+ (16GB recommended)
   - **GPU**: NVIDIA Tesla P4 or compatible datacenter GPU
   - **Network**: Bridge mode for external access

## Post-Installation Configuration

### 1. Initial Setup
After first boot, run the setup script:
```bash
sudo /etc/ludos/ludos-setup.sh
```

### 2. NVIDIA GRID Licensing
Edit the GRID configuration:
```bash
sudo nano /etc/nvidia/gridd.conf

# Update these fields:
# ServerAddress=your-license-server.domain.com
# ServerPort=7070
# FeatureType=2  # For RTX Virtual Workstation
```

Restart GRID daemon:
```bash
sudo systemctl restart nvidia-gridd
sudo systemctl status nvidia-gridd
```

### 3. Sunshine Streaming Setup
Access Sunshine web interface:
```
https://your-vm-ip:47990
```

Configure:
- Set username/password
- Configure applications (Steam, Desktop)
- Set video encoding preferences (NVENC recommended)
- Configure audio settings

### 4. Verify Installation
Check all services are running:
```bash
sudo systemctl status ludos-gamescope
sudo systemctl status sunshine
sudo systemctl status nvidia-gridd
```

Check NVIDIA driver:
```bash
nvidia-smi
```

## Connecting Clients

### Moonlight Client Setup
1. Install Moonlight on client device
2. Add PC using LudOS VM IP address
3. Pair with PIN from Sunshine web interface
4. Launch games remotely

### Supported Clients
- **Windows**: Moonlight PC client
- **macOS**: Moonlight macOS client
- **Linux**: Moonlight AppImage
- **Android**: Moonlight Android app
- **iOS**: Moonlight iOS app
- **Steam Deck**: Moonlight via Discover store

## Troubleshooting

### Build Issues
```bash
# Clean build artifacts
just clean

# Check container logs
podman logs <container-id>

# Rebuild from scratch
just clean && just build
```

### Runtime Issues
```bash
# Check NVIDIA driver status
nvidia-smi

# Check service logs
journalctl -u ludos-gamescope
journalctl -u sunshine
journalctl -u nvidia-gridd

# Verify GPU passthrough (VMs)
lspci | grep NVIDIA
```

### Network Issues
```bash
# Check Sunshine is listening
netstat -tlnp | grep 47990

# Check firewall (if enabled)
sudo firewall-cmd --list-all
```

## Advanced Configuration

### Custom GPU Support
For non-Tesla P4 GPUs, edit `build_files/build.sh`:
```bash
# For newer GPUs, use open kernel modules
dnf5 install -y nvidia-open
```

### Performance Tuning
Edit `/etc/ludos/gamescope/default.conf`:
```bash
# Higher resolution
GAMESCOPE_WIDTH=2560
GAMESCOPE_HEIGHT=1440

# Higher refresh rate
GAMESCOPE_REFRESH=120
```

### Multi-GPU Setup
Configure multiple GPUs in GRID licensing:
```bash
# Edit /etc/nvidia/gridd.conf
# Add multiple FeatureType entries for different GPUs
```

## Support and Documentation

- **NVIDIA GRID Documentation**: https://docs.nvidia.com/vgpu/
- **Gamescope GitHub**: https://github.com/ValveSoftware/gamescope
- **Sunshine Documentation**: https://docs.lizardbyte.dev/projects/sunshine/
- **Bootc Documentation**: https://bootc.dev/

## Security Considerations

- Change default passwords in Sunshine
- Configure firewall rules for streaming ports
- Use VPN for remote access over internet
- Keep NVIDIA drivers updated for security patches
- Monitor system logs for unauthorized access attempts
