# LudOS Command Reference

Complete reference for all LudOS management commands. These commands provide user-friendly interfaces to manage your headless gaming VM.

## Quick Command List

```bash
# Display & Window Management
ludos-display               # Manage Gamescope virtual display
ludos-openbox              # Manage OpenBox window manager
ludos-gamescope-display    # Low-level Gamescope control

# Gaming & Streaming
ludos-steam                # Manage Steam Big Picture
ludos-sunshine-setup       # Configure Sunshine streaming server

# NVIDIA Drivers
ludos-tesla-setup          # Install/manage Tesla datacenter drivers
ludos-tesla-rebuild-modules # Rebuild Tesla kernel modules
```

---

## Display & Window Management

### ludos-display

High-level display management for Gamescope virtual displays.

**Commands:**
```bash
ludos-display start         # Start Gamescope display
ludos-display stop          # Stop Gamescope display
ludos-display restart       # Restart display
ludos-display status        # Show display status
ludos-display logs          # View display logs
```

**Configuration:**
- Service: `ludos-gamescope-display.service`
- Default display: `:0` and `:1`
- Resolution: 1920x1080@60Hz (configurable)

---

### ludos-openbox

Manage the OpenBox window manager for proper Steam UI rendering.

**Commands:**
```bash
ludos-openbox status        # Show OpenBox status
ludos-openbox start         # Start window manager
ludos-openbox stop          # Stop window manager
ludos-openbox restart       # Restart OpenBox
ludos-openbox enable        # Enable auto-start on boot
ludos-openbox disable       # Disable auto-start
ludos-openbox logs          # View OpenBox logs
ludos-openbox reconfigure   # Reload config without restart
ludos-openbox config        # Show config file location
ludos-openbox verify        # Test window manager is working
```

**Why OpenBox?**
- Required for Steam and game windows to display properly
- Manages window positioning, sizing, and focus
- Lightweight (~50MB RAM, <1% CPU)

**Configuration:**
- Service: `ludos-openbox.service`
- Config: `/var/home/ludos/.config/openbox/rc.xml`
- Runs on display: `:0`

**Troubleshooting:**
```bash
# Quick verification
ludos-openbox verify

# If Steam UI not visible
sudo systemctl restart ludos-gamescope-display.service
sleep 5
ludos-openbox restart
ludos-steam restart
```

---

### ludos-gamescope-display

Low-level Gamescope display control script (advanced users).

**Usage:**
```bash
# Environment variables
export LUDOS_DISPLAY_NUM=99    # Display number
export LUDOS_RESOLUTION=1920x1080
export LUDOS_REFRESH=60
export LUDOS_BACKEND=headless  # xvfb, headless, or drm

# Run directly
/usr/local/bin/ludos-gamescope-display
```

**Note:** Most users should use `ludos-display` instead.

---

## Gaming & Streaming

### ludos-steam

Manage Steam Big Picture mode.

**Commands:**
```bash
ludos-steam start           # Start Steam Big Picture
ludos-steam stop            # Stop Steam
ludos-steam restart         # Restart Steam
ludos-steam status          # Show Steam status
ludos-steam enable          # Enable auto-start on boot
ludos-steam disable         # Disable auto-start
ludos-steam logs            # View Steam logs
ludos-steam desktop         # Launch desktop mode (not Big Picture)
```

**Service Stack:**
1. `ludos-gamescope-display.service` - Creates virtual displays
2. `ludos-openbox.service` - Manages windows
3. `steam-bigpicture.service` - Runs Steam

**Configuration:**
- Service: `steam-bigpicture.service`
- Display: `:0`
- Mode: Big Picture (`-gamepadui`)

**Troubleshooting:**
```bash
# If Steam UI not visible
ludos-steam status          # Check status
ludos-openbox verify        # Verify window manager
ludos-steam logs            # Check for errors
```

---

### ludos-sunshine-setup

Configure Sunshine streaming server for Moonlight clients.

