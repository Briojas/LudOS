# LudOS v0.8.2 - Tesla P4 Headless Gaming Architecture Fix

**Release Date**: October 12, 2025

## Critical Discovery: Tesla P4 Lacks Vulkan WSI Extensions

### Problem
Attempted to use OpenBox window manager with Gamescope to solve Steam resolution detection issues, but encountered fundamental hardware limitation.

**Root Cause**: Tesla P4 datacenter drivers **do not support Vulkan Window System Integration (WSI)** extensions required for X11 surfaces:
- Missing: `VK_KHR_surface`, `VK_KHR_xlib_surface`, `VK_KHR_xcb_surface`
- Error: `vkGetPhysicalDeviceSurfacePresentModesKHR failed (VkResult: -13)`

This makes any non-headless Gamescope backend (xvfb, SDL, DRM) incompatible with Tesla P4.

### Solution
Optimized for Tesla P4's capabilities with **headless-only architecture** + Steam resolution workarounds:

1. **Keep `ludos-gamescope-display.service` on headless backend**:
   - Headless is the ONLY backend compatible with Tesla P4 (no Vulkan WSI needed)
   - Gamescope creates rootless Xwayland displays :0 and :1
   - Built-in window management (no external WM needed)

2. **Updated `steam-bigpicture.service`** - Resolution detection workarounds:
   - Added SDL environment variables to force resolution in rootless Xwayland:
     - `SDL_VIDEO_X11_MODE_WIDTH=1920`
     - `SDL_VIDEO_X11_MODE_HEIGHT=1080`
     - `SDL_VIDEO_FULLSCREEN_DISPLAY=0`
   - Removed OpenBox dependency (incompatible with headless mode)
   - Reduced startup delay from 10s to 5s

