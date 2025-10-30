# DGX Tunnel Setup & NVIDIA AI Workbench Toolkit

Systemd + SSH tunnel setup script for NVIDIA DGX Spark + Jupyter access, plus complete AI Workbench management toolkit for Omarchy 3.1.1

## Overview

This repository contains two main components:

1. **DGX Tunnel Setup** - Automated SSH tunnel management for DGX systems
2. **AI Workbench Toolkit** - Complete installer and control utility for NVIDIA AI Workbench on Omarchy 3.1.1

### DGX Tunnel Setup

Automates the setup of persistent SSH tunnels to NVIDIA DGX systems using systemd services. It supports both system-wide and user-mode installations with comprehensive validation and error handling.

## Features

- Automatic systemd service creation (system or user mode)
- Multiple SSH tunnel configuration (3 ports by default)
- Firewall integration (UFW and firewalld)
- Input validation (ports, CIDR, SSH keys)
- SSH connection testing before installation
- Port conflict detection
- Dry-run mode for previewing configuration
- Easy uninstall functionality
- Comprehensive logging

## Quick Start

```bash
# Install system-wide tunnel (requires sudo)
sudo ./scripts/setup-dgx-tunnel.sh --mode system --dgx-host 192.168.0.240

# Install user-mode tunnel
./scripts/setup-dgx-tunnel.sh --mode user --bind 127.0.0.1

# Preview configuration without installing
./scripts/setup-dgx-tunnel.sh --dry-run

# Uninstall
sudo ./scripts/setup-dgx-tunnel.sh --uninstall --mode system
```

## Usage

```bash
./scripts/setup-dgx-tunnel.sh [options]

Options:
  --mode [system|user]         Installation mode (default: system)
  --bind [0.0.0.0|127.0.0.1]   Local bind address (default: 0.0.0.0)
  --dgx-user USER              SSH username (default: rjackson)
  --dgx-host HOST              DGX hostname/IP (default: 192.168.0.240)
  --ssh-key PATH               Path to SSH key (optional)
  --lp1 N --rp1 N              Port mapping 1 (default: 12000 -> 11000)
  --lp2 N --rp2 N              Port mapping 2 (default: 12001 -> 11002)
  --lp3 N --rp3 N              Port mapping 3 (default: 12003 -> 11003)
  --allow-subnet CIDR          Restrict firewall to subnet (optional)
  --token JUPYTER_TOKEN        Jupyter token for URL generation (optional)
  --dry-run                    Preview without installing
  --uninstall                  Remove the service
  -h, --help                   Show help message
```

## Port Mappings

By default, the script creates these SSH tunnels:

- `localhost:12000` -> `dgx:11000` (Spark port 1)
- `localhost:12001` -> `dgx:11002` (Spark port 2)
- `localhost:12003` -> `dgx:11003` (Jupyter)

## Prerequisites

- SSH client (`openssh-client`)
- systemd
- Passwordless SSH authentication to DGX host
- sudo access (for system mode)

## Testing

Run the validation suite:

```bash
./scripts/validate.sh
```

This runs 13 comprehensive tests covering:
- Help and documentation
- Dry-run functionality
- Input validation
- Port configuration
- CIDR validation
- SSH key validation
- Uninstall functionality

## Examples

### Basic Installation

```bash
# System-wide (accessible from all network interfaces)
sudo ./scripts/setup-dgx-tunnel.sh --dgx-host 192.168.0.240

# User-mode (local only)
./scripts/setup-dgx-tunnel.sh --mode user --bind 127.0.0.1
```

### Custom Ports

```bash
./scripts/setup-dgx-tunnel.sh --mode user \
  --lp1 9000 --rp1 8000 \
  --lp2 9001 --rp2 8001 \
  --lp3 9002 --rp2 8888
```

### With SSH Key

```bash
sudo ./scripts/setup-dgx-tunnel.sh \
  --ssh-key ~/.ssh/dgx_rsa \
  --dgx-user myuser \
  --dgx-host dgx.example.com
```

### Restricted Access

```bash
# Only allow connections from 192.168.0.0/24
sudo ./scripts/setup-dgx-tunnel.sh \
  --allow-subnet 192.168.0.0/24
```

## Service Management

```bash
# Check status (system mode)
systemctl status dgx-tunnel.service

# Check status (user mode)
systemctl --user status dgx-tunnel.service

# View logs (system mode)
journalctl -u dgx-tunnel.service -f

# View logs (user mode)
journalctl --user -u dgx-tunnel.service -f

# Restart service
systemctl restart dgx-tunnel.service  # or with --user
```

## Troubleshooting

### SSH Connection Fails

Ensure passwordless SSH is configured:
```bash
ssh-copy-id rjackson@192.168.0.240
```

### Port Already in Use

Stop conflicting services or choose different ports:
```bash
# Find what's using the port
sudo ss -ltnp | grep :12000

# Use different ports
./scripts/setup-dgx-tunnel.sh --lp1 13000 --dry-run
```

### Firewall Issues

Manually open ports if needed:
```bash
# UFW
sudo ufw allow 12000/tcp

# firewalld
sudo firewall-cmd --permanent --add-port=12000/tcp
sudo firewall-cmd --reload
```

