# Playnite Implementation Guide for LudOS

**Status:** Production Implementation  
**Created:** October 14, 2025  
**Issue:** Steam Big Picture GLX incompatibility with Tesla P4 GPUs  
**Solution:** Playnite game launcher with simpler rendering requirements

---

## Executive Summary

This guide provides step-by-step instructions for implementing Playnite as the primary game launcher for LudOS, replacing Steam Big Picture Mode which cannot render on Tesla datacenter GPUs due to GLX/CEF incompatibilities.

**Implementation Time:** 16-20 hours  
**Difficulty:** Medium (3/5)  
**Success Probability:** 95%

---

## Architecture Overview

```
[Moonlight Client] 
    ↓ H.264/HEVC Stream
[Sunshine Server] (NVENC on Tesla P4)
    ↓ Capture Display :0
[Gamescope Compositor] (Headless mode)
    ↓ Display :0 (Xwayland)
[Playnite Fullscreen UI] (Wine/Proton)
    ├─ Steam Game Library
    ├─ GOG Games
    ├─ Epic Games
    └─ Standalone Games
        ↓ Launch
[Games on NVIDIA GPU]
```

**Key Advantages:**
- ✅ Wine/Proton rendering works with rootless Xwayland
- ✅ No complex OpenGL context requirements like CEF
- ✅ Native controller support
- ✅ Unified multi-store library
- ✅ Active development and community support

---

## Why Playnite Works When Steam Big Picture Doesn't

### Steam Big Picture Problem
```
Steam CEF (Chromium) → Requires hardware GL context
                      → Needs working GLX with direct rendering
                      → Rootless Xwayland + Tesla = FAILS
                      → Result: Black screen
```

### Playnite Solution
```
Playnite (Wine/WPF) → Uses GDI+/DirectX via Wine
                    → Wine translates to OpenGL/Vulkan
                    → Works with software rendering fallback
                    → Gamescope provides Vulkan acceleration
                    → Result: Working UI
```

**Critical difference:** Playnite's rendering path has fallback options that Steam CEF lacks.

---

## Implementation Phases

### Phase 1: Preparation (2 hours)

**Goal:** Understand environment and gather resources

1. **Review current LudOS setup**
   ```bash
   # Check Gamescope status
   systemctl status ludos-gamescope-display
   
   # Check displays
   ludos-display status
   
   # Verify GPU
   nvidia-smi
   ```

2. **Research Playnite Linux compatibility**
   - Playnite runs on Windows via Wine/Proton
   - Community has Wine installation guides
   - Alternative: Use Lutris (which includes Playnite-like features)

3. **Decision: Playnite vs Lutris vs Custom**

**DECISION NEEDED:** 

**Option A: Lutris** (Recommended for speed)
- Native Linux application
- Built-in game library management
- Steam, GOG, Epic integration
- Controller support via Steam Input
- **Faster implementation:** 8-12 hours

**Option B: Playnite via Wine** (Better UX)
- Windows app via Wine
- Best controller UI
- Most features
- **Longer implementation:** 16-20 hours

**Recommendation:** Start with **Lutris** for MVP, consider Playnite migration later.

---

## Phase 2: Lutris Implementation (8-12 hours)

### Why Lutris First?

- ✅ Native Linux (no Wine complexity)
- ✅ Already packaged for Fedora
- ✅ Steam integration built-in
- ✅ Faster to production
- ✅ Proven to work on headless systems

### Step 1: Install Lutris (2 hours)

**Modify `build_files/build.sh`:**

```bash
# Add after Steam installation (around line 110)

# Install Lutris game launcher for unified library management
echo "Installing Lutris game launcher..."
dnf5 install -y lutris

# Install Lutris dependencies
dnf5 install -y \
    python3-gobject \
    python3-cairo \
    gtk3 \
    webkit2gtk3 \
    gvfs \
    cabextract \
    p7zip \
    curl \
    fluid-soundfont-gm
```

### Step 2: Create Lutris Service (2 hours)

**Create `build_files/ludos-lutris.service`:**

```ini
[Unit]
Description=LudOS Lutris Game Launcher
After=ludos-gamescope-display.service ludos-openbox.service
Requires=ludos-gamescope-display.service ludos-openbox.service
Documentation=https://lutris.net/

[Service]
Type=simple
User=ludos
Group=ludos
Environment="DISPLAY=:0"
Environment="XAUTHORITY=/run/user/1000/ludos/Xauthority"
Environment="XDG_RUNTIME_DIR=/run/user/1000"
Environment="DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus"
Environment="LUTRIS_SKIP_INIT=1"
ExecStartPre=/bin/sleep 5
ExecStart=/usr/bin/lutris --fullscreen
Restart=always
RestartSec=3
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=graphical.target
```