3. **Removed OpenBox requirement**:
   - OpenBox cannot work with headless Gamescope (rootless conflict)
   - OpenBox requires Vulkan WSI extensions (Tesla P4 doesn't have them)
   - Gamescope's rootless mode provides window management

4. **Created `ludos-configure-display` helper script**:
   - Diagnostic tool for display configuration
   - Attempts xrandr configuration (informational only in rootless mode)

## Changes

### Modified Files
- `build_files/ludos-gamescope-display.service` - Reverted to headless backend (only compatible backend)
- `build_files/steam-bigpicture.service` - Added SDL resolution environment variables, removed OpenBox dependency
- `build_files/ludos-gamescope-display` - Added GPU preference flag for xvfb backend (documentation)
- `build_files/ludos-configure-display` - New diagnostic helper script
- `docs/openbox-troubleshooting.md` - Added Tesla P4 Vulkan WSI limitation documentation
- `VERSION` - Bumped from 0.8.1 to 0.8.2

## Testing Instructions

### For Existing Deployments (Immediate Fix)
```bash
# Stop all services
sudo systemctl stop ludos-openbox.service sunshine.service ludos-gamescope-display.service

# Ensure headless backend (compatible with Tesla P4)
sudo mkdir -p /etc/systemd/system/ludos-gamescope-display.service.d
cat << 'EOF' | sudo tee /etc/systemd/system/ludos-gamescope-display.service.d/backend.conf
[Service]
Environment=LUDOS_BACKEND=headless
EOF

# Disable OpenBox (incompatible with headless mode)
sudo systemctl disable ludos-openbox.service

# Reload and restart
sudo systemctl daemon-reload
sudo systemctl start ludos-gamescope-display.service
sleep 5
sudo systemctl start sunshine.service

# Verify Gamescope is using GPU
nvidia-smi  # Should show gamescope + sunshine processes
ludos-display status
```

### Testing Steam Resolution Detection

After services are running, test if Steam works with the SDL resolution variables:

```bash
# Check if Steam service file exists
ls ~/.config/systemd/user/steam-bigpicture.service

# If updating existing deployment, you'll need to manually update the service file
# with the SDL resolution environment variables from build_files/steam-bigpicture.service

# Test Steam (if installed)
systemctl --user start steam-bigpicture.service
journalctl --user -u steam-bigpicture.service -f
```

### For New Builds
Rebuild ISO with updated configuration:
```bash
just clean
just build-iso
```

The new ISO will have headless backend and SDL resolution workarounds configured.

## Technical Details

### Tesla P4 Headless Architecture (ONLY Compatible Configuration)
```
Hardware GPU (Tesla P4)
  ↓ (Direct Vulkan, NO WSI extensions)
Gamescope (--backend headless)
  ↓ (Creates :0 and :1 with -rootless Xwayland)
  ↓ (Built-in rootless window management)
Steam Big Picture (with SDL resolution env vars)
  ↓ (UI: software llvmpipe, Games: full GPU)
Sunshine (captures Gamescope output)
  ↓ (NVENC GPU encoding)
Moonlight client
```

### Why Other Backends Fail on Tesla P4

**Xvfb/SDL Backend**:
- ❌ Requires `VK_KHR_surface` + `VK_KHR_xlib_surface` (missing on Tesla P4)
- ❌ Error: `vkGetPhysicalDeviceSurfacePresentModesKHR failed (-13)`
- ❌ Gamescope crashes immediately after start

**DRM Backend**:
- ❌ Requires KMS/DRM surface extensions (missing on Tesla P4)
- ❌ Similar Vulkan WSI failures

**OpenBox/External WM**:
- ❌ Cannot attach to rootless Xwayland (Gamescope already managing windows)
- ❌ Requires non-headless backend (which requires WSI extensions)
- ❌ Error: "A window manager is already running on screen 0"

### Steam Resolution Detection Workaround

Since rootless Xwayland doesn't report proper screen bounds, we use SDL environment variables:

```bash
SDL_VIDEO_X11_MODE_WIDTH=1920
SDL_VIDEO_X11_MODE_HEIGHT=1080
SDL_VIDEO_FULLSCREEN_DISPLAY=0
```

These variables force Steam to use the correct resolution without querying X11 RandR (which fails in rootless mode).

## Verification

After applying the fix, verify all services:

```bash
# Check Gamescope display (headless mode)
systemctl status ludos-gamescope-display.service
ludos-display status

# Verify Xwayland IS in rootless mode (expected for headless)
ps aux | grep Xwayland
# Should show "-rootless" flag (this is correct!)

# Check GPU usage
nvidia-smi
# Should show: gamescope and sunshine using GPU memory

# Check Sunshine streaming
systemctl status sunshine.service

# Check display dimensions
DISPLAY=:0 xdpyinfo | grep dimensions
# Should show: 1920x1080 pixels

# Test Steam (if installed)
systemctl --user status steam-bigpicture.service
journalctl --user -u steam-bigpicture.service | grep -i resolution
```

## Known Issues

1. **Steam Resolution Detection**: The SDL environment variables may not work for all Steam versions. If Steam still fails to detect resolution:
   - Try launching Steam inside Gamescope's session (embedded mode)
   - Alternative: Use `STEAM_FORCE_DESKTOPUI_SCALING` environment variable

2. **OpenBox Installation**: OpenBox is still installed in the image but disabled by default. Can be safely removed in future builds to reduce image size.

## Future Considerations

- **Remove OpenBox from build**: Since it's incompatible with Tesla P4, remove from build.sh
- **Test embedded Steam mode**: Launch Steam directly in Gamescope session: `gamescope -- steam -gamepadui`
- **Alternative GPUs**: Document which NVIDIA GPUs support Vulkan WSI for users who might want OpenBox
- **Consumer GPU mode**: Add build flag for consumer NVIDIA drivers that support full Vulkan WSI

## Related Documentation
- `docs/openbox-troubleshooting.md` - Complete troubleshooting guide
- `docs/tesla-p4-fixes.md` - Tesla P4 specific configurations
- `docs/unsigned-deployment.md` - Deployment procedures
