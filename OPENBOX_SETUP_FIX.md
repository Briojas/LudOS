# OpenBox Setup Automation - v0.8.0

## Problem Identified

During deployment testing, discovered that `/var/home/ludos/.config` was being created by **root** (likely by Sunshine service starting early), causing permission issues when OpenBox service tried to create its configuration directory.

## Root Cause

```bash
drwxr-xr-x. 1 root  root   16 Oct 10 15:43 .config
```

The `.config` directory had `root:root` ownership instead of `ludos:ludos`, preventing the ludos user from creating subdirectories.

## Solution Implemented

### 1. Updated `ludos-setup.sh`

Added automatic OpenBox configuration to the post-installation setup script:

**Lines 176-199**:
- Fix home directory ownership: `chown -R ludos:ludos /var/home/ludos`
- Create OpenBox config directory
- Copy template from `/etc/ludos/openbox-rc.xml`
- Fix all permissions (important for bootc systems)
- Enable OpenBox service

**Lines 236-242**:
- Auto-enable `ludos-openbox.service` during setup

**Lines 270-284**:
- Added helpful output showing service startup order
- Added `ludos-openbox` management command documentation

### 2. Updated `ludos-openbox.service`

**Lines 28-30**:
- Removed automatic config creation (was causing permission errors)
- Added comment explaining manual setup is handled by setup script

### 3. Updated Documentation

**unsigned-deployment.md**:
- Step 9: Changed from manual configuration to verification step
- Noted that setup script handles everything automatically

**v0.8.0.md**:
- Changed "Known Issues" to "Automatic Configuration"
- Documented that setup script now handles OpenBox configuration

## Testing Results

After running `sudo /etc/ludos/ludos-setup.sh`:

```bash
✓ Checking OpenBox service... Running
✓ Checking OpenBox process... Found
✓ Checking display :0... Accessible
✓ Checking configuration... Present
✓ Checking Gamescope display... Running

All checks passed! OpenBox is working correctly.
```

Steam Big Picture also started successfully with proper window management.

## Service Startup Order

The correct startup sequence is now automatically configured:

1. **ludos-gamescope-display.service** - Creates virtual displays :0 and :1
2. **ludos-openbox.service** - Manages windows on display :0
3. **steam-bigpicture.service** - Launches Steam UI
4. **sunshine.service** - Captures and streams display :0

## Files Modified

1. `build_files/ludos-setup.sh` - Added OpenBox configuration automation
2. `build_files/ludos-openbox.service` - Removed problematic auto-config
3. `docs/unsigned-deployment.md` - Updated Step 9 to verification only
4. `releases/v0.8.0.md` - Changed Known Issues to Automatic Configuration

## Deployment Workflow (Updated)

```bash
# 1. Install LudOS from ISO
# 2. Install Tesla drivers
sudo ludos-tesla-setup install NVIDIA-driver.run
sudo systemctl reboot

# 3. Run setup script (now handles OpenBox automatically)
sudo /etc/ludos/ludos-setup.sh

# 4. Reboot
sudo systemctl reboot

# 5. Verify everything is working
ludos-openbox verify
ludos-steam status
```

## Benefits

- ✅ **Automatic**: No manual OpenBox configuration needed
- ✅ **Idempotent**: Setup script can be run multiple times safely
- ✅ **Bootc Compatible**: Handles home directory permission quirks
- ✅ **User Friendly**: Single setup script does everything
- ✅ **Documented**: Clear service startup order

## Future Builds

All future ISO builds will include this fix. Users simply:
1. Deploy ISO
2. Install Tesla drivers
3. Run `sudo /etc/ludos/ludos-setup.sh`
4. Reboot
5. Start gaming!

No manual OpenBox configuration steps required.

---

**Status**: ✅ Resolved and tested  
**Version**: 0.8.0  
**Date**: 2025-10-10
