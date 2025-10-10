# OpenBox Window Manager Troubleshooting

This guide helps troubleshoot window management issues in LudOS's headless gaming setup.

## Background

LudOS uses OpenBox as a lightweight window manager for Gamescope's XWayland displays. Without a window manager, applications like Steam cannot properly display their UI, even though they may be running (audible feedback).

## Verifying OpenBox is Running

### Check OpenBox Service Status

```bash
systemctl status ludos-openbox.service
```

**Expected output**:
- Status: `active (running)`
- No error messages
- Process ID should be shown

### Check OpenBox Process

```bash
ps aux | grep openbox | grep -v grep
```

**Expected output**:
```
ludos    1234  0.1  0.2  123456  23456 ?  Sl   10:00   0:01 /usr/bin/openbox --config-file /var/home/ludos/.config/openbox/rc.xml
```

### Verify Display Connection

```bash
sudo -u ludos env DISPLAY=:0 xdpyinfo | head -20
```

**Expected output**:
- Should show display information
- Screen dimensions should match your resolution (e.g., 1920x1080)
- No connection errors

## Common Issues

### Issue 1: OpenBox Service Failed to Start

**Symptom**: `systemctl status ludos-openbox.service` shows "failed" or "inactive"

**Diagnosis**:
```bash
journalctl -u ludos-openbox.service -n 50
```

**Common causes**:
1. Gamescope display not ready
2. Configuration file missing or invalid
3. Display :0 not available

**Solution**:
```bash
# Restart Gamescope first
sudo systemctl restart ludos-gamescope-display.service
sleep 5

# Then restart OpenBox
sudo systemctl restart ludos-openbox.service

# Verify
systemctl status ludos-openbox.service
```

### Issue 2: Configuration File Missing

**Symptom**: OpenBox fails with "cannot open config file" error

**Diagnosis**:
```bash
ls -la /var/home/ludos/.config/openbox/rc.xml
```

**Solution**:
```bash
# Recreate config directory
sudo mkdir -p /var/home/ludos/.config/openbox

# Copy configuration from system location (if available)
sudo cp /etc/ludos/openbox-rc.xml /var/home/ludos/.config/openbox/rc.xml

# Or from build files if rebuilding
# Copy openbox-rc.xml from build_files/ directory

# Fix permissions
sudo chown -R ludos:ludos /var/home/ludos/.config
sudo chmod 644 /var/home/ludos/.config/openbox/rc.xml

# Restart service
sudo systemctl restart ludos-openbox.service
```

### Issue 3: Steam Still Not Visible

**Symptom**: OpenBox is running but Steam UI still not visible

**Diagnosis**:
```bash
# Check all required services
systemctl status ludos-gamescope-display.service
systemctl status ludos-openbox.service
systemctl status steam-bigpicture.service

# Check window manager is on correct display
sudo -u ludos env DISPLAY=:0 xdpyinfo | grep "name of display"
```

**Solution**:
```bash
# Restart services in correct order
sudo systemctl restart ludos-gamescope-display.service
sleep 5
sudo systemctl restart ludos-openbox.service
sleep 3
sudo systemctl restart steam-bigpicture.service

# Monitor Steam logs
journalctl -u steam-bigpicture.service -f
```

### Issue 4: Window Decorations Visible (Not Fullscreen)

**Symptom**: Steam shows window borders/decorations instead of fullscreen

**Diagnosis**: Check OpenBox configuration

**Solution**:
Edit `/var/home/ludos/.config/openbox/rc.xml` and ensure:
```xml
<application name="steam" class="Steam">
  <decor>no</decor>
  <maximized>yes</maximized>
  <fullscreen>yes</fullscreen>
  <focus>yes</focus>
</application>
```

Then restart:
```bash
sudo systemctl restart ludos-openbox.service
sudo systemctl restart steam-bigpicture.service
```

### Issue 5: Multiple Window Managers Conflict

**Symptom**: Multiple window managers running, causing conflicts

**Diagnosis**:
```bash
ps aux | grep -E "openbox|mutter|kwin|mwm" | grep -v grep
```

