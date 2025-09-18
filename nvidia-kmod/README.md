# LudOS Tesla NVIDIA kmod

This directory contains a fork of RPM Fusion's nvidia-kmod package, modified to build Tesla datacenter drivers instead of consumer drivers.

## Overview

This is a hybrid approach (Option 1 + Option 3 from the custom kmod guide) that:
- Uses RPM Fusion's proven kmod toolset and infrastructure
- Modifies the spec file to download and build Tesla drivers
- Integrates directly into the LudOS build process
- Provides fallback to consumer drivers if Tesla build fails

## Files

- `nvidia-tesla-kmod.spec` - Modified spec file for Tesla drivers
- `ludos-tesla-optimizations.patch` - LudOS-specific optimizations for headless gaming
- `build-tesla-kmod.sh` - Build script for Tesla kmod packages
- `nvidia-kmodtool-excludekernel-filterfile` - Kernel exclusion filter (from RPM Fusion)
- `make_modeset_default.patch` - Enable modeset by default (from RPM Fusion)
- `nvidia-kmod-noopen-*` - Open driver detection files (from RPM Fusion)

## How it Works

### Build Process (Licensing Compliant)
1. **During LudOS image build**, consumer kmod-nvidia is installed by default
2. **Tesla tools included**: Tesla kmod build tools are included but not used
3. **Post-install only**: Tesla drivers are built and installed by users post-deployment
4. **User downloads**: Users must download Tesla drivers directly from NVIDIA
5. **Automated build**: `ludos-tesla-setup` tool automates the build and installation process

### Key Modifications from RPM Fusion nvidia-kmod

#### nvidia-tesla-kmod.spec
- **Name**: Changed to `nvidia-tesla-kmod` to avoid conflicts
- **Source**: Downloads Tesla drivers instead of consumer drivers
- **Epoch**: Set to 1 to ensure proper versioning
- **Conflicts**: Prevents installation alongside consumer drivers
- **LudOS patches**: Applies Tesla-specific optimizations

#### Tesla Driver Sources
- **Consumer**: `http://download.nvidia.com/XFree86/Linux-x86_64/`
- **Tesla**: `http://us.download.nvidia.com/tesla/`

#### LudOS Optimizations
The `ludos-tesla-optimizations.patch` adds:
- Headless gaming optimizations
- Virtual display support enhancements
- Tesla-specific DRM features
- Performance tuning for datacenter GPUs

## Usage

### Tesla Driver Installation (Post-Install)

#### Step 1: Download Tesla Driver
1. Visit: https://www.nvidia.com/Download/index.aspx
2. Select: Tesla / Linux 64-bit / [Version]
3. Download: NVIDIA-Linux-x86_64-VERSION.run

#### Step 2: Install Tesla Drivers
```bash
# Install Tesla drivers from downloaded .run file
sudo ludos-tesla-setup install ~/Downloads/NVIDIA-Linux-x86_64-580.82.07.run
```

#### Step 3: Check Status
```bash
# Check driver status
ludos-tesla-setup status
```

### Other Commands
```bash
# Remove Tesla drivers (revert to consumer)
sudo ludos-tesla-setup remove

# List available versions
ludos-tesla-setup list-versions

# Manual build (advanced users)
cd /etc/ludos/nvidia-kmod
sudo ./build-tesla-kmod.sh
```

## Driver Status

Check which drivers are installed:
```bash
# Comprehensive status check
ludos-tesla-setup status

# Quick status file check
cat /etc/ludos/nvidia-driver-status
```

Possible status values:
- `TESLA_DRIVERS_INSTALLED=true` - Tesla datacenter drivers
- `CONSUMER_DRIVERS_INSTALLED=true` - Consumer drivers (default)
- `TESLA_VERSION=580.82.07` - Installed Tesla version

## Advantages

### Licensing Compliance
- ✅ **NVIDIA compliant**: Users download drivers directly from NVIDIA
- ✅ **No redistribution**: LudOS doesn't redistribute proprietary drivers
- ✅ **Legal safety**: Avoids licensing violations
- ✅ **Enterprise ready**: Suitable for commercial deployments

### Technical Benefits
- ✅ **Tesla optimized**: Better performance on datacenter GPUs
- ✅ **Bootc compatible**: Uses rpm-ostree for installation
- ✅ **No signing issues**: Pre-built kmod packages
- ✅ **User-friendly**: Bazzite-style management commands

### vs Manual Installation
- ✅ **Automated process**: One command installation
- ✅ **Package management**: Proper RPM integration
- ✅ **Easy removal**: Simple revert to consumer drivers
- ✅ **Status tracking**: Built-in driver status monitoring

## Troubleshooting

### Build Failures
If Tesla kmod build fails:
1. Ensure you've downloaded the correct Tesla driver .run file
2. Verify kernel-devel packages are installed
3. Check build logs in `/etc/ludos/nvidia-kmod/build/`
4. Try a different Tesla driver version
5. Consumer drivers remain active if Tesla installation fails

### Driver Issues
```bash
# Check driver status
nvidia-smi
lsmod | grep nvidia

# Rebuild if needed
cd /etc/ludos/nvidia-kmod
sudo ./build-tesla-kmod.sh
```

### Version Updates
To update Tesla driver version:
1. Edit `TESLA_VERSION` in `build-tesla-kmod.sh`
2. Update `Version:` in `nvidia-tesla-kmod.spec`
3. Rebuild: `./build-tesla-kmod.sh`

## Integration with LudOS

This Tesla kmod integration is fully integrated with:
- **LudOS build system** (`build.sh`)
- **Driver installation script** (`nvidia-driver-install.sh`)
- **Post-install setup** (`ludos-setup.sh`)
- **Documentation** (NVIDIA_DRIVER_GUIDE.md)

The goal is to provide Tesla-optimized drivers with the same reliability and ease of use as consumer drivers, while maintaining the flexibility for enterprise GRID installations.
