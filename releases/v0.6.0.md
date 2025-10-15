# LudOS v0.6.0 Release Notes

## Major Feature: Custom Gamescope Display Management System

This release introduces a comprehensive display management system for LudOS, replacing the monolithic gamescope service with a flexible, modular architecture.

### Key Changes

#### New Components

1. **ludos-gamescope-display** - Display wrapper script
   - Manages virtual display lifecycle (Xvfb + Gamescope)
   - Supports three backends: xvfb, headless, drm
   - Automatic cleanup and error handling
   - Comprehensive logging

2. **ludos-gamescope-display.service** - Systemd service
   - Replaces old `ludos-gamescope.service`
   - Runs display independently from applications
   - Proper dependency ordering with Sunshine
   - Configurable via environment variables

3. **ludos-display** - Management command
   - User-friendly interface for display control
   - Commands: start, stop, status, enable, disable, logs, test
   - Configuration management (backend, resolution)
   - Colored output and diagnostics

#### Benefits Over Previous Approach

**Old System (ludos-gamescope.service):**
- ❌ Monolithic service running Gamescope + Steam together
- ❌ Hard to troubleshoot display vs application issues
- ❌ Fixed configuration (headless backend only)
- ❌ Required manual editing of service file to change settings
- ❌ Steam embedded in display service

**New System (ludos-gamescope-display.service):**
- ✅ Separation of concerns (display vs applications)
- ✅ Easy troubleshooting with dedicated logs
- ✅ Three configurable backends (xvfb, headless, drm)
- ✅ Simple configuration via `ludos-display` command
- ✅ Display runs independently, apps connect to it
- ✅ Better stability and restart behavior

### Architecture Comparison

**Previous Architecture:**
```
ludos-gamescope.service
└── gamescope --headless -- steam -gamepadui
    └── Games run inside
```

**New Architecture:**
```
ludos-gamescope-display.service
├── Xvfb :99 (xvfb backend)
└── gamescope (nested or standalone)
    └── Display ready on :99

sunshine.service
└── Captures from :99

Steam/Games
└── Connect to :99 when launched
```

### Migration Guide

If you're upgrading from LudOS v0.5.x:

#### Automatic Migration (Recommended)

Rebuild your LudOS image and deploy fresh:
```bash
git pull
just build
just build-qcow2
# Deploy new image
```

The new setup script will automatically configure the new display system.

#### Manual Migration (Existing VMs)

1. **Stop old services:**
   ```bash
   sudo systemctl stop ludos-gamescope.service sunshine.service
   sudo systemctl disable ludos-gamescope.service
   ```

2. **Copy new files to VM:**
   ```bash
   # From LudOS repo on build machine
   scp build_files/ludos-gamescope-display ludos@<vm-ip>:/tmp/
   scp build_files/ludos-gamescope-display.service ludos@<vm-ip>:/tmp/
   scp build_files/ludos-display ludos@<vm-ip>:/tmp/
   ```

3. **Install on VM:**
   ```bash
   # On LudOS VM
   sudo cp /tmp/ludos-gamescope-display /usr/local/bin/
   sudo cp /tmp/ludos-display /usr/local/bin/
   sudo cp /tmp/ludos-gamescope-display.service /etc/systemd/system/
   sudo chmod +x /usr/local/bin/ludos-gamescope-display
   sudo chmod +x /usr/local/bin/ludos-display
   ```

4. **Update Sunshine service:**
   ```bash
   sudo systemctl edit sunshine.service
   ```
   
   Change:
   ```ini
   [Unit]
   After=ludos-gamescope-display.service
   Wants=ludos-gamescope-display.service
   ```

5. **Enable and start:**
   ```bash
   sudo systemctl daemon-reload
   sudo ludos-display enable
   sudo ludos-display start
   sudo systemctl start sunshine.service
   ```

6. **Verify:**
   ```bash
   ludos-display status
   ludos-display test
   ```

### Usage Examples

#### Basic Operation

```bash
# Start display
sudo ludos-display start

# Check if running
ludos-display status

# View logs
ludos-display logs

# Test display
ludos-display test
```

#### Backend Configuration

```bash
# Use xvfb backend (default, most compatible)
sudo ludos-display set-backend xvfb
sudo ludos-display restart

# Try headless mode (experimental, lower overhead)
sudo ludos-display set-backend headless
sudo ludos-display restart

# Use DRM mode (best performance)
sudo ludos-display set-backend drm
sudo ludos-display restart
```

#### Resolution Changes

```bash
# Set 1440p
sudo ludos-display set-resolution 2560x1440
sudo ludos-display restart

# Set 4K
sudo ludos-display set-resolution 3840x2160
sudo ludos-display restart

# Back to 1080p
sudo ludos-display set-resolution 1920x1080
sudo ludos-display restart
```

### Backend Selection Guide

#### When to Use xvfb (Default)

**Recommended for:**
- ✅ Initial setup and testing
- ✅ Maximum compatibility
- ✅ Legacy X11 games
- ✅ Troubleshooting
- ✅ Most stable option

