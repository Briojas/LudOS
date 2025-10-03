# LudOS Unsigned Deployment Guide (Secure Boot Disabled)

Quick reference for deploying LudOS with unsigned Tesla drivers when Secure Boot is disabled.

---

## 🚀 TL;DR - Quick Order of Operations

```bash
# 1. DISABLE SECURE BOOT IN BIOS/UEFI (CRITICAL!)

# 2. Build LudOS
just clean && just build && just build-iso

# 3. Deploy ISO to VM/bare metal

# 4. Boot into LudOS, download Tesla driver
curl -fSsl -O https://us.download.nvidia.com/tesla/580.82.07/NVIDIA-Linux-x86_64-580.82.07.run

# 5. Install Tesla drivers WITHOUT --secure-boot flag
sudo ludos-tesla-setup install-tesla ~/NVIDIA-Linux-x86_64-580.82.07.run

# 6. Reboot
sudo systemctl reboot

# 7. Run setup and verify
sudo /etc/ludos/ludos-setup.sh
ludos-tesla-setup status
nvidia-smi
```

**Key difference from signed branch:** Omit `--secure-boot` flag in step 5. That's it!

---

## ⚠️ Prerequisites

**CRITICAL:** Secure Boot **MUST** be disabled on your system for unsigned drivers to load.

- **VM/Physical Machine:** Disable Secure Boot in BIOS/UEFI settings
- **Proxmox VMs:** Set `bios: seabios` instead of `ovmf` in VM config, OR disable Secure Boot in OVMF settings
- **Physical Hardware:** Enter BIOS/UEFI setup and disable Secure Boot

## Quick Deployment Steps

### 1. Verify Secure Boot is Disabled

```bash
# On the target system after boot, verify:
mokutil --sb-state

# Expected output:
# SecureBoot disabled
```

### 2. Build LudOS Image

```bash
# On build machine
cd /path/to/LudOS
just clean
just build localhost/ludos latest
just build-iso localhost/ludos latest
```

### 3. Deploy VM or Bare Metal

**For Proxmox VMs:**
- Set `bios: seabios` (Legacy BIOS mode) OR
- Set `bios: ovmf` but disable Secure Boot in OVMF settings
- Configure GPU passthrough (Tesla P4, etc.)
- Boot from LudOS ISO and install

**For Bare Metal:**
- Disable Secure Boot in BIOS/UEFI
- Boot from LudOS ISO and install

### 4. Download Tesla Driver

```bash
# On LudOS system after installation
curl -fSsl -O https://us.download.nvidia.com/tesla/580.82.07/NVIDIA-Linux-x86_64-580.82.07.run

# Or download from: https://www.nvidia.com/Download/index.aspx
# Product Type: Tesla
# Operating System: Linux 64-bit
```

### 5. Install Tesla Drivers (Unsigned)

```bash
# Install WITHOUT Secure Boot signing (no --secure-boot flag)
sudo ludos-tesla-setup install-tesla ~/NVIDIA-Linux-x86_64-580.82.07.run

# The script will:
# - Build Tesla kmod packages WITHOUT signing
# - Remove consumer drivers
# - Install Tesla drivers via rpm-ostree
# - Configure kernel parameters
# - Prompt for reboot
```

### 6. Reboot and Verify

```bash
# After reboot
sudo ludos-tesla-setup status

# Verify Tesla driver loaded
nvidia-smi

# Check kernel modules
lsmod | grep nvidia

# Should see:
# - nvidia (Tesla kernel module)
# - nvidia_drm
# - nvidia_modeset
# - nvidia_uvm
```

### 7. Complete Setup

```bash
# Run post-installation setup
sudo /etc/ludos/ludos-setup.sh

# This configures:
# - Sunshine streaming server
# - Gamescope virtual display
# - System services

# Reboot one final time
sudo systemctl reboot
```

### 8. Verify Services

```bash
# Check all services are running
systemctl status ludos-gamescope
systemctl status sunshine
nvidia-smi

# Access Sunshine web interface
https://<vm-ip>:47990
```

## Key Differences from Signed Deployment

| Aspect | Signed (Secure Boot) | Unsigned (No Secure Boot) |
|--------|---------------------|---------------------------|
| Command | `install-tesla --secure-boot driver.run` | `install-tesla driver.run` |
| MOK Enrollment | Required (blue screen) | Not needed |
| Reboots | 2 (install + MOK) | 1 (install only) |
| Kernel Modules | Signed with MOK | Unsigned |
| Secure Boot | Must be enabled | Must be **disabled** |

## Troubleshooting Unsigned Drivers

### Issue: Kernel modules not loading

```bash
# Check if Secure Boot accidentally enabled
mokutil --sb-state

# If enabled, you MUST disable it in BIOS/UEFI
# Unsigned modules cannot load with Secure Boot enabled
```

