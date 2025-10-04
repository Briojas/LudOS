# LudOS Gamescope Display Management Guide

## Overview

LudOS provides a custom display management system built on Gamescope and Xvfb to create a virtual display that Sunshine can capture and stream to Moonlight clients. This system is designed for headless gaming VMs with no physical display attached.

## Architecture

The display system consists of three components:

1. **Xvfb** - Creates a virtual X11 display server (`:99`)
2. **Gamescope** - Nested Wayland compositor providing GPU-accelerated rendering
3. **Sunshine** - Captures the display and streams to Moonlight clients

```
┌─────────────────────────────────────────┐
│  Moonlight Client (Remote)              │
│  ↑                                       │
│  │ H.264/H.265 Stream                   │
└──┼──────────────────────────────────────┘
   │
┌──┴──────────────────────────────────────┐
│  Sunshine (Capture & Encode)            │
│  ↑                                       │
└──┼──────────────────────────────────────┘
   │
┌──┴──────────────────────────────────────┐
│  Gamescope (Compositor)                 │
│  - Wayland compositor                   │
│  - GPU acceleration                     │
│  - Virtual display :99                  │
│  ↑                                       │
└──┼──────────────────────────────────────┘
   │
┌──┴──────────────────────────────────────┐
│  Xvfb (Virtual X Server)                │
│  - Display :99                          │
│  - 1920x1080@60Hz default               │
└─────────────────────────────────────────┘
```

## Management Command

The `ludos-display` command provides easy management of the display service.

### Basic Commands

```bash
# Start the display
sudo ludos-display start

# Check status
ludos-display status

# View logs
ludos-display logs

# Stop the display
sudo ludos-display stop

# Restart the display
sudo ludos-display restart

# Enable auto-start on boot
sudo ludos-display enable

# Disable auto-start
sudo ludos-display disable
```

### Advanced Commands

```bash
# Test display connectivity
ludos-display test

# View current configuration
ludos-display config

# Change display backend
sudo ludos-display set-backend headless
sudo ludos-display set-backend drm
sudo ludos-display set-backend xvfb  # default

# Change resolution
sudo ludos-display set-resolution 2560x1440
sudo ludos-display set-resolution 3840x2160  # 4K
sudo ludos-display set-resolution 1920x1080  # default

# Show help
ludos-display help
```

## Display Backends

LudOS supports three display backends, each with different characteristics:

### 1. **xvfb** (Default - Recommended)

**How it works:**
- Starts Xvfb virtual X server on `:99`
- Launches Gamescope nested inside Xvfb
- Most compatible approach

**Pros:**
- ✅ Most compatible and stable
- ✅ Works with all GPU types
- ✅ Reliable X11 compatibility
- ✅ Easy to debug

**Cons:**
- ❌ Slightly higher CPU overhead
- ❌ Extra layer (X11 + Wayland)

**Use when:**
- Default choice for most setups
- Running legacy X11 games
- Need maximum compatibility
- Troubleshooting other backends

```bash
sudo ludos-display set-backend xvfb
sudo ludos-display restart
```

### 2. **headless** (Experimental)

**How it works:**
- Gamescope runs in headless mode
- No X server required
- Creates virtual display internally

**Pros:**
- ✅ Lower overhead (no Xvfb)
- ✅ Simpler architecture
- ✅ Native Wayland

**Cons:**
- ❌ Experimental Gamescope feature
- ❌ May not work with all games
- ❌ Limited X11 compatibility

**Use when:**
- Want to minimize overhead
- Running native Wayland games
- GPU supports headless rendering
- Testing new Gamescope features

```bash
sudo ludos-display set-backend headless
sudo ludos-display restart
```

### 3. **drm** (Direct Rendering)

**How it works:**
- Gamescope uses DRM/KMS directly
- Bypasses X11 entirely
- Direct GPU access

**Pros:**
- ✅ Best performance potential
- ✅ Lowest latency
- ✅ Direct GPU control

**Cons:**
- ❌ Requires proper DRM permissions
- ❌ May conflict with other display services
- ❌ More complex setup

**Use when:**
- Maximum performance needed
- Direct GPU control required
- Running datacenter GPUs (Tesla)
- Advanced setup only

```bash
sudo ludos-display set-backend drm
sudo ludos-display restart
```

## Configuration

### Environment Variables

The display service can be configured via environment variables in the systemd service:

```bash
# Edit service configuration
sudo systemctl edit ludos-gamescope-display.service
```

Add overrides:

```ini
[Service]
# Change display number
Environment=LUDOS_DISPLAY_NUM=99

# Change resolution
Environment=LUDOS_RESOLUTION=2560x1440

# Change refresh rate
Environment=LUDOS_REFRESH=120

# Change backend
Environment=LUDOS_BACKEND=xvfb
```

Then reload and restart:

```bash
sudo systemctl daemon-reload
sudo systemctl restart ludos-gamescope-display.service
```

### Service File Location

- Service: `/etc/systemd/system/ludos-gamescope-display.service`
- Overrides: `/etc/systemd/system/ludos-gamescope-display.service.d/`
- Script: `/usr/local/bin/ludos-gamescope-display`

## Troubleshooting

### Display Not Starting

