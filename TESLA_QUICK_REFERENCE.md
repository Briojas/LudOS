# LudOS Tesla Quick Reference

Essential commands for managing NVIDIA Tesla drivers in LudOS.

## Tesla Driver Management

### Installation
```bash
# Download Tesla driver from NVIDIA first, then:
sudo ludos-tesla-setup install ~/NVIDIA-Linux-x86_64-580.82.07.run
sudo systemctl reboot
```

### Status Check
```bash
# Comprehensive driver status
ludos-tesla-setup status

# Quick NVIDIA info
nvidia-smi

# Driver version
nvidia-smi --query-gpu=driver_version --format=csv,noheader
```

### Switch Drivers
```bash
# Remove Tesla, install consumer drivers
sudo ludos-tesla-setup remove
sudo systemctl reboot

# Reinstall Tesla drivers
sudo ludos-tesla-setup install ~/driver.run
```

### Available Versions
```bash
# List Tesla driver versions
ludos-tesla-setup list-versions
```

## System Setup

### Post-Installation
```bash
# Complete LudOS setup
sudo /etc/ludos/ludos-setup.sh

# Check all services
systemctl status ludos-gamescope sunshine nvidia-gridd
```

### GRID Licensing
```bash
# Configure license server
sudo nano /etc/nvidia/gridd.conf

# Restart GRID daemon
sudo systemctl restart nvidia-gridd

# Check license status
nvidia-smi -q | grep "License Status"
```

## Streaming Setup

### Sunshine Configuration
```bash
# Access web interface
https://<ludos-ip>:47990

# Check service
systemctl status sunshine

# View logs
journalctl -u sunshine -f
```

### Gamescope Management
```bash
# Check virtual display
systemctl status ludos-gamescope

# Restart Gamescope
sudo systemctl restart ludos-gamescope

# View configuration
cat /etc/ludos/gamescope/default.conf
```

## Troubleshooting

### Driver Issues
```bash
# Check loaded modules
lsmod | grep nvidia

# Rebuild Tesla drivers
cd /etc/ludos/nvidia-kmod
sudo ./build-tesla-kmod.sh

# Check build logs
ls -la /etc/ludos/nvidia-kmod/build/
```

### Service Problems
```bash
# Restart all services
sudo systemctl restart ludos-gamescope sunshine

# Check service dependencies
systemctl list-dependencies ludos-gamescope

# Reset failed services
sudo systemctl reset-failed
```

### Network/Firewall
```bash
# Open Sunshine ports
sudo firewall-cmd --permanent --add-port=47989-47990/tcp
sudo firewall-cmd --permanent --add-port=48010/tcp
sudo firewall-cmd --reload

# Check listening ports
ss -tulpn | grep -E "(47989|47990|48010)"
```

## Performance Monitoring

### GPU Utilization
```bash
# Real-time GPU stats
watch -n 1 nvidia-smi

# GPU memory usage
nvidia-smi --query-gpu=memory.used,memory.total --format=csv

# Temperature monitoring
nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader
```

### System Resources
```bash
# CPU and memory
htop

# Network bandwidth
iftop

# Disk I/O
iotop
```

### Streaming Performance
```bash
# Encoder statistics
nvidia-smi -q -d ENCODER_STATS

# Network latency (from client)
ping <ludos-ip>

# Bandwidth test
iperf3 -s  # On LudOS
iperf3 -c <ludos-ip>  # On client
```

## File Locations

### Configuration Files
```bash
/etc/nvidia/gridd.conf              # GRID licensing
/etc/ludos/gamescope/default.conf   # Gamescope settings
/etc/ludos/nvidia-driver-status     # Driver status
```

### Service Files
```bash
/etc/systemd/system/ludos-gamescope.service  # Gamescope service
/usr/lib/systemd/system/sunshine.service     # Sunshine service
/usr/lib/systemd/system/nvidia-gridd.service # GRID daemon
```

### Build Tools
```bash
/etc/ludos/nvidia-kmod/             # Tesla kmod build tools
/usr/local/bin/ludos-tesla-setup    # Tesla management script
/usr/local/bin/ludos-sunshine-setup # Sunshine management script
```

### Logs
```bash
journalctl -u sunshine              # Sunshine logs
journalctl -u ludos-gamescope       # Gamescope logs
journalctl -u nvidia-gridd          # GRID daemon logs
dmesg | grep nvidia                 # Kernel driver logs
```

## Common Commands

### Daily Operations
```bash
# Check system health
ludos-tesla-setup status && systemctl status ludos-gamescope sunshine

# Restart streaming stack
sudo systemctl restart ludos-gamescope sunshine

# Monitor performance
watch -n 1 'nvidia-smi && echo "--- Services ---" && systemctl is-active ludos-gamescope sunshine nvidia-gridd'
```

### Maintenance
```bash
# Update system (bootc)
rpm-ostree upgrade && systemctl reboot

# Clean logs
sudo journalctl --vacuum-time=7d

# Check disk space
df -h
```

### Emergency Recovery
```bash
# Switch to consumer drivers if Tesla fails
sudo ludos-tesla-setup remove

# Reset to known good state
sudo systemctl disable ludos-gamescope sunshine
sudo systemctl enable ludos-gamescope sunshine

# Check for conflicts
rpm -qa | grep nvidia
```

---

💡 **Tip**: Bookmark this page for quick access to essential LudOS Tesla commands!
