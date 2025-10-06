# LudOS Gaming VM Deployment Guide

Complete step-by-step process for building and deploying LudOS gaming VM with Tesla P4 GPU passthrough.

## Prerequisites

- Fedora Workstation 42 build machine with:
  - `podman`, `just`, `git` installed
  - At least 16GB RAM and 50GB free disk space
  - Internet connection for package downloads

- Proxmox VE hypervisor with:
  - Tesla P4 GPU available for passthrough
  - IOMMU enabled in BIOS/UEFI
  - VT-d/AMD-Vi enabled
  - Latest Proxmox VE 8.x installed

## Part 1: Building the LudOS ISO

### Step 1: Prepare Build Environment

```bash
# Navigate to LudOS repository
cd /path/to/LudOS

# Verify build tools
just --version
podman --version

# Clean any previous builds
just clean
```

### Step 2: Build the Container Image

```bash
# Build the base container image
just build localhost/ludos latest

# This will:
# - Use Fedora 42 bootc as base image
# - Install gaming components (Steam, Gamescope)
# - Install Sunshine streaming server
# - Prepare NVIDIA driver installation framework
# - Configure kernel parameters for headless operation
```

### Step 3: Generate Bootable ISO

```bash
# Build ISO image using Bootc Image Builder
just build-iso localhost/ludos latest

# This process will:
# - Create bootable ISO with LudOS container
# - Configure installer with ludos user (password: ludos)
# - Apply boot fixes for stable headless operation
# - Generate versioned ISO file
```

### Step 4: Locate Generated ISO

```bash
# Check build output
ls -la output/bootiso/

# ISO will be named: ludos-v0.0.4-YYYYMMDD.HHMM-GITHASH.iso
# Example: ludos-v0.0.4-20250916.1200-abc1234.iso
```

## Part 2: VM Creation and Tesla P4 Passthrough

### Step 5: Create New VM in Proxmox

1. **Access Proxmox Web Interface:**
   - Navigate to `https://your-proxmox-server:8006`
   - Login with root credentials

2. **Create VM:**
   - Click "Create VM" button
   - **General:** VM ID (e.g., 100), Name: `ludos-gaming`
   - **OS:** Use CD/DVD ISO image, select uploaded LudOS ISO
   - **System:** 
     - Machine: q35
     - BIOS: OVMF (UEFI)
     - Add EFI Disk: Yes
     - SCSI Controller: VirtIO SCSI single
   - **Hard Disk:** 
     - Bus/Device: VirtIO Block
     - Disk size: 100 GB
     - Cache: Write back
   - **CPU:** 
     - Cores: 8
     - Type: host
   - **Memory:** 16384 MB (16 GB)
   - **Network:** VirtIO (paravirtualized), Bridge: vmbr0

### Step 6: Configure Tesla P4 GPU Passthrough in Proxmox

1. **Enable IOMMU on Proxmox host:**
   ```bash
   # SSH into Proxmox host
   ssh root@proxmox-host
   
   # Edit GRUB configuration
   nano /etc/default/grub
   
   # Add to GRUB_CMDLINE_LINUX_DEFAULT:
   # For Intel: intel_iommu=on iommu=pt pcie_acs_override=downstream,multifunction
   # For AMD: amd_iommu=on iommu=pt pcie_acs_override=downstream,multifunction
   
   # Update GRUB and reboot
   update-grub
   reboot
   ```

2. **Configure VFIO modules:**
   ```bash
   # Add VFIO modules to load at boot
   echo 'vfio' >> /etc/modules
   echo 'vfio_iommu_type1' >> /etc/modules
   echo 'vfio_pci' >> /etc/modules
   echo 'vfio_virqfd' >> /etc/modules
   ```

3. **Identify Tesla P4 PCI address:**
   ```bash
   lspci -nn | grep NVIDIA
   # Example output: 01:00.0 VGA compatible controller [0300]: NVIDIA Corporation GP104GL [Tesla P4] [10de:1bb3]
   ```

4. **Blacklist NVIDIA driver on host:**
   ```bash
   echo "blacklist nvidia" >> /etc/modprobe.d/blacklist.conf
   echo "blacklist nouveau" >> /etc/modprobe.d/blacklist.conf
   ```