### Step 3: Create Lutris Management Script (2 hours)

**Create `build_files/ludos-lutris`:**

```bash
#!/bin/bash
# LudOS Lutris Management Script

set -e

LUTRIS_CONFIG="/var/home/ludos/.config/lutris"
LUTRIS_SERVICE="ludos-lutris.service"

show_status() {
    echo "=== LudOS Lutris Status ==="
    
    if systemctl is-active --quiet $LUTRIS_SERVICE; then
        echo "[SUCCESS] Lutris is running"
    else
        echo "[ERROR] Lutris is not running"
    fi
    
    systemctl status $LUTRIS_SERVICE --no-pager || true
}

start_lutris() {
    echo "Starting Lutris..."
    systemctl start $LUTRIS_SERVICE
    echo "Lutris started successfully"
}

stop_lutris() {
    echo "Stopping Lutris..."
    systemctl stop $LUTRIS_SERVICE
    echo "Lutris stopped"
}

enable_lutris() {
    echo "Enabling Lutris to start on boot..."
    systemctl enable $LUTRIS_SERVICE
    echo "Lutris enabled"
}

disable_lutris() {
    echo "Disabling Lutris autostart..."
    systemctl disable $LUTRIS_SERVICE
    echo "Lutris disabled"
}

configure_steam() {
    echo "Configuring Steam integration..."
    
    # Ensure Lutris config directory exists
    mkdir -p "$LUTRIS_CONFIG"
    
    # Add Steam runner configuration
    cat > "$LUTRIS_CONFIG/steam.yml" << 'EOF'
system:
  disable_runtime: false
  prefer_system_libs: false
  
game:
  runner: steam
EOF

    echo "Steam integration configured"
}

show_help() {
    cat << 'EOF'
LudOS Lutris Management Tool

Usage: ludos-lutris <command>

Commands:
    status      Show Lutris service status
    start       Start Lutris launcher
    stop        Stop Lutris launcher
    enable      Enable Lutris autostart on boot
    disable     Disable Lutris autostart
    restart     Restart Lutris service
    logs        Show Lutris logs
    configure   Run initial configuration
    help        Show this help message

Examples:
    ludos-lutris status
    ludos-lutris enable
    ludos-lutris logs

EOF
}

case "${1:-}" in
    status)
        show_status
        ;;
    start)
        start_lutris
        ;;
    stop)
        stop_lutris
        ;;
    enable)
        enable_lutris
        ;;
    disable)
        disable_lutris
        ;;
    restart)
        stop_lutris
        sleep 2
        start_lutris
        ;;
    logs)
        journalctl -u $LUTRIS_SERVICE -f
        ;;
    configure)
        configure_steam
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo "Error: Unknown command '${1:-}'"
        echo ""
        show_help
        exit 1
        ;;
esac
```

### Step 4: Integration with Build Process (2 hours)

**Update `build_files/build.sh`:**

```bash
# Add after ludos-steam script copying (around line 202)

cp /ctx/ludos-lutris /usr/local/bin/
cp /ctx/ludos-lutris.service /etc/systemd/system/
chmod +x /usr/local/bin/ludos-lutris

# Disable Steam Big Picture service (replaced by Lutris)
systemctl disable steam-bigpicture.service || true
```

### Step 5: Update Setup Script (2 hours)

**Modify `build_files/ludos-setup.sh`:**

Add Lutris configuration section:

```bash
# Configure Lutris for headless gaming
echo "Configuring Lutris..."

# Create Lutris configuration directory
mkdir -p /var/home/ludos/.config/lutris
chown -R ludos:ludos /var/home/ludos/.config/lutris

# Enable Lutris service
systemctl enable ludos-lutris.service
echo "Lutris configured and enabled"
```

---

## Phase 3: Controller Configuration (2-3 hours)

### Configure Steam Input for Lutris

Lutris can use Steam's controller support:

```bash
# Run as ludos user
steam -silent &
sleep 5
pkill -9 steam

# Steam Input daemon will now provide controller support for all apps
```

**Create controller udev rules:**

