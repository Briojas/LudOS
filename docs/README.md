# LudOS Documentation

Quick navigation for LudOS headless gaming documentation.

---

## 📚 Getting Started

**New users start here:**

1. **[Build Instructions](guides/build-instructions.md)** - How to build LudOS images
2. **[Unsigned Deployment Guide](guides/unsigned-deployment.md)** - Deploy with unsigned Tesla drivers
3. **[Lutris Quick Start](guides/LUTRIS-QUICKSTART.md)** - Using the game launcher

---

## 📖 User Guides

Step-by-step guides for common tasks:

- **[Build Instructions](guides/build-instructions.md)** - Building LudOS images and ISOs
- **[Deployment Guide](guides/deployment-guide.md)** - General deployment procedures
- **[Unsigned Deployment](guides/unsigned-deployment.md)** - Deploying without Secure Boot
- **[Lutris Quick Start](guides/LUTRIS-QUICKSTART.md)** - Game launcher usage and troubleshooting

---

## 🔧 Reference Documentation

Technical details and command references:

- **[Command Reference](reference/command-reference.md)** - Complete command-line tool documentation
- **[Gamescope Display Guide](reference/gamescope-display-guide.md)** - Display system architecture
- **[OpenBox Troubleshooting](reference/openbox-troubleshooting.md)** - Window manager issues
- **[Tesla Quick Reference](reference/tesla-quick-reference.md)** - Tesla driver management
- **[Tesla P4 Fixes](reference/tesla-p4-fixes.md)** - Known Tesla issues and solutions

---

## 🏗️ Implementation Details

Advanced technical documentation:

- **[Playnite/Lutris Implementation](impl/playnite-implementation.md)** - Game launcher architecture

---

## 🗃️ Archive

Historical documentation (kept for reference):

- **[Steam GLX Fix Approach](archive/steam-glx-fix-approach.md)** - Why we don't use Steam Big Picture
- **[Steam UI Solutions Index](archive/steam-ui-solutions-index.md)** - Alternative UI comparison

---

## 🚀 Quick Links

### Common Commands

```bash
# Display management
ludos-display status
ludos-display test

# Game launcher
ludos-lutris status
ludos-lutris logs

# Window manager
ludos-openbox verify
ludos-openbox status

# Tesla drivers
ludos-tesla-setup status
nvidia-smi

# Streaming
systemctl status sunshine
```

### Service Status Check

```bash
# Check all LudOS services
systemctl status ludos-gamescope-display
systemctl status ludos-openbox
systemctl status ludos-lutris
systemctl status sunshine
```

---

## 📦 LudOS Architecture

```
[Moonlight Client]
    ↓ H.265 Stream
[Sunshine Server] (NVENC on Tesla P4)
    ↓ Capture Display :0
[Gamescope Compositor] (Headless Vulkan)
    ↓ Display :0 (Xwayland)
[OpenBox Window Manager]
    ↓ Window management
[Lutris Game Launcher]
    ├─ Steam Library
    ├─ GOG Games
    ├─ Epic Games
    └─ Standalone Games
        ↓ Launch
[Games on Tesla GPU]
```

---

## ❓ Need Help?

1. **Check guides** - Start with the guides above
2. **Check reference** - Look up specific commands
3. **Check logs** - Use `journalctl -u <service-name> -n 50`
4. **Report issues** - Include logs and system info

### Gathering System Info

```bash
# Version
cat VERSION

# GPU
nvidia-smi --query-gpu=name,driver_version --format=csv

# Services
systemctl status ludos-gamescope-display ludos-openbox ludos-lutris sunshine

# Recent logs
journalctl -u ludos-lutris.service -n 50
```

---

## 📝 Contributing

When adding new documentation:

- **Guides** go in `guides/` - Step-by-step tutorials
- **Reference** goes in `reference/` - Technical details, commands
- **Implementation** goes in `impl/` - Architecture, design docs
- **Archive** for deprecated but historical docs

Keep documentation focused, searchable, and up-to-date.