5. **Bind GPU to VFIO:**
   ```bash
   # Add GPU PCI ID to VFIO
   echo "options vfio-pci ids=10de:1bb3" >> /etc/modprobe.d/vfio.conf
   
   # Update initramfs and reboot
   update-initramfs -u
   reboot
   ```

6. **Add GPU to VM via Proxmox Web UI:**
   - Select your VM → Hardware tab
   - Click "Add" → "PCI Device"
   - Select Tesla P4 from dropdown
   - Check "All Functions" if available
   - Check "Primary GPU" (important for gaming)
   - Check "PCI-Express" for better performance
   - Apply changes

7. **Configure VM for GPU passthrough:**
   ```bash
   # Edit VM configuration file (replace 100 with your VM ID)
   nano /etc/pve/qemu-server/100.conf
   
   # Ensure these settings are present:
   machine: q35
   bios: ovmf
   cpu: host,hidden=1,flags=+pcid
   args: -cpu host,+kvm_pv_unhalt,+kvm_pv_eoi,hv_vendor_id=NV43FIX,kvm=off
   ```

### Step 7: Install LudOS

1. **Boot VM from ISO:**
   - Start VM and boot from LudOS ISO
   - Anaconda installer will start automatically

2. **Installation Process:**
   - Installer uses automated kickstart configuration
   - Creates `ludos` user with sudo privileges (password: `ludos`)
   - Applies kernel parameters for stable headless operation
   - Installation takes 10-15 minutes

3. **First Boot:**
   - Remove ISO and reboot VM
   - System will boot to console login
   - Login as `ludos` user

## Part 3: Post-Installation Configuration

### Step 8: Install NVIDIA Tesla Drivers

LudOS ships with consumer NVIDIA drivers by default, but provides automated Tesla driver installation for datacenter GPUs.

#### Option A: Quick Setup (Consumer Drivers)
```bash
# SSH into VM or use console
ssh ludos@<vm-ip-address>

# Run post-installation setup with consumer drivers
sudo /etc/ludos/ludos-setup.sh
```

#### Option B: Tesla Datacenter Drivers (Recommended for Tesla P4)

1. **Download Tesla Drivers from NVIDIA:**
   - Visit: https://www.nvidia.com/Download/index.aspx
   - Select: **Tesla** / **Linux 64-bit** / [Version]
   - Download: `NVIDIA-Linux-x86_64-VERSION.run`
   - Or, use curl command to download driver: 
   ```bash
   curl -fSsl -O https://us.download.nvidia.com/tesla/<VERSION>/NVIDIA-Linux-x86_64-<VERSION>.run
   ```
   - Replace `<VERSION>` with the version number desired (ex: `580.82.07`)
   - **Important**: You must download directly from NVIDIA (licensing compliance)

2. **Transfer driver to VM:**
   ```bash
   # Via SCP
   scp NVIDIA-Linux-x86_64-580.82.07.run ludos@<vm-ip>:~/
   
   # Or via USB/ISO mount
   sudo mount /dev/sr0 /mnt
   cp /mnt/NVIDIA-Linux-x86_64-580.82.07.run ~/
   ```

