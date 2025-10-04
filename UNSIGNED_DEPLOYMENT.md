# LudOS Unsigned Deployment Guide (Secure Boot Disabled)

Quick reference for deploying LudOS with unsigned Tesla drivers when Secure Boot is disabled.

---

## 🚀 TL;DR - Quick Order of Operations

```bash
# 1. DISABLE SECURE BOOT IN BIOS/UEFI (CRITICAL!)

# 2. Build LudOS (includes Steam, Gamescope, Xvfb, Sunshine)
just clean && just build && just build-iso

# 3. Deploy ISO to VM/bare metal
#    Note: VGA adapter needed for initial setup only

# 4. Boot into LudOS, download Tesla driver
curl -fSsl -O https://us.download.nvidia.com/tesla/580.82.07/NVIDIA-Linux-x86_64-580.82.07.run

# 5. Install Tesla drivers WITHOUT --secure-boot flag
sudo ludos-tesla-setup install-tesla ~/NVIDIA-Linux-x86_64-580.82.07.run

# 6. Reboot
sudo systemctl reboot

# 7. Run post-install setup
sudo /etc/ludos/ludos-setup.sh

# 8. Verify everything is working
nvidia-smi                              # Should show Tesla P4
systemctl status ludos-gamescope        # Should show Steam running
systemctl status sunshine               # Should show streaming ready

# 9. Configure Sunshine and connect
# Access https://<vm-ip>:47990 to set credentials
# Connect via Moonlight client - you'll see Steam Big Picture!

# 10. (Optional) Remove VGA adapter from VM config
#     Gamescope creates virtual display, VGA no longer needed
```

**What's included in the build:**
- ✅ Steam (gaming platform)
- ✅ Gamescope (virtual display compositor for Tesla GPU)
- ✅ Xvfb (virtual X server for gamescope to run on)
- ✅ Sunshine (streaming server with KMS capture)

## 🏗️ Architecture Overview

**How LudOS Headless Gaming Works:**

```
┌─────────────────────────────────────────────┐
│ LudOS VM (Headless - No Physical Monitor)   │
│                                             │
│  ┌──────────────────────────────────────┐  │
│  │ Xvfb :99 (Virtual X Server)          │  │
│  │  └─> Gamescope (Virtual Display)     │  │
│  │       └─> Steam Big Picture          │  │
│  │            └─> Game                   │  │
│  │                ↓ Rendered on          │  │
│  │           Tesla P4 via Vulkan/OpenGL  │  │
│  └──────────────────────────────────────┘  │
│              ↓ Captured at DISPLAY=:99      │
│  ┌──────────────────────────────────────┐  │
│  │ Sunshine Streaming Server            │  │
│  │ - Captures gamescope display         │  │
│  │ - Encodes with NVENC (Tesla HW)      │  │
│  │ - Streams over network               │  │
│  └──────────────────────────────────────┘  │
│              ↓ Network (TCP/UDP)            │
└──────────────┼──────────────────────────────┘
               ↓
      ┌────────────────┐
      │ Moonlight      │ ← Your gaming device
      │ Client         │   (PC/Phone/Tablet)
      └────────────────┘
```

**Key Points:**
- **No physical monitor needed** - Gamescope creates virtual display
- **Tesla GPU acceleration** - Games render directly on Tesla P4
- **Hardware encoding** - NVENC on Tesla for efficient streaming
- **VGA adapter optional** - Only needed for initial VM setup
- **Low latency** - Direct GPU access, no VNC overhead

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
nvidia-smi                              # Should show Tesla P4
systemctl status ludos-gamescope        # Should show Steam launching
systemctl status sunshine               # Should show streaming ready

# Check gamescope logs to ensure Steam started
journalctl -u ludos-gamescope.service -n 50

# You should see:
# - Xvfb started on :99
# - Gamescope initialized with Tesla P4
# - Steam Big Picture launching
```

### 9. Configure Sunshine

```bash
# Access Sunshine web interface
https://<vm-ip>:47990

# First-time setup:
# 1. Create username and password
# 2. Click "Configuration" tab
# 3. Verify settings:
#    - Display: :99 (gamescope's display)
#    - Encoder: Should auto-detect NVENC on Tesla
# 4. Click "Apply" and restart Sunshine if needed

# Sunshine should now be ready to accept connections
```

### 10. Connect via Moonlight

```bash
# Install Moonlight on your client device:
# - Windows/Mac/Linux: https://moonlight-stream.org
# - Android/iOS: Download from app store

# In Moonlight:
# 1. Add PC manually with LudOS VM IP address
# 2. Enter the PIN shown in Moonlight into Sunshine web UI
# 3. Once paired, you'll see "Steam Big Picture" as available app
# 4. Click to connect - you should see Steam running on Tesla P4!
```

**What you'll see:**
- Steam Big Picture UI running at 1920x1080@60Hz
- Full Tesla P4 GPU acceleration for games
- Low latency streaming with NVENC hardware encoding
- Games will detect and use the Tesla P4 for rendering

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

### Issue: nvidia-smi fails with "couldn't communicate with driver"

This means device nodes weren't created automatically:

```bash
# Check if device nodes exist
ls -la /dev/nvidia*

# If missing /dev/nvidia0 or /dev/nvidiactl, create them manually:
sudo mknod -m 666 /dev/nvidiactl c 195 255
sudo mknod -m 666 /dev/nvidia0 c 195 0
sudo mknod -m 666 /dev/nvidia-modeset c 195 254

# Or use nvidia-modprobe
sudo nvidia-modprobe -c 0
sudo nvidia-modprobe -u

# Test nvidia-smi
nvidia-smi

# Fix the service for next boot
sudo systemctl restart nvidia-device-setup.service
sudo systemctl status nvidia-device-setup.service
```

**Root cause:** The nvidia-device-setup.service needs to create both primary device nodes (`-c 0`) and UVM nodes (`-u`). This is fixed in the latest version.

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
