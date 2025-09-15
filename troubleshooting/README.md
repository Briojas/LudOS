# LudOS Troubleshooting

This directory contains logs, screenshots, and other diagnostic files for troubleshooting LudOS issues.

## Directory Structure

- `logs/` - System logs, boot logs, service logs
- `screenshots/` - Boot screenshots, error screenshots
- `configs/` - Configuration files for debugging
- `dumps/` - Core dumps, memory dumps
- `network/` - Network diagnostic outputs
- `hardware/` - Hardware detection outputs

## Common Files to Collect

### Boot Issues
- `journalctl -b > boot.log`
- `dmesg > dmesg.log`
- `systemctl --failed > failed-services.log`

### Service Issues
- `systemctl status service-name > service-status.log`
- `journalctl -u service-name > service-journal.log`

### NVIDIA Issues
- `nvidia-smi > nvidia-smi.log`
- `lspci | grep -i nvidia > nvidia-hardware.log`
- `modinfo nvidia > nvidia-module.log`

### Network Issues
- `ip addr show > network-interfaces.log`
- `ss -tuln > network-ports.log`

## Usage

Drop any diagnostic files here for analysis. Files in this directory are automatically ignored by git.