3. **Install Tesla drivers using LudOS management tool:**
   
   **For systems WITHOUT Secure Boot:**
   ```bash
   # Install Tesla drivers (replaces consumer drivers)
   sudo ludos-tesla-setup install-tesla ~/NVIDIA-Linux-x86_64-<VERSION>.run
   ```
   
   **For systems WITH Secure Boot (recommended):**
   ```bash
   # Install Tesla drivers with signed kernel modules
   sudo ludos-tesla-setup install-tesla --secure-boot ~/NVIDIA-Linux-x86_64-<VERSION>.run
   ```
   
   The installation will:
   - Build Tesla kmod packages for bootc compatibility
   - Generate and sign kernel modules with MOK (if --secure-boot used)
   - Stage MOK enrollment for firmware (you'll set a one-time password)
   - Remove consumer drivers
   - Install Tesla drivers via rpm-ostree
   - Update driver status tracking
   - Prompt for reboot

4. **MOK Enrollment (Secure Boot only):**
   
   If you used `--secure-boot`, after reboot a **blue MOK Manager screen** will appear:
   
   ```
   1. Select "Enroll MOK"
   2. Select "Continue"
   3. Select "Yes"
   4. Enter the password you set during installation
   5. Select "Reboot"
   ```
   
   **Important:** This is a one-time process. The password is only used for this enrollment.

5. **Reboot to activate Tesla drivers:**
   ```bash
   sudo systemctl reboot
   ```
   
   After the second reboot (post-MOK enrollment), the signed NVIDIA modules will load successfully.

### Step 9: Verify Tesla Driver Installation

```bash
# Check Tesla driver status using LudOS management tool
ludos-tesla-setup status

# This will show:
# - Current driver type (Tesla vs Consumer)
# - Tesla driver version
# - GPU information
# - Loaded kernel modules
# - Installed packages

# Verify NVIDIA SMI output
nvidia-smi

# Should show Tesla P4 information:
# +-----------------------------------------------------------------------------+
# | NVIDIA-SMI 580.xx.xx    Driver Version: 580.xx.xx    CUDA Version: 12.x  |
# |-------------------------------+----------------------+----------------------+
# | GPU  Name        Persistence-M| Bus-Id        Disp.A | Volatile Uncorr. ECC |
# | Fan  Temp  Perf  Pwr:Usage/Cap|         Memory-Usage | GPU-Util  Compute M. |
# |===============================+======================+======================|
# |   0  Tesla P4            Off  | 00000000:01:00.0 Off |                    0 |
# | N/A   xx°C    P8    xx W /  75W|      0MiB /  7680MiB |      0%      Default |
# +-------------------------------+----------------------+----------------------+

# Check Tesla-specific driver features
nvidia-smi --query-gpu=name,driver_version,pci.bus_id --format=csv,noheader
```

### Step 10: Run LudOS Setup Script

```bash
# Run post-installation setup
sudo /etc/ludos/ludos-setup.sh

# This will:
# - Configure Sunshine streaming server
# - Set up Gamescope virtual display service
# - Enable required systemd services
# - Configure audio system for headless operation
```

### Step 11: Configure NVIDIA GRID Licensing (Optional)

For enterprise deployments with GRID licensing:

```bash
# Edit GRID configuration
sudo nano /etc/nvidia/gridd.conf

# Basic GRID configuration:
# ServerAddress=<license-server-ip>
# ServerPort=7070
# FeatureType=1
# EnableUI=TRUE

# Start GRID daemon
sudo systemctl enable nvidia-gridd
sudo systemctl start nvidia-gridd

# Check license status
nvidia-smi -q | grep "License Status"
```

### Step 12: Reboot and Verify

```bash
# Reboot to load NVIDIA drivers
sudo reboot

# After reboot, verify installation
ludos-tesla-setup status  # Comprehensive status check
nvidia-smi  # Should show Tesla P4
systemctl status ludos-gamescope  # Should be active
systemctl status sunshine  # Should be active
systemctl status nvidia-gridd  # Should be active (if GRID configured)
```

## Part 4: Gaming Configuration

### Step 13: Configure Sunshine Streaming

1. **Access Sunshine Web Interface:**
   ```bash
   # From VM or external machine
   https://<vm-ip-address>:47990
   ```

2. **Initial Setup:**
   - Create username/password for Sunshine
   - Configure video settings (1920x1080, 60fps recommended)
   - Enable KMS capture for headless operation
   - Set up audio capture

### Step 14: Configure Virtual Display

**Tesla Drivers with Gamescope Virtual Display:**
```bash
# Gamescope provides virtual display for headless gaming
# Configuration in /etc/ludos/gamescope/default.conf
sudo systemctl start ludos-gamescope

# Verify Gamescope is creating virtual display
sudo systemctl status ludos-gamescope
journalctl -u ludos-gamescope -f
```

### Step 15: Install and Configure Games

```bash
# Steam will start automatically with Gamescope
# Or manually start Steam:
sudo -u ludos steam

# Install games through Steam interface
# Games will run in virtual display environment
```

## Part 5: Client Connection

### Step 16: Connect with Moonlight

1. **Install Moonlight Client:**
   - Windows/Mac: Download from https://moonlight-stream.org/
   - Android/iOS: Install from app stores

2. **Connect to LudOS VM:**
   - Add computer with VM IP address
   - Pair using PIN from Sunshine web interface
   - Start gaming session

## Troubleshooting

### Common Issues:

1. **Tesla Driver Installation Failed:**
   ```bash
   # Check Tesla driver build logs
   sudo cat /etc/ludos/nvidia-kmod/build/BUILDROOT/*/var/log/*
   
   # Verify kernel headers are installed
   rpm -qa | grep kernel-devel
   
   # Rebuild Tesla drivers manually
   cd /etc/ludos/nvidia-kmod
   sudo ./build-tesla-kmod.sh
   
   # Switch back to consumer drivers if needed
   sudo ludos-tesla-setup remove
   ```

2. **Tesla Driver Status Check:**
   ```bash
   # Comprehensive driver status
   ludos-tesla-setup status
   
   # Check which drivers are loaded
   lsmod | grep nvidia
   
   # Verify Tesla driver version
   nvidia-smi --query-gpu=driver_version --format=csv,noheader
   ```

3. **No GPU detected:**
   ```bash
   lspci | grep NVIDIA  # Verify GPU passthrough
   dmesg | grep nvidia  # Check driver loading
   
   # Check if Tesla drivers are properly installed
   ludos-tesla-setup status
   ```

4. **Gamescope virtual display issues:**
   ```bash
   systemctl status ludos-gamescope
   journalctl -u ludos-gamescope
   # Check DRM permissions and nvidia_drm.modeset=1
   
   # Verify Tesla drivers support DRM
   ls -la /dev/dri/
   cat /proc/cmdline | grep nvidia_drm.modeset
   ```

5. **GRID Licensing Issues:**
   ```bash
   # Check GRID daemon status
   systemctl status nvidia-gridd
   
   # Verify license configuration
   cat /etc/nvidia/gridd.conf
   
   # Check license status
   nvidia-smi -q | grep "License Status"
   
   # Restart GRID daemon
   sudo systemctl restart nvidia-gridd
   ```

6. **Sunshine connection issues:**
   ```bash
   systemctl status sunshine
   # Check firewall settings (ports 47989, 47990, 48010)
   # Verify KMS capture capabilities
   ```

### Performance Optimization:

1. **CPU Pinning:**
   - Pin VM vCPUs to dedicated host cores
   - Avoid hyperthreading conflicts

2. **Memory Configuration:**
   - Use hugepages for better performance
   - Allocate sufficient RAM (16GB+ recommended)

3. **Network Optimization:**
   - Use dedicated network interface for streaming
   - Configure QoS for gaming traffic

### Tesla Driver Management Commands:

```bash
# Check current driver status
ludos-tesla-setup status

# List available Tesla driver versions
ludos-tesla-setup list-versions

# Install Tesla drivers
sudo ludos-tesla-setup install ~/NVIDIA-Linux-x86_64-580.82.07.run

# Remove Tesla drivers (revert to consumer)
sudo ludos-tesla-setup remove

# Get help
ludos-tesla-setup help
```

## Support and Updates

- **LudOS Updates:** Use `rpm-ostree upgrade` for system updates
- **Tesla Driver Updates:** Download new version from NVIDIA and run `ludos-tesla-setup install`
- **Consumer Driver Updates:** Use `rpm-ostree upgrade` for automatic updates
- **Configuration Changes:** Modify files in `/etc/ludos/`

### Quick Reference:
- **Tesla Management:** `ludos-tesla-setup` command
- **System Status:** `ludos-tesla-setup status`
- **Service Status:** `systemctl status ludos-gamescope sunshine nvidia-gridd`
- **Logs:** `journalctl -u sunshine -f` or `journalctl -u ludos-gamescope -f`

For issues and support, refer to the LudOS troubleshooting documentation and GitHub issues.
