# LudOS - Headless Gaming VM

LudOS is a specialized headless gaming virtual machine image built on Fedora 42 with NVIDIA datacenter GPU support. It's designed for streaming games to remote clients using Sunshine/Moonlight technology, making it perfect for cloud gaming, home lab setups, and datacenter gaming deployments.

## Features

- **Headless Gaming**: No physical display required - games run on virtual displays
- **NVIDIA Datacenter GPU Support**: Optimized for Tesla P4, K80, T4, V100, and other datacenter GPUs  
- **NVIDIA GRID vGPU Compatible**: Full support for GRID licensing and mdev profiles
- **Sunshine Streaming**: Built-in streaming server for Moonlight clients
- **Gamescope Integration**: Virtual display compositor for seamless gaming
- **Steam Ready**: Pre-configured Steam installation with Proton compatibility
- **Container-Based**: Built using bootc for atomic updates and rollbacks

## Quick Start

### Prerequisites

- NVIDIA datacenter GPU (Tesla P4, K80, T4, V100, A10, etc.)
- Hypervisor with GPU passthrough support (for VMs)
- NVIDIA GRID license (for vGPU features)

### Building LudOS

1. **Install build tools**:
   ```bash
   # Fedora/RHEL
   sudo dnf install -y podman buildah just git
   
   # Ubuntu/Debian  
   sudo apt install -y podman buildah git
   curl --proto '=https' --tlsv1.2 -sSf https://just.systems/install.sh | bash -s -- --to /usr/local/bin
   ```

2. **Clone and build**:
   ```bash
   git clone <your-ludos-repo-url>
   cd LudOS
   just build
   ```

3. **Create VM image**:
   ```bash
   just build-qcow2  # For virtual machines
   just build-iso    # For bare metal installation
   ```
   
   **Note**: The build process takes 10-30 minutes. You'll be prompted for your sudo password at the start. The script will automatically keep sudo active during the entire build, so you can safely leave your computer during the build process.

### Deployment

Deploy the QCOW2 image to your hypervisor with:
- **CPU**: 4+ cores
- **RAM**: 8GB minimum, 16GB recommended  
- **GPU**: NVIDIA datacenter GPU with passthrough
- **Network**: Bridge mode for client access

### Post-Installation Setup

#### Quick Setup (Consumer Drivers)
For basic gaming with consumer NVIDIA drivers:
```bash
# Run post-installation setup
sudo /etc/ludos/ludos-setup.sh

# Configure Sunshine at https://your-vm-ip:47990
# Connect Moonlight clients to VM IP
```

#### Tesla Datacenter Drivers
For enterprise Tesla GPU support:

1. **Download Tesla drivers** from NVIDIA:
   - Visit: https://www.nvidia.com/Download/index.aspx
   - Select: Tesla / Linux 64-bit / [Version]
   - Download: `NVIDIA-Linux-x86_64-VERSION.run`

2. **Install Tesla drivers**:
   ```bash
   # Transfer driver file to LudOS VM
   scp NVIDIA-Linux-x86_64-580.82.07.run ludos@<vm-ip>:~/
   
   # Install Tesla drivers
   sudo ludos-tesla-setup install ~/NVIDIA-Linux-x86_64-580.82.07.run
   
   # Reboot to activate
   sudo systemctl reboot
   ```

3. **Complete setup**:
   ```bash
   # Run post-installation configuration
   sudo /etc/ludos/ludos-setup.sh
   
   # Configure GRID licensing (optional)
   sudo nano /etc/nvidia/gridd.conf
   ```

4. **Connect clients**:
   - Install Moonlight on client devices
   - Add PC using LudOS VM IP address
   - Stream games remotely

📖 **For detailed Tesla deployment instructions, see [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)**

## Architecture

LudOS uses a layered approach for headless gaming:

```
┌─────────────────────────────────────┐
│           Moonlight Clients         │ ← Remote gaming clients
├─────────────────────────────────────┤
│            Network Layer            │ ← Streaming protocols
├─────────────────────────────────────┤
│         Sunshine Server             │ ← Video encoding & streaming
├─────────────────────────────────────┤
│      Gamescope (Virtual Display)    │ ← Virtual display compositor  
├─────────────────────────────────────┤
│         Steam + Games               │ ← Gaming applications
├─────────────────────────────────────┤
│       NVIDIA GRID Drivers           │ ← GPU virtualization & licensing
├─────────────────────────────────────┤
│      Fedora 42 (bootc)             │ ← Base operating system
└─────────────────────────────────────┘
```

## NVIDIA Driver Support

LudOS supports multiple NVIDIA driver configurations:

| Driver Type | Use Case | GRID Licensing | Installation |
|-------------|----------|----------------|--------------|
| **GRID vGPU** | Virtualized GPU with licensing | ✅ Yes | Manual download required |
| **Tesla Datacenter** | Bare metal datacenter GPUs | ❌ No | Manual download required |
| **CUDA Toolkit** | Compute workloads only | ❌ No | Not recommended for gaming |

For gaming with licensing support, use **GRID vGPU drivers**.

## Supported GPUs

### Primary Support (Tesla P4 Focus)
- **Tesla P4**: 8GB GDDR5, optimized for virtualization
- **Tesla K80**: 24GB GDDR5, legacy support
- **Tesla T4**: 16GB GDDR6, modern datacenter

### Extended Support  
- **Tesla V100**: 32GB HBM2, high-end compute
- **Tesla A10**: 24GB GDDR6, latest generation
- **Quadro RTX**: Various models with GRID support

## Community

- **Issues & Support**: [GitHub Issues](../../issues)
- **Discussions**: [GitHub Discussions](../../discussions)  
- **Universal Blue Community**: [Discord](https://discord.gg/WEu6BdFEtp)

## Documentation

- **[Deployment Guide](DEPLOYMENT_GUIDE.md)**: Complete Tesla driver deployment procedure
- **[Tesla Quick Reference](TESLA_QUICK_REFERENCE.md)**: Essential Tesla commands and troubleshooting
- **[Build Instructions](BUILD_INSTRUCTIONS.md)**: Detailed build and deployment guide
- **[NVIDIA Setup Guide](build_files/nvidia-driver-install.sh)**: Driver installation procedures
- **[Troubleshooting](BUILD_INSTRUCTIONS.md#troubleshooting)**: Common issues and solutions

## Repository Structure

- **[Containerfile](Containerfile)**: Main image definition
- **[build.sh](build_files/build.sh)**: Package installation and system configuration  
- **[Justfile](Justfile)**: Build automation and VM management
- **[GitHub Actions](.github/workflows/)**: Automated builds and releases

## Building Disk Images

Create bootable images for different deployment scenarios:

```bash
just build-qcow2    # Virtual machine image
just build-iso      # Installation ISO  
just build-raw      # Raw disk image
just run-vm-qcow2   # Test in local VM
```

## Advanced Configuration

### Custom GPU Support
Edit `build_files/build.sh` to support additional GPU types or driver versions.

### Performance Tuning  
Modify `/etc/ludos/gamescope/default.conf` for resolution, refresh rate, and upscaling settings.

### Multi-GPU Setup
Configure multiple GPUs using GRID licensing profiles and mdev device assignment.

## Security Considerations

- Change default Sunshine passwords
- Configure firewall rules for streaming ports  
- Use VPN for internet-based streaming
- Keep NVIDIA drivers updated
- Monitor system logs for unauthorized access

## License

This project is licensed under the Apache 2.0 License - see the [LICENSE](LICENSE) file for details.

## Contributing

Contributions are welcome! Please read our contributing guidelines and submit pull requests for improvements.

---

**LudOS**: Bringing datacenter-grade gaming to the cloud. Game anywhere, stream everywhere. 🎮☁️