**Characteristics:**
- Uses Xvfb + Gamescope nested
- Slight CPU overhead from X server
- Works with all GPU types
- Easy to debug

#### When to Use headless

**Recommended for:**
- ⚠️ Testing newer Gamescope features
- ⚠️ Native Wayland games
- ⚠️ Minimizing resource usage

**Characteristics:**
- Experimental Gamescope feature
- No X server overhead
- May not work with all games
- Requires recent Gamescope version

**Note:** This is Option B from our original discussion. If xvfb has issues, try this next.

#### When to Use drm

**Recommended for:**
- ⚡ Maximum performance scenarios
- ⚡ Lowest latency requirements
- ⚡ Direct GPU control
- ⚡ Advanced users only

**Characteristics:**
- Direct DRM/KMS rendering
- Best performance potential
- Requires proper permissions
- May conflict with other services

**Note:** This is Option C from our original discussion. Most advanced option.

### Troubleshooting

#### Display Won't Start

```bash
# Check service logs
ludos-display logs

# Test display manually
sudo systemctl stop ludos-gamescope-display.service
sudo -u ludos /usr/local/bin/ludos-gamescope-display

# Try different backend
sudo ludos-display set-backend xvfb
sudo ludos-display start
```

#### Sunshine Can't Find Display

```bash
# Verify display is running
ludos-display test

# Check Sunshine service
systemctl status sunshine.service

# Restart both services
sudo systemctl restart ludos-gamescope-display.service
sudo systemctl restart sunshine.service
```

#### Performance Issues

```bash
# Try headless backend
sudo ludos-display set-backend headless
sudo ludos-display restart

# Or try DRM backend
sudo ludos-display set-backend drm
sudo ludos-display restart

# Monitor GPU usage
nvidia-smi dmon -s u
```

### Breaking Changes

1. **Service Name Change**
   - Old: `ludos-gamescope.service`
   - New: `ludos-gamescope-display.service`
   - **Action Required:** Update any scripts or documentation referencing old service name

2. **Steam Not Auto-Started**
   - Old behavior: Steam launched automatically with display
   - New behavior: Display runs independently, launch Steam via Sunshine or manually
   - **Action Required:** Launch Steam through Sunshine web interface or add to startup

3. **Service Dependencies**
   - Old: Sunshine had optional dependency on gamescope
   - New: Sunshine requires gamescope-display to be running
   - **Action Required:** Ensure display service is enabled and running

### Documentation

New documentation added:

- **[GAMESCOPE_DISPLAY_GUIDE.md](GAMESCOPE_DISPLAY_GUIDE.md)** - Complete display management guide
  - Architecture explanation
  - Backend comparison and selection
  - Configuration options
  - Troubleshooting procedures
  - Advanced usage examples

Updated documentation:

- **[README.md](README.md)** - Added Display Management section
- **[build_files/ludos-setup.sh](build_files/ludos-setup.sh)** - Updated for new service
- **[build_files/build.sh](build_files/build.sh)** - Added new components

### Technical Details

#### Files Added

- `build_files/ludos-gamescope-display` - Display manager script (217 lines)
- `build_files/ludos-gamescope-display.service` - Systemd service unit
- `build_files/ludos-display` - Management command (476 lines)
- `GAMESCOPE_DISPLAY_GUIDE.md` - Comprehensive documentation

#### Files Modified

- `build_files/build.sh` - Added new components to build
- `build_files/ludos-setup.sh` - Updated service configuration
- `README.md` - Added display management section
- `VERSION` - Bumped to 0.6.0

#### Dependencies Added

- `xorg-x11-utils` - For xdpyinfo and display testing

### Future Improvements

Potential enhancements for future releases:

1. **Auto-backend selection** - Automatically select best backend based on GPU capabilities
2. **Multiple displays** - Support for multiple virtual displays
3. **HDR support** - When Gamescope adds HDR capabilities
4. **Dynamic resolution** - Automatically adjust based on client capabilities
5. **Display presets** - Named configurations for common scenarios

### Acknowledgments

This implementation was created in response to user feedback about difficulty configuring Gamescope displays for Sunshine streaming in headless VMs. The modular approach is inspired by similar display management in other gaming-focused distributions.

### Version Information

- **Version:** 0.6.0
- **Release Date:** 2025-10-04
- **Previous Version:** 0.5.2
- **Breaking Changes:** Yes (service name change)
- **Migration Required:** Recommended

### Getting Help

If you encounter issues with the new display system:

1. Check the logs: `ludos-display logs`
2. Test the display: `ludos-display test`
3. Try different backends: `ludos-display set-backend xvfb`
4. Review the guide: [GAMESCOPE_DISPLAY_GUIDE.md](GAMESCOPE_DISPLAY_GUIDE.md)
5. Open an issue: [GitHub Issues](../../issues)

---

**Upgrade Notes:** Due to the service name change, existing deployments should disable the old `ludos-gamescope.service` before enabling the new `ludos-gamescope-display.service`. Fresh deployments will automatically use the new system.
