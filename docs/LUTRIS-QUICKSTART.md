# LudOS Lutris Quick Start Guide

**Version:** 0.9.0+  
**Audience:** End users  
**Time to complete:** 10-15 minutes

---

## What is Lutris?

Lutris is your game launcher interface in LudOS. It replaces Steam Big Picture Mode (which doesn't work with Tesla datacenter GPUs) and provides:

- ✅ Unified game library (Steam, GOG, Epic, standalone)
- ✅ Controller-friendly fullscreen interface
- ✅ Game launching and management
- ✅ Works perfectly with Tesla P4 GPUs via streaming

---

## First-Time Setup

### Step 1: Complete LudOS Installation

```bash
# After installing LudOS, run the setup script
sudo /etc/ludos/ludos-setup.sh

# This configures Lutris automatically
# Reboot when prompted
sudo systemctl reboot
```

### Step 2: Connect via Moonlight

1. Open Moonlight on your client device
2. Add your LudOS server IP
3. Pair with the server
4. Connect to "LudOS Desktop"

**You should see:** Lutris fullscreen interface

---

## Using Lutris

### Navigation

**Controller:**
- **Left Stick** - Navigate
- **A/Cross** - Select
- **B/Circle** - Back
- **Start** - Menu

**Keyboard:**
- **Arrow Keys** - Navigate
- **Enter** - Select
- **Escape** - Back
- **F11** - Fullscreen toggle

### Adding Your Steam Library

First time only:

1. In Lutris, navigate to **Sources**
2. Select **Add Steam**
3. Lutris will detect your Steam installation
4. Your Steam games appear in the library

### Launching Games

1. Browse your library
2. Select a game
3. Press **A/Cross** or **Enter**
4. Game launches with full GPU acceleration

---

## Management Commands

### Check Status

```bash
# See if Lutris is running
ludos-lutris status
```

### Restart Lutris

```bash
# If Lutris gets stuck
ludos-lutris restart
```

### View Logs

```bash
# See what Lutris is doing
ludos-lutris logs

# Press Ctrl+C to exit
```

### First-Time Setup

```bash
# Re-run initial configuration
sudo ludos-lutris setup
```

---

## Troubleshooting

### Problem: Lutris UI Not Visible

**Check services:**
```bash
# All should show "active (running)"
systemctl status ludos-gamescope-display
systemctl status ludos-openbox
systemctl status ludos-lutris
```

**Restart display stack:**
```bash
# Restart in order
sudo systemctl restart ludos-gamescope-display
sudo systemctl restart ludos-openbox
sudo systemctl restart ludos-lutris
```

### Problem: Steam Games Not Showing

**Solution 1: Start Steam backend once**
```bash
DISPLAY=:0 steam -silent &
sleep 10
pkill steam
sudo systemctl restart ludos-lutris
```

**Solution 2: Re-configure Steam integration**
```bash
sudo ludos-lutris configure
sudo systemctl restart ludos-lutris
```

### Problem: Controller Not Working

**Check controller detection:**
```bash
# Should list your controller
ls /dev/input/js*

# Test controller
jstest /dev/input/js0

# If not found, reconnect controller
```

### Problem: Lutris Service Won't Start

**Check logs:**
```bash
journalctl -u ludos-lutris.service -n 50
```

**Common causes:**
1. **Gamescope not running** - Check `ludos-display status`
2. **OpenBox not running** - Check `ludos-openbox status`
3. **Display :0 not ready** - Wait 10 seconds after boot

**Fix:**
```bash
# Restart entire display stack
sudo systemctl restart ludos-gamescope-display
sleep 5
sudo systemctl restart ludos-openbox
sleep 3
sudo systemctl restart ludos-lutris
```

---

## Advanced Configuration

### Change Lutris Settings

1. In Lutris, go to **Settings**
2. Adjust preferences
3. Changes auto-save

### Add Other Game Sources

**GOG Games:**
1. Lutris → Sources → Add GOG
2. Sign in with GOG account
3. Games appear in library

**Epic Games:**
1. Lutris → Sources → Add Epic
2. Sign in with Epic account
3. Games appear in library

**Standalone Games:**
1. Lutris → Add Game
2. Browse to game executable
3. Configure launch options

### Enable/Disable Autostart

**Disable Lutris autostart:**
```bash
sudo ludos-lutris disable
```

**Enable Lutris autostart:**
```bash
sudo ludos-lutris enable
```

**Manual start:**
```bash
sudo ludos-lutris start
```

---

## FAQ

### Q: Where did Steam Big Picture go?

**A:** Steam Big Picture Mode doesn't work with Tesla datacenter GPUs due to OpenGL/GLX incompatibility. Lutris is the replacement and works perfectly.

### Q: Can I still play Steam games?

**A:** Yes! Steam backend still runs in the background. Lutris shows your Steam library and launches games through Steam.

### Q: Do games run slower with Lutris?

**A:** No! Lutris is just the launcher UI. Games run exactly the same with full GPU acceleration.

### Q: Can I use keyboard/mouse?

**A:** Yes, but controller is recommended for the couch gaming experience. Keyboard works for navigation.

### Q: How do I update games?

**A:** Games update through their native clients (Steam, etc.) just like before.

### Q: Can I add non-Steam games?

**A:** Yes! Use Lutris → Add Game to add standalone games or games from other stores.

---

## Performance Tips

### Optimize Streaming Quality

In Sunshine web interface (https://your-ludos-ip:47990):

1. Set bitrate to 20-30 Mbps for 1080p
2. Enable hardware encoding (NVENC)
3. Use H.265/HEVC if client supports it

### Reduce Lutris UI Lag

```bash
# Disable animations in Lutris
# Settings → Interface → Disable animations
```

### Optimize Game Performance

Same as before - game performance is unchanged:
- Lutris is just the launcher
- Games run with full GPU acceleration
- NVENC encoding same as with Steam Big Picture

---

## Getting Help

### Check Logs

```bash
# Lutris logs
journalctl -u ludos-lutris.service -n 100

# Display logs
journalctl -u ludos-gamescope-display.service -n 100

# Sunshine logs
journalctl -u sunshine.service -n 100

# OpenBox logs
journalctl -u ludos-openbox.service -n 100
```

### System Status

```bash
# Complete system check
echo "=== GPU ==="
nvidia-smi

echo "=== Display ==="
ludos-display status

echo "=== OpenBox ==="
ludos-openbox status

echo "=== Lutris ==="
ludos-lutris status

echo "=== Sunshine ==="
systemctl status sunshine
```

### Report Issues

Include this information when reporting issues:

1. LudOS version: `cat /etc/ludos/VERSION`
2. GPU model: `nvidia-smi --query-gpu=name --format=csv,noheader`
3. Error logs: Output from troubleshooting commands above
4. Steps to reproduce the issue

---

## Related Documentation

- [Playnite Implementation Guide](impl/playnite-implementation.md) - Technical details
- [Steam Big Picture Issue](steam-big-picture-issue.md) - Why we use Lutris
- [Tesla Deployment Guide](../TESLA_DEPLOYMENT_GUIDE.md) - Full setup guide

---

## Quick Reference

```bash
# Status
ludos-lutris status

# Control
ludos-lutris start
ludos-lutris stop
ludos-lutris restart

# Configuration
ludos-lutris setup
ludos-lutris configure

# Troubleshooting
ludos-lutris logs
journalctl -u ludos-lutris.service -n 50

# Enable/Disable
ludos-lutris enable
ludos-lutris disable
```

---

**Enjoy gaming with LudOS! 🎮**
