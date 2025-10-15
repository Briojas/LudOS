# Tesla P4 Steam Big Picture Fixes

## Problem Summary

Tesla P4 datacenter GPUs have a critical limitation for gaming/streaming workloads: **they lack Vulkan Window System Integration (WSI) extensions** (`VK_KHR_surface`, `VK_KHR_xlib_surface`). These are required for applications like Steam Big Picture that use Chromium Embedded Framework (CEF) with Vulkan rendering.

## Root Causes

1. **Vulkan WSI Missing**: Tesla P4 drivers (580.82.07) don't include X11/XWayland surface extensions
2. **CEF GPU Process Crashes**: Steam's CEF tries to initialize Vulkan → fails → crashes → black screen
3. **Steam Compositor Conflict**: Steam launches `steamcompmgr` which conflicts with OpenBox window manager
4. **XDG_RUNTIME_DIR Not Set**: User services need this for Vulkan ICD loader to work properly

## Solutions Implemented

### 1. **Force Software Rendering** (`steam-bigpicture.service`)
```ini
Environment=LIBGL_ALWAYS_SOFTWARE=1
Environment=GALLIUM_DRIVER=llvmpipe
Environment=MESA_GL_VERSION_OVERRIDE=3.3
Environment=MESA_GLSL_VERSION_OVERRIDE=330
```
Forces Mesa to use CPU-based llvmpipe instead of GPU acceleration for CEF.

### 2. **Completely Disable Vulkan**
```ini
Environment=VK_ICD_FILENAMES=
Environment=VK_LOADER_DISABLE=1
Environment=DISABLE_VULKAN=1
```
Prevents CEF from attempting Vulkan initialization.

### 3. **Disable Steam Compositor**
```ini
Environment=STEAM_DISABLE_COMPOSITING=1
```
Prevents Steam from launching `steamcompmgr` which conflicts with OpenBox.

### 4. **Ensure XDG_RUNTIME_DIR is Set**
```ini
Environment=XDG_RUNTIME_DIR=/run/user/1000
```
Required for Vulkan loader and proper X11 integration.

### 5. **OpenBox Window Manager** (`ludos-openbox.service`)
Already configured with `--replace` flag to forcefully replace any existing window managers.

### 6. **Longer Startup Wait**
```ini
ExecStartPre=/bin/sleep 10
```
Gives OpenBox time to fully initialize before Steam starts.

## Steam Launch Flags

```bash
/usr/bin/steam -gamepadui -fulldesktopres -disable-gpu -noverifyfiles
```

- `-gamepadui`: Big Picture Mode interface
- `-fulldesktopres`: Use full desktop resolution
- `-disable-gpu`: Disable CEF GPU process (forces software rendering)
- `-noverifyfiles`: Skip file verification on startup

## Service Startup Order

1. `ludos-gamescope-display.service` - Creates XWayland displays :0 and :1
2. `ludos-openbox.service` - Window manager on :0 (waits 3s)
3. `steam-bigpicture.service` - Steam UI (waits 10s)
4. `sunshine.service` - Streaming server

## Testing Checklist for New ISO

- [ ] OpenBox starts successfully and stays running
- [ ] `ludos-openbox verify` shows OpenBox as running
- [ ] Steam starts without Vulkan errors in logs
- [ ] `steamcompmgr` does NOT appear in process list
- [ ] Steam window appears in `xwininfo` output
- [ ] Steam uses GPU memory for rendering (check `nvidia-smi`)
- [ ] Moonlight shows Steam Big Picture interface (not black screen)
- [ ] Can navigate Steam with controller/keyboard
- [ ] Can launch a game from Steam

## Known Limitations

- **No GPU-accelerated UI**: Steam Big Picture runs in software rendering mode (llvmpipe)
- **Performance Impact**: UI animations may be less smooth than with GPU acceleration
- **Games Still Use GPU**: Only Steam's UI is software-rendered; games launched from Steam use full GPU

## Verification Commands

```bash
# Check OpenBox is running
sudo systemctl status ludos-openbox.service
ludos-openbox verify

# Check no steamcompmgr
ps aux | grep steamcompmgr

# Check Steam logs for Vulkan errors
tail -100 ~/.local/share/Steam/logs/console-linux.txt | grep -i vulkan

# Check GPU usage
nvidia-smi

# Check window manager
DISPLAY=:0 xprop -root _NET_SUPPORTING_WM_CHECK
```

## Future Improvements

If software rendering is too slow:

1. **Try NVIDIA EGL/GBM Backend**: Newer drivers might support headless Vulkan
2. **Consumer GPU Fallback**: For testing/development, use consumer driver stack
3. **Alternative UI**: Explore non-CEF Steam interfaces (though Big Picture is CEF-based)
4. **GRID vGPU**: If using virtualization, GRID drivers might have better Vulkan WSI support

## References

- Tesla P4 doesn't support Vulkan for display/windowing (compute-only)
- CEF Vulkan initialization: https://bitbucket.org/chromiumembedded/cef/issues/2575
- Mesa llvmpipe: https://docs.mesa3d.org/drivers/llvmpipe.html