**Commands:**
```bash
ludos-sunshine-setup enable     # Enable and start Sunshine
ludos-sunshine-setup disable    # Disable Sunshine
ludos-sunshine-setup install    # Install Sunshine (if missing)
ludos-sunshine-setup portal     # Open Sunshine web portal info
```

**Web Interface:**
- URL: `https://<vm-ip>:47990`
- Default credentials: Set on first login
- Streams display: `:0` (Gamescope)

**Client Connection:**
1. Install Moonlight on client device
2. Moonlight auto-discovers Sunshine
3. Enter PIN from Moonlight into Sunshine web UI
4. Start streaming!

---

## NVIDIA Driver Management

### ludos-tesla-setup

Install and manage NVIDIA Tesla datacenter drivers.

**Commands:**
```bash
# Installation
ludos-tesla-setup install-tesla [--secure-boot] DRIVER.run
ludos-tesla-setup remove-tesla

# Management
ludos-tesla-setup status
ludos-tesla-setup switch-to-consumer
ludos-tesla-setup switch-to-tesla

# Information
ludos-tesla-setup help
ludos-tesla-setup version
```

**Workflow:**

1. **Download Tesla Drivers:**
   ```bash
   # Visit https://www.nvidia.com/Download/index.aspx
   # Select: Tesla / Linux 64-bit / [Version]
   # Download to local machine
   ```

2. **Transfer to LudOS:**
   ```bash
   scp NVIDIA-Linux-x86_64-580.82.07.run ludos@<vm-ip>:~/
   ```

3. **Install Drivers:**
   ```bash
   # With Secure Boot enabled
   sudo ludos-tesla-setup install-tesla --secure-boot ~/NVIDIA-Linux-x86_64-580.82.07.run
   
   # With Secure Boot disabled
   sudo ludos-tesla-setup install-tesla ~/NVIDIA-Linux-x86_64-580.82.07.run
   ```

4. **Reboot:**
   ```bash
   sudo systemctl reboot
   ```

5. **Verify:**
   ```bash
   nvidia-smi
   ludos-tesla-setup status
   ```

**See Also:**
- [Tesla Deployment Guide](deployment-guide.md)
- [Tesla Quick Reference](tesla-quick-reference.md)

---

### ludos-tesla-rebuild-modules

Rebuild Tesla kernel modules after kernel updates.

**Usage:**
```bash
sudo ludos-tesla-rebuild-modules
```

**When to Use:**
- After kernel updates
- If `nvidia-smi` shows "driver/library version mismatch"
- After switching kernels

**What it Does:**
- Rebuilds Tesla kernel modules for current kernel
- Signs modules if Secure Boot enabled
- Loads new modules into kernel

---

## System Setup

### ludos-setup.sh

Initial post-installation setup (run once after deployment).

**Usage:**
```bash
sudo /etc/ludos/ludos-setup.sh
```

**What it Does:**
- Configures system for first use
- Sets up GPU devices
- Configures NVIDIA persistence
- Enables required services

**Note:** This is typically run automatically or manually after first boot.

---

## Common Workflows

### First-Time Setup

```bash
# 1. Run initial setup
sudo /etc/ludos/ludos-setup.sh

# 2. Install Tesla drivers (optional)
sudo ludos-tesla-setup install-tesla ~/NVIDIA-driver.run
sudo systemctl reboot

# 3. Configure Sunshine
ludos-sunshine-setup enable
# Visit https://<vm-ip>:47990

# 4. Start Steam
ludos-steam enable
ludos-steam start

# 5. Connect with Moonlight client
```

### Daily Operations

```bash
# Check system status
ludos-openbox verify
ludos-steam status
systemctl status sunshine.service

# Restart services
ludos-openbox restart
ludos-steam restart

# View logs
ludos-openbox logs
ludos-steam logs
journalctl -u sunshine.service -n 50
```

### Troubleshooting Steam UI Not Visible

