#!/usr/bin/env bash
# Quick installer for DGX Tunnel Setup & AI Workbench Toolkit
set -euo pipefail

echo "=========================================="
echo "DGX Tunnel & AI Workbench Toolkit Installer"
echo "=========================================="
echo

# Check if running from repo directory
if [[ ! -f "aiwctl" ]] || [[ ! -f "scripts/setup-dgx-tunnel.sh" ]]; then
    echo "Error: Must run from repository root directory"
    exit 1
fi

install_aiwctl() {
    echo "Installing aiwctl to /usr/local/bin/..."
    if [[ ! -x "aiwctl" ]]; then
        chmod +x aiwctl
    fi
    sudo install -m 755 aiwctl /usr/local/bin/aiwctl
    echo "✓ aiwctl installed"
}

install_dgx_tunnel() {
    echo "Installing setup-dgx-tunnel.sh to ~/.local/bin/..."
    mkdir -p ~/.local/bin
    if [[ ! -x "scripts/setup-dgx-tunnel.sh" ]]; then
        chmod +x scripts/setup-dgx-tunnel.sh
    fi
    cp scripts/setup-dgx-tunnel.sh ~/.local/bin/
    echo "✓ setup-dgx-tunnel.sh installed"

    # Check if ~/.local/bin is in PATH
    if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
        echo
        echo "⚠️  Warning: ~/.local/bin is not in your PATH"
        echo "Add this to your ~/.bashrc or ~/.zshrc:"
        echo '    export PATH="$HOME/.local/bin:$PATH"'
    fi
}

install_scripts() {
    echo "Making all scripts executable..."
    chmod +x scripts/*.sh 2>/dev/null || true
    echo "✓ Scripts are executable"
}

# Main installation
echo "What would you like to install?"
echo "  1) aiwctl only (requires sudo)"
echo "  2) DGX tunnel script only (user install)"
echo "  3) Both (recommended)"
echo "  4) Just make scripts executable"
echo
read -p "Enter choice [1-4]: " choice

case "$choice" in
    1)
        install_aiwctl
        ;;
    2)
        install_dgx_tunnel
        ;;
    3)
        install_aiwctl
        echo
        install_dgx_tunnel
        echo
        install_scripts
        ;;
    4)
        install_scripts
        ;;
    *)
        echo "Invalid choice"
        exit 1
        ;;
esac

echo
echo "=========================================="
echo "Installation Complete!"
echo "=========================================="
echo
echo "Next steps:"
echo

if [[ "$choice" == "1" ]] || [[ "$choice" == "3" ]]; then
    echo "• Run 'aiwctl help' to see AI Workbench commands"
    echo "• Run 'aiwctl install' to set up AI Workbench"
fi

if [[ "$choice" == "2" ]] || [[ "$choice" == "3" ]]; then
    echo "• Run 'setup-dgx-tunnel.sh --help' for DGX tunnel setup"
    echo "• Run 'setup-dgx-tunnel.sh --dry-run' to preview configuration"
fi

if [[ "$choice" == "3" ]]; then
    echo "• Run './scripts/validate.sh' to test DGX tunnel script"
fi

echo