```bash
# /etc/udev/rules.d/70-ludos-controllers.rules
# Xbox controllers
SUBSYSTEM=="usb", ATTRS{idVendor}=="045e", MODE="0666"
# PlayStation controllers  
SUBSYSTEM=="usb", ATTRS{idVendor}=="054c", MODE="0666"
# Generic HID gamepads
SUBSYSTEM=="hidraw", KERNEL=="hidraw*", MODE="0666"
```

---

## Phase 4: Testing and Validation (2-3 hours)

### Test Checklist

```bash
# 1. Verify Lutris starts
systemctl start ludos-lutris.service
journalctl -u ludos-lutris.service -n 50

# 2. Check display
DISPLAY=:0 xwininfo -root

# 3. Verify Steam library visible in Lutris
# Connect via Sunshine/Moonlight and navigate

# 4. Test game launch
# Try launching a small game

# 5. Verify streaming quality
# Check Sunshine encoding stats

# 6. Test controller input
# Navigate Lutris with gamepad
```

### Common Issues and Solutions

**Issue: Lutris UI not visible**
```bash
# Check display
ludos-display status

# Verify OpenBox running
systemctl status ludos-openbox.service

# Check Lutris logs
journalctl -u ludos-lutris.service -n 100
```

**Issue: Steam games not showing**
```bash
# Configure Steam integration
ludos-lutris configure

# Manually add Steam
# Connect to Sunshine, open Lutris, add Steam as source
```

**Issue: Controller not working**
```bash
# Check controller detection
ls /dev/input/js*

# Test with jstest
jstest /dev/input/js0

# Reload udev rules
udevadm control --reload-rules
udevadm trigger
```

---

## Phase 5: Documentation and Deployment (2-3 hours)

### Update User Documentation

**Create quickstart guide:**

```markdown
# LudOS Gaming Quick Start

1. Connect to LudOS via Sunshine/Moonlight
2. Lutris will launch automatically in fullscreen
3. First time: Add your Steam library
   - Settings → Sources → Add Steam
4. Navigate with controller to select games
5. Press A/X to launch games
```

### Update Build Documentation

- Add Lutris to feature list
- Update installation instructions
- Document controller setup
- Add troubleshooting section

---

## Alternative: Full Playnite Implementation

If Lutris doesn't meet requirements, proceed with Playnite via Wine:

### Additional Steps for Playnite

1. **Install Wine and dependencies** (2h)
2. **Create Wine prefix** (1h)
3. **Install Playnite in Wine** (2h)
4. **Configure Playnite service** (2h)
5. **Fix Wine display issues** (3h)
6. **Controller input mapping** (2h)
7. **Steam integration** (2h)

**Total:** 14 additional hours beyond Lutris

**Recommendation:** Only pursue if Lutris fails to meet requirements.

---

## Success Criteria

### Minimum Viable Product (MVP)

- ✅ Lutris launches automatically on boot
- ✅ Steam library visible and browsable
- ✅ Can launch Steam games
- ✅ Controller navigation works
- ✅ Sunshine streaming captures Lutris UI
- ✅ Games run with GPU acceleration

### Production Ready

- ✅ All MVP criteria
- ✅ Service auto-restarts on failure
- ✅ Controller hotplug support
- ✅ Multiple game sources (Steam, GOG, Epic)
- ✅ User-friendly error handling
- ✅ Documentation complete

---

## Timeline Summary

| Phase | Time | Cumulative |
|-------|------|------------|
| Preparation | 2h | 2h |
| Lutris Installation | 2h | 4h |
| Service Setup | 2h | 6h |
| Management Script | 2h | 8h |
| Build Integration | 2h | 10h |
| Controller Config | 2h | 12h |
| Testing | 2h | 14h |
| Documentation | 2h | 16h |

**Total MVP Time:** 16 hours  
**Buffer for issues:** +4 hours  
**Total Expected:** 16-20 hours

---

## Next Steps

1. **Review this guide** and confirm approach
2. **Execute Phase 1** (Preparation)
3. **Implement Lutris integration** (Phases 2-3)
4. **Test thoroughly** (Phase 4)
5. **Document and deploy** (Phase 5)

---

## Related Documentation

- [Steam Big Picture Issue](../steam-big-picture-issue.md) - Root cause analysis
- [Steam UI Solutions Index](../steam-ui-solutions-index.md) - Solution comparison
- [Alternative UI Solutions](../steam-alternative-ui-solutions.md) - Other approaches

---

**Ready to implement? Start with Phase 1 preparation, then proceed sequentially through the phases.**