## Improvements Over Original

1. Added comprehensive input validation
2. SSH connection testing before installation
3. Port conflict detection
4. Dry-run mode for safe configuration preview
5. Uninstall functionality
6. Better error messages
7. SSH key path support
8. Fixed user determination in system mode
9. Improved firewall handling for user mode
10. Added comprehensive test suite

## Files

- [setup-dgx-tunnel.sh](scripts/setup-dgx-tunnel.sh) - Main setup script
- [validate.sh](scripts/validate.sh) - Validation test suite
- [test-setup.sh](scripts/test-setup.sh) - Comprehensive test script

---

# NVIDIA AI Workbench Setup Toolkit for Omarchy 3.1.1

A complete installer, uninstaller, and control utility (`aiwctl`) to manage **NVIDIA AI Workbench** on **Omarchy 3.1.1** (Arch-based Linux).
Optimized for **DGX Spark**, **A40**, and other NVIDIA GPUs.

## AI Workbench Overview

This toolkit makes it simple to:
- Install all dependencies (drivers, CUDA, Docker, NVIDIA Container Toolkit)
- Download and set up NVIDIA AI Workbench AppImage
- Verify GPU & Docker integration
- Uninstall or update cleanly
- Control everything via a single CLI tool: `aiwctl`

## Installation

### Quick Install (Recommended)

Interactive installer for both tools:

```bash
git clone https://github.com/<your-username>/dgx-tunnel-setup.git
cd dgx-tunnel-setup
./install.sh
```

The installer will prompt you to choose:
1. Install `aiwctl` only (requires sudo)
2. Install DGX tunnel script only (user install)
3. Install both (recommended)
4. Just make scripts executable

### Manual Installation

#### Install aiwctl

```bash
cd dgx-tunnel-setup
sudo install -m 755 aiwctl /usr/local/bin/aiwctl
aiwctl help
```

#### Install DGX Tunnel Script

```bash
cd dgx-tunnel-setup
mkdir -p ~/.local/bin
cp scripts/setup-dgx-tunnel.sh ~/.local/bin/
setup-dgx-tunnel.sh --help
```

## aiwctl Usage

| Command            | Description                                     |
| ------------------ | ----------------------------------------------- |
| `aiwctl install`   | Installs NVIDIA AI Workbench with CUDA + Docker |
| `aiwctl test-gpu`  | Verifies GPU and Docker runtime integration     |
| `aiwctl update`    | Updates AI Workbench to latest AppImage         |
| `aiwctl uninstall` | Removes Workbench, Docker, and optionally CUDA  |
| `aiwctl help`      | Displays help and usage info                    |

## AI Workbench Example Workflow

```bash
# 1. Install everything
aiwctl install

# 2. Test GPU visibility
aiwctl test-gpu

# 3. Launch Workbench
ai-workbench

# 4. (Optional) Update later
aiwctl update
```

## Example AI Workbench Projects

Clone official NVIDIA examples directly inside Workbench:

```bash
ai-workbench clone https://github.com/NVIDIA/workbench-example-llama3-finetune
ai-workbench clone https://github.com/NVIDIA/workbench-example-hybrid-rag
```

## AI Workbench Compatibility

| Component         | Supported Version                      |
| ----------------- | -------------------------------------- |
| OS                | Omarchy 3.1.1 (Arch-based)             |
| GPU               | A40, A100, L40S, RTX 5090              |
| CUDA              | 12.2+                                  |
| Container Runtime | Docker 25.x + NVIDIA Container Toolkit |
| Workbench         | Latest AppImage build                  |

## AI Workbench Uninstall

To remove everything cleanly:

```bash
aiwctl uninstall
```

Or use the standalone script:

```bash
./uninstall_ai_workbench.sh
```

## Complete Toolkit Files

### Installation
- [install.sh](install.sh) - Interactive installer for all tools

### DGX Tunnel Setup
- [setup-dgx-tunnel.sh](scripts/setup-dgx-tunnel.sh) - Main setup script (454 lines)
- [validate.sh](scripts/validate.sh) - Quick validation suite (102 lines)
- [test-setup.sh](scripts/test-setup.sh) - Comprehensive test script (309 lines)

### AI Workbench Toolkit
- [aiwctl](aiwctl) - Unified management CLI (107 lines)

## Installation to Local Bin

The DGX tunnel script is also available as a standalone command:

```bash
# Script is already installed at:
~/.local/bin/setup-dgx-tunnel.sh

# Use it from anywhere:
setup-dgx-tunnel.sh --help
setup-dgx-tunnel.sh --dry-run --mode user
```

## Notes

- DGX Tunnel Setup is optimized for **persistent SSH tunnels** to DGX systems
- AI Workbench Toolkit is optimized for **local GPU development** (DGX Spark, A40)
- For remote cluster mode, configure SSH access to your target node
- Built and tested on **Omarchy 3.1.1 kernel 6.10+** with **CUDA 12.4**

## License

MIT License © 2025 Robert A. Jackson II

---

> *"Build locally, scale anywhere — with Workbench as your AI lab."*
