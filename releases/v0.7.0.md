# LudOS v0.7.0 Release Notes

## Major Changes: Hardware-Accelerated Display with NVIDIA GPU

This release migrates from software-based Xvfb rendering to **Gamescope headless mode** with full NVIDIA GPU acceleration.

### What Changed

#### 🎮 Gamescope Headless Mode (Default)

**Before (v0.6.x):**
- Used Xvfb (virtual framebuffer) + nested Gamescope
- **Software rendering only** (llvmpipe/mesa)
- Steam would never detect NVIDIA GPU
- No GPU acceleration for games
- No NVENC hardware encoding

**After (v0.7.0):**
- Uses Gamescope in headless mode directly
- **Full NVIDIA Tesla GPU acceleration**
- Steam detects and uses NVIDIA GPU
- Hardware-accelerated game rendering
- NVENC hardware encoding available for Sunshine

### Technical Details

#### Service Configuration Updates

**ludos-gamescope-display.service:**
- Default backend: `xvfb` → `headless`
- Added DRI device permissions:
  - `/dev/dri/card0`, `/dev/dri/card1`
  - `/dev/dri/renderD128`, `/dev/dri/renderD129`
- Full NVIDIA environment variables configured

**Sunshine service:**
- Added DRI device permissions for NVENC access
- Updated to capture from GPU-accelerated display

#### Architecture

```
Moonlight Client
    ↓ H.265/NVENC stream
Sunshine (NVENC encoding)
    ↓ X11 capture
Gamescope Headless (Wayland + Xwayland)
    ↓ Direct rendering
NVIDIA Tesla P4 GPU
```

### Backend Options

Users can still choose different backends based on needs:

1. **headless** (default) - NVIDIA GPU acceleration, best for Tesla GPUs
2. **drm** - Direct DRM/KMS, alternative GPU mode
3. **xvfb** - Software fallback for troubleshooting

Switch backends with:
```bash
sudo ludos-display set-backend <headless|drm|xvfb>
sudo ludos-display restart
```

### Expected Performance Improvements

- ✅ GPU-accelerated game rendering
- ✅ NVENC hardware encoding (lower CPU usage)
- ✅ Better frame pacing and latency
- ✅ Steam games detect NVIDIA GPU properly
- ✅ Support for GPU-specific features (DLSS, ray tracing, etc.)

### Verification After Install

```bash
# Check GPU is being used
nvidia-smi
# Should show active processes

# Test display
ludos-display status
ludos-display test

# Check logs
journalctl -u ludos-gamescope-display.service -n 50

# Should see:
# - Gamescope initialized with NVIDIA GPU
# - Virtual display :99 created
# - GPU rendering active
```

### Breaking Changes

None - existing installations can migrate by:

1. Update to v0.7.0
2. Optionally change backend: `sudo ludos-display set-backend headless`
3. Restart service: `sudo ludos-display restart`

### Files Modified

- `build_files/ludos-gamescope-display.service` - Default backend + GPU permissions
- `build_files/ludos-setup.sh` - Sunshine GPU permissions + updated docs
- `build_files/ludos-display` - Updated help text
- `UNSIGNED_DEPLOYMENT.md` - Fixed service names and verification steps
- `GAMESCOPE_DISPLAY_GUIDE.md` - Complete rewrite for headless-first approach
- `VERSION` - Bumped to 0.7.0

### Known Issues

- DRI permissions may require user to be in `video` and `render` groups (already handled by setup script)
- First boot after install requires one reboot for all services to start properly

### For Fresh Installations

The new default (headless mode) will be used automatically. No configuration needed - just follow the standard deployment guide.

### Migration Guide (Existing Installations)

If you're running v0.6.x with xvfb backend:

```bash
# Update LudOS files
# ... (copy new files from v0.7.0)

# Switch to headless backend
sudo ludos-display set-backend headless

# Restart display service
sudo systemctl daemon-reload
sudo ludos-display restart

# Verify GPU is active
nvidia-smi
ludos-display test
```

---

**Full Changelog:** https://github.com/Briojas/LudOS/compare/v0.6.4...v0.7.0