**Solution**:
Only OpenBox should be running. If other window managers are present:
```bash
# Kill other window managers (as root)
sudo pkill -9 mutter kwin mwm

# Ensure only OpenBox starts
sudo systemctl disable gdm
sudo systemctl disable sddm
sudo systemctl set-default multi-user.target

# Restart LudOS services
sudo systemctl restart ludos-gamescope-display.service
sudo systemctl restart ludos-openbox.service
sudo systemctl restart steam-bigpicture.service
```

## Manual Testing

### Test OpenBox Manually

```bash
# Stop the service first
sudo systemctl stop ludos-openbox.service

# Run OpenBox manually to see errors
sudo -u ludos env DISPLAY=:0 \
  HOME=/var/home/ludos \
  XDG_RUNTIME_DIR=/run/user/1000 \
  /usr/bin/openbox --config-file /var/home/ludos/.config/openbox/rc.xml
```

Press Ctrl+C to stop, then restart the service:
```bash
sudo systemctl start ludos-openbox.service
```

### Test Steam with OpenBox

```bash
# Ensure OpenBox is running
systemctl status ludos-openbox.service

# Launch Steam manually
sudo -u ludos env DISPLAY=:0 \
  HOME=/var/home/ludos \
  XDG_RUNTIME_DIR=/run/user/1000 \
  __GLX_VENDOR_LIBRARY_NAME=nvidia \
  steam -gamepadui -fulldesktopres
```

Monitor output for errors. Press Ctrl+C to stop.

## Verification Checklist

Before reporting issues, verify:

- [ ] Gamescope display service is active: `systemctl status ludos-gamescope-display.service`
- [ ] OpenBox service is active: `systemctl status ludos-openbox.service`
- [ ] Display :0 is available: `sudo -u ludos env DISPLAY=:0 xdpyinfo`
- [ ] OpenBox config exists: `ls /var/home/ludos/.config/openbox/rc.xml`
- [ ] Config has correct permissions: owned by ludos user
- [ ] No other window managers running: `ps aux | grep -E "mutter|kwin"`
- [ ] Steam service dependencies met: `systemctl list-dependencies steam-bigpicture.service`

## Performance Monitoring

### Check OpenBox Resource Usage

```bash
ps aux | grep openbox | grep -v grep
# Look at %CPU and %MEM columns
```

OpenBox should use:
- CPU: < 1% when idle
- Memory: ~20-50 MB

### Monitor Window Events

```bash
# Watch OpenBox debug output
sudo -u ludos env DISPLAY=:0 \
  HOME=/var/home/ludos \
  openbox --debug --reconfigure
```

## Advanced Configuration

### Custom OpenBox Settings

Edit `/var/home/ludos/.config/openbox/rc.xml` to customize:

- **Focus behavior**: `<focus>` section
- **Window placement**: `<placement>` section
- **Keybindings**: `<keyboard>` section
- **Application rules**: `<applications>` section

After changes:
```bash
# Reconfigure OpenBox (reload config without restart)
sudo -u ludos env DISPLAY=:0 openbox --reconfigure

# Or restart service
sudo systemctl restart ludos-openbox.service
```

### Enable OpenBox Debug Logging

Create systemd override:
```bash
sudo systemctl edit ludos-openbox.service
```

Add:
```ini
[Service]
ExecStart=
ExecStart=/usr/bin/openbox --config-file /var/home/ludos/.config/openbox/rc.xml --debug
```

Save and restart:
```bash
sudo systemctl daemon-reload
sudo systemctl restart ludos-openbox.service
```

View debug logs:
```bash
journalctl -u ludos-openbox.service -f
```

## Getting Help

If issues persist after following this guide:

1. Collect logs:
   ```bash
   journalctl -u ludos-gamescope-display.service -n 100 > gamescope.log
   journalctl -u ludos-openbox.service -n 100 > openbox.log
   journalctl -u steam-bigpicture.service -n 100 > steam.log
   ```

2. Capture configuration:
   ```bash
   cat /var/home/ludos/.config/openbox/rc.xml > openbox-config.xml
   ```

3. Report issue with:
   - All log files
   - OpenBox configuration
   - Output of `systemctl status` for all three services
   - Description of symptoms and steps to reproduce

## Related Documentation

- [Gamescope Display Guide](gamescope-display-guide.md)
- [Deployment Guide](deployment-guide.md)
- [Build Instructions](build-instructions.md)