### Issue: Driver installation failed

```bash
# Check build logs
sudo cat /etc/ludos/nvidia-kmod/build/build.log | tail -50

# Verify kernel headers installed
rpm -qa | grep kernel-devel
rpm -qa | grep kernel-headers

# Try rebuilding
cd /etc/ludos/nvidia-kmod
sudo SIGN_MODULES=0 ./build-tesla-kmod.sh
```

### Issue: "nvidia" module in use errors

```bash
# Check what's using nvidia modules
lsmod | grep nvidia

# If consumer drivers are still loaded, reboot and try again
sudo systemctl reboot

# After reboot, reinstall Tesla drivers
sudo ludos-tesla-setup install-tesla ~/NVIDIA-Linux-x86_64-580.82.07.run
```

### Issue: GPU not detected after Tesla driver install

```bash
# Verify GPU is visible
lspci | grep NVIDIA

# Check kernel logs
dmesg | grep nvidia | tail -20

# Verify nouveau is blacklisted
cat /etc/modprobe.d/blacklist-nouveau.conf

# Check kernel parameters
cat /proc/cmdline | grep nvidia
```

## Manual Build Process (Advanced)

If `ludos-tesla-setup` fails, you can build manually:

```bash
# 1. Place driver in build directory
sudo mkdir -p /etc/ludos/nvidia-kmod/build/SOURCES
sudo cp ~/NVIDIA-Linux-x86_64-580.82.07.run /etc/ludos/nvidia-kmod/build/SOURCES/

# 2. Build without signing
cd /etc/ludos/nvidia-kmod
sudo SIGN_MODULES=0 TESLA_VERSION=580.82.07 ./build-tesla-kmod.sh

# 3. Install built packages
sudo rpm-ostree install \
  /etc/ludos/nvidia-kmod/build/RPMS/x86_64/nvidia-tesla-kmod-common-*.rpm \
  /etc/ludos/nvidia-kmod/build/RPMS/x86_64/kmod-nvidia-tesla-*.rpm \
  /etc/ludos/nvidia-kmod/build/RPMS/x86_64/nvidia-tesla-utils-*.rpm

# 4. Configure kernel parameters
sudo rpm-ostree kargs \
  --append-if-missing=nvidia-drm.modeset=1 \
  --append-if-missing=rd.driver.blacklist=nouveau \
  --append-if-missing=modprobe.blacklist=nouveau

# 5. Reboot
sudo systemctl reboot
```

## Environment Variables

Control build behavior with environment variables:

```bash
# Disable module signing (unsigned drivers)
export SIGN_MODULES=0

# Disable MOK enrollment staging
export ENROLL_MOK=0

# Specify Tesla driver version
export TESLA_VERSION=580.82.07

# Custom build directory
export BUILD_DIR=/tmp/tesla-build

# Then run build script
sudo -E /etc/ludos/nvidia-kmod/build-tesla-kmod.sh
```

## Quick Command Reference

```bash
# Check driver status
ludos-tesla-setup status

# Install unsigned Tesla drivers
sudo ludos-tesla-setup install-tesla <driver.run>

# Remove Tesla drivers (revert to consumer)
sudo ludos-tesla-setup remove

# List available versions
ludos-tesla-setup list-versions

# Verify Secure Boot state
mokutil --sb-state

# Check loaded modules
lsmod | grep nvidia

# View driver logs
journalctl -k | grep nvidia

# Rebuild initramfs (if needed)
sudo rpm-ostree initramfs --enable
```

## When to Use Unsigned vs Signed

**Use Unsigned (This Guide):**
- ✅ Development/testing environments
- ✅ Home labs with Secure Boot disabled
- ✅ Systems where you control BIOS/UEFI
- ✅ Kernel panic issues with signed drivers

**Use Signed (Main Branch):**
- ✅ Production environments requiring Secure Boot
- ✅ Enterprise compliance requirements
- ✅ Systems where Secure Boot cannot be disabled
- ✅ Security-focused deployments

## Additional Resources

- **Main Deployment Guide:** [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) (includes Secure Boot/signed process)
- **Quick Reference:** [TESLA_QUICK_REFERENCE.md](TESLA_QUICK_REFERENCE.md)
- **Build Instructions:** [BUILD_INSTRUCTIONS.md](BUILD_INSTRUCTIONS.md)

## Support

If you encounter issues:

1. Verify Secure Boot is disabled: `mokutil --sb-state`
2. Check build logs: `/etc/ludos/nvidia-kmod/build/build.log`
3. Review kernel logs: `dmesg | grep nvidia`
4. Check driver status: `ludos-tesla-setup status`

For persistent issues, open a GitHub issue with:
- Output of `ludos-tesla-setup status`
- Build log contents
- `dmesg | grep nvidia` output