```bash
# 1. Verify service startup order
systemctl status ludos-gamescope-display.service
systemctl status ludos-openbox.service
systemctl status steam-bigpicture.service

# 2. Check window manager
ludos-openbox verify

# 3. Restart in correct order
sudo systemctl restart ludos-gamescope-display.service
sleep 5
ludos-openbox restart
sleep 3
ludos-steam restart

# 4. Check Moonlight connection
# Connect and verify Steam UI is visible
```

### After Kernel Updates

```bash
# Rebuild Tesla modules (if using Tesla drivers)
sudo ludos-tesla-rebuild-modules

# Verify drivers loaded
nvidia-smi

# Restart gaming services
ludos-openbox restart
ludos-steam restart
```

---

## Service Dependencies

Understanding the service startup order:

```
1. ludos-gamescope-display.service
   ↓ (creates displays :0 and :1)
   
2. ludos-openbox.service
   ↓ (manages windows on :0)
   
3. steam-bigpicture.service
   ↓ (launches Steam UI)
   
4. sunshine.service
   (captures and streams display :0)
```

**Critical:** OpenBox **must** start before Steam, or windows won't display properly.

---

## Environment Variables

### Gamescope Display

```bash
LUDOS_DISPLAY_NUM=99       # Display number (default: 99)
LUDOS_RESOLUTION=1920x1080 # Screen resolution
LUDOS_REFRESH=60           # Refresh rate in Hz
LUDOS_BACKEND=headless     # Backend: xvfb, headless, or drm
```

### NVIDIA

```bash
__GLX_VENDOR_LIBRARY_NAME=nvidia
__NV_PRIME_RENDER_OFFLOAD=1
__VK_LAYER_NV_optimus=NVIDIA_only
```

---

## Configuration Files

| File | Purpose |
|------|---------|
| `/var/home/ludos/.config/openbox/rc.xml` | OpenBox window manager config |
| `/etc/ludos/nvidia-driver-status` | Current NVIDIA driver status |
| `/etc/kernel/cmdline` | Kernel boot parameters |
| `/etc/nvidia/gridd.conf` | NVIDIA GRID licensing config |
| `/etc/ludos/ludos-setup.sh` | Post-installation setup script |

---

## Getting Help

### Quick Diagnostics

```bash
# System overview
ludos-openbox verify
ludos-tesla-setup status
systemctl status ludos-*

# Collect logs for support
journalctl -u ludos-gamescope-display.service -n 100 > gamescope.log
journalctl -u ludos-openbox.service -n 100 > openbox.log
journalctl -u steam-bigpicture.service -n 100 > steam.log
journalctl -u sunshine.service -n 100 > sunshine.log
```

### Documentation

- **[OpenBox Troubleshooting](openbox-troubleshooting.md)** - Window manager issues
- **[Gamescope Display Guide](gamescope-display-guide.md)** - Virtual display setup
- **[Tesla Quick Reference](tesla-quick-reference.md)** - NVIDIA driver commands
- **[Deployment Guide](deployment-guide.md)** - Full deployment procedure

### Support

- GitHub Issues: Report bugs and request features
- GitHub Discussions: Ask questions and share tips
- Check release notes for known issues

---

## Tips & Best Practices

### Performance

- **Enable OpenBox auto-start**: `ludos-openbox enable`
- **Monitor resource usage**: `htop` or `systemctl status`
- **Check GPU utilization**: `nvidia-smi -l 1`

### Reliability

- **Enable all services**: Auto-start Gamescope, OpenBox, and Steam
- **Use systemd**: Let systemd manage restarts on failure
- **Monitor logs**: Regularly check for errors

### Maintenance

- **Keep drivers updated**: Check for Tesla driver updates monthly
- **Rebuild after kernel updates**: `ludos-tesla-rebuild-modules`
- **Backup configuration**: Save `/var/home/ludos/.config/`

### Security

- **Change Sunshine password**: Use strong password in web UI
- **Configure firewall**: Restrict streaming ports to LAN
- **Update system**: `rpm-ostree upgrade` regularly
- **Use VPN**: For internet-based streaming

---

**Last Updated**: 2025-10-10 (LudOS v0.8.0)