**Check service status:**
```bash
ludos-display status
```

**View logs:**
```bash
ludos-display logs
# Or for live logs:
journalctl -u ludos-gamescope-display.service -f
```

**Common issues:**
1. **Xvfb not starting** - Check if port :99 is already in use
2. **Gamescope crashes** - Check GPU drivers are loaded
3. **Permission errors** - Ensure ludos user has GPU access

### Testing Display

**Test if display is available:**
```bash
ludos-display test
```

**Manual display test:**
```bash
# Check if display responds
DISPLAY=:99 xdpyinfo

# Check display information
DISPLAY=:99 xdpyinfo | grep -E "(dimensions|resolution)"

# Test GL rendering
DISPLAY=:99 glxinfo | grep "OpenGL renderer"
```

### Sunshine Can't Find Display

**Verify display environment:**
```bash
# Check Sunshine service configuration
systemctl cat sunshine.service | grep DISPLAY

# Should show: Environment=DISPLAY=:99
```

**Restart both services:**
```bash
sudo systemctl restart ludos-gamescope-display.service
sudo systemctl restart sunshine.service
```

### Performance Issues

**Check backend:**
- Default `xvfb` backend has extra overhead
- Try `headless` or `drm` backends for better performance

**Check GPU acceleration:**
```bash
# Verify NVIDIA GPU is being used
DISPLAY=:99 nvidia-smi

# Check Gamescope GPU usage
ludos-display logs | grep -i "gpu\|vulkan\|nvidia"
```

### Switching Backends

If one backend doesn't work, try another:

```bash
# Try headless mode
sudo ludos-display set-backend headless
sudo ludos-display restart
ludos-display test

# If that fails, try DRM
sudo ludos-display set-backend drm
sudo ludos-display restart
ludos-display test

# Fall back to xvfb
sudo ludos-display set-backend xvfb
sudo ludos-display restart
ludos-display test
```

## Integration with Sunshine

Sunshine automatically uses the display created by this service.

### Sunshine Configuration

The Sunshine service is configured to:
- Wait for `ludos-gamescope-display.service` to start
- Use `DISPLAY=:99` environment
- Start after display is ready

### Streaming Workflow

1. **Display starts** - `ludos-gamescope-display.service` creates virtual display
2. **Sunshine starts** - Waits for display, then begins streaming
3. **Client connects** - Moonlight client connects to Sunshine
4. **Games launch** - Games run in Gamescope display, Sunshine streams to client

## Advanced Usage

### Running Games

To run a game in the virtual display:

```bash
# Set display environment
export DISPLAY=:99

# Launch game
steam steam://rungameid/12345

# Or launch directly
gamescope -w 1920 -h 1080 -- ./your_game
```

### Custom Gamescope Arguments

Edit the wrapper script to add custom Gamescope arguments:

```bash
sudo nano /usr/local/bin/ludos-gamescope-display
```

Add arguments to the `gamescope_args` array in the `start_gamescope()` function.

### Multiple Displays

To run multiple independent displays:

1. Copy service file with different name
2. Change `LUDOS_DISPLAY_NUM` to different value (`:100`, `:101`, etc.)
3. Update dependent services to use new display

## Performance Optimization

### Recommended Settings

**For 1080p 60Hz gaming (balanced):**
```bash
LUDOS_RESOLUTION=1920x1080
LUDOS_REFRESH=60
LUDOS_BACKEND=xvfb
```

**For 1440p 120Hz gaming (high-end):**
```bash
LUDOS_RESOLUTION=2560x1440
LUDOS_REFRESH=120
LUDOS_BACKEND=drm
```

**For 4K 60Hz gaming (maximum quality):**
```bash
LUDOS_RESOLUTION=3840x2160
LUDOS_REFRESH=60
LUDOS_BACKEND=drm
```

### Monitoring Performance

**Check display service performance:**
```bash
# CPU usage
top -p $(pgrep -f ludos-gamescope-display)

# GPU usage
nvidia-smi dmon -s u
```

**Check Gamescope performance:**
```bash
# Gamescope logs show frame times
ludos-display logs | grep -i "fps\|frame"
```

## Migration from Old Setup

If you're upgrading from an older LudOS setup:

### Old Service (ludos-gamescope.service)

The old service ran Gamescope with Steam directly:
```bash
# Disable old service
sudo systemctl disable ludos-gamescope.service
sudo systemctl stop ludos-gamescope.service
```

### New Service (ludos-gamescope-display.service)

The new service provides just the display:
```bash
# Enable new service
sudo ludos-display enable
sudo ludos-display start
```

### Launching Steam

With the new system, launch Steam separately:
```bash
# Via Sunshine web interface
# Or manually:
DISPLAY=:99 steam -gamepadui
```

## Summary

The LudOS display management system provides:

- ✅ **Simple management** via `ludos-display` command
- ✅ **Three backends** for different use cases
- ✅ **Automatic Sunshine integration**
- ✅ **Configurable resolution and refresh rate**
- ✅ **Headless VM optimized**

**Default configuration works for most users** - Xvfb backend with 1080p@60Hz is the most stable and compatible option.

For questions or issues, check the logs with `ludos-display logs` and test the display with `ludos-display test`.
