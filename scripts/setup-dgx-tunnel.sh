#!/usr/bin/env bash
set -euo pipefail

# Default configuration
MODE="system"
LOCAL_BIND="0.0.0.0"
DGX_USER="rjackson"
DGX_HOST="192.168.0.240"
SSH_KEY=""
LP1=12000 RP1=11000
LP2=12001 RP2=11002
LP3=12003 RP3=11003
ALLOW_SUBNET=""
JUPYTER_TOKEN=""
DRY_RUN=false
UNINSTALL=false

usage() {
  cat <<USAGE
Usage: $0 [opts]
  --mode [system|user]         (default: system)
  --bind [0.0.0.0|127.0.0.1]   (default: 0.0.0.0)
  --dgx-user USER              (default: rjackson)
  --dgx-host HOST              (default: 192.168.0.240)
  --ssh-key PATH               (optional, e.g. ~/.ssh/id_rsa)
  --lp1 N --rp1 N              (default: 12000 -> 11000)
  --lp2 N --rp2 N              (default: 12001 -> 11002)
  --lp3 N --rp3 N              (default: 12003 -> 11003)
  --allow-subnet CIDR          (optional, e.g. 192.168.0.0/24)
  --token JUPYTER_TOKEN        (optional)
  --dry-run                    Preview configuration without applying
  --uninstall                  Remove the tunnel service
  -h, --help                   Show this help message

Examples:
  # Install system-wide tunnel (requires sudo)
  sudo $0 --mode system --dgx-host 192.168.0.240

  # Install user-mode tunnel
  $0 --mode user --bind 127.0.0.1

  # Preview configuration
  $0 --dry-run --mode system

  # Uninstall
  sudo $0 --uninstall --mode system
USAGE
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode) MODE="$2"; shift 2;;
    --bind) LOCAL_BIND="$2"; shift 2;;
    --dgx-user) DGX_USER="$2"; shift 2;;
    --dgx-host) DGX_HOST="$2"; shift 2;;
    --ssh-key) SSH_KEY="$2"; shift 2;;
    --lp1) LP1="$2"; shift 2;; --rp1) RP1="$2"; shift 2;;
    --lp2) LP2="$2"; shift 2;; --rp2) RP2="$2"; shift 2;;
    --lp3) LP3="$2"; shift 2;; --rp3) RP3="$2"; shift 2;;
    --allow-subnet) ALLOW_SUBNET="$2"; shift 2;;
    --token) JUPYTER_TOKEN="$2"; shift 2;;
    --dry-run) DRY_RUN=true; shift;;
    --uninstall) UNINSTALL=true; shift;;
    -h|--help) usage; exit 0;;
    *) echo "Error: Unknown argument: $1"; usage; exit 1;;
  esac
done

# Validation functions
validate_mode() {
  if [[ "$MODE" != "system" && "$MODE" != "user" ]]; then
    echo "Error: --mode must be 'system' or 'user', got: '$MODE'" >&2
    exit 1
  fi
}

validate_bind() {
  if [[ "$LOCAL_BIND" != "0.0.0.0" && "$LOCAL_BIND" != "127.0.0.1" ]]; then
    echo "Error: --bind must be '0.0.0.0' or '127.0.0.1', got: '$LOCAL_BIND'" >&2
    exit 1
  fi
}

validate_cidr() {
  if [[ -n "$ALLOW_SUBNET" ]]; then
    if ! [[ "$ALLOW_SUBNET" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}$ ]]; then
      echo "Error: Invalid CIDR notation: '$ALLOW_SUBNET'" >&2
      echo "Expected format: 192.168.0.0/24" >&2
      exit 1
    fi
  fi
}

validate_port() {
  local port=$1
  local name=$2
  if ! [[ "$port" =~ ^[0-9]+$ ]] || [[ "$port" -lt 1 || "$port" -gt 65535 ]]; then
    echo "Error: Invalid port for $name: '$port'" >&2
    exit 1
  fi
}

validate_ports() {
  validate_port "$LP1" "--lp1"
  validate_port "$LP2" "--lp2"
  validate_port "$LP3" "--lp3"
  validate_port "$RP1" "--rp1"
  validate_port "$RP2" "--rp2"
  validate_port "$RP3" "--rp3"
}

check_port_available() {
  local port=$1
  if command -v ss >/dev/null 2>&1; then
    if ss -ltn | grep -q ":${port} "; then
      return 1
    fi
  elif command -v netstat >/dev/null 2>&1; then
    if netstat -ltn 2>/dev/null | grep -q ":${port} "; then
      return 1
    fi
  fi
  return 0
}

validate_ports_available() {
  local conflicts=()
  for port in "$LP1" "$LP2" "$LP3"; do
    if ! check_port_available "$port"; then
      conflicts+=("$port")
    fi
  done

  if [[ ${#conflicts[@]} -gt 0 ]]; then
    echo "Warning: The following local ports are already in use: ${conflicts[*]}" >&2
    echo "The tunnel service may fail to start. Stop conflicting services or choose different ports." >&2
    if [[ "$DRY_RUN" == "false" ]]; then
      read -p "Continue anyway? (y/N) " -n 1 -r
      echo
      if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
      fi
    fi
  fi
}

test_ssh_connection() {
  echo "Testing SSH connection to ${DGX_USER}@${DGX_HOST}..."
  local ssh_opts="-o ConnectTimeout=10 -o BatchMode=yes -o StrictHostKeyChecking=accept-new"
  if [[ -n "$SSH_KEY" ]]; then
    ssh_opts="$ssh_opts -i $SSH_KEY"
  fi

  if ssh $ssh_opts "${DGX_USER}@${DGX_HOST}" exit 2>/dev/null; then
    echo "✓ SSH connection successful"
    return 0
  else
    echo "Error: Cannot connect to ${DGX_USER}@${DGX_HOST}" >&2
    echo "Please ensure:" >&2
    echo "  1. SSH keys are configured for passwordless authentication" >&2
    echo "  2. Host is reachable: ping $DGX_HOST" >&2
    echo "  3. SSH service is running on the host" >&2
    if [[ -n "$SSH_KEY" ]]; then
      echo "  4. SSH key exists and has correct permissions: $SSH_KEY" >&2
    fi
    return 1
  fi
}

# Run validations
validate_mode
validate_bind
validate_cidr
validate_ports

# Check permissions early
if [[ "$MODE" == "system" ]] && [[ $EUID -ne 0 ]] && [[ "$DRY_RUN" == "false" ]]; then
  echo "Error: System mode requires root privileges. Run with sudo." >&2
  exit 1
fi

# Check for required commands
SSH_BIN="$(command -v ssh || true)"
if [[ -z "$SSH_BIN" ]]; then
  echo "Error: ssh command not found. Install openssh-client." >&2
  exit 1
fi

# Validate SSH key if provided
if [[ -n "$SSH_KEY" ]]; then
  if [[ ! -f "$SSH_KEY" ]]; then
    echo "Error: SSH key not found: $SSH_KEY" >&2
    exit 1
  fi
  if [[ ! -r "$SSH_KEY" ]]; then
    echo "Error: SSH key not readable: $SSH_KEY" >&2
    exit 1
  fi
fi

# Setup systemd paths
UNIT_NAME="dgx-tunnel.service"
LOG_PATH_SYSTEM="/var/log/dgx-tunnel.log"
LOG_PATH_USER="$HOME/logs/dgx-tunnel.log"

if [[ "$MODE" == "system" ]]; then
  UNIT_FILE="/etc/systemd/system/${UNIT_NAME}"
  LOG_PATH="$LOG_PATH_SYSTEM"
  SYSCTL_CMD="systemctl"
  JOURNAL_CMD="journalctl -u"
else
  UNIT_DIR="$HOME/.config/systemd/user"
  UNIT_FILE="$UNIT_DIR/$UNIT_NAME"
  LOG_PATH="$LOG_PATH_USER"
  SYSCTL_CMD="systemctl --user"
  JOURNAL_CMD="journalctl --user -u"
fi

# Handle uninstall
if [[ "$UNINSTALL" == "true" ]]; then
  echo "Uninstalling DGX tunnel service..."

  if [[ -f "$UNIT_FILE" ]]; then
    if [[ "$DRY_RUN" == "true" ]]; then
      echo "[DRY RUN] Would stop and disable: $UNIT_NAME"
      echo "[DRY RUN] Would remove: $UNIT_FILE"
    else
      $SYSCTL_CMD stop "$UNIT_NAME" 2>/dev/null || true
      $SYSCTL_CMD disable "$UNIT_NAME" 2>/dev/null || true
      rm -f "$UNIT_FILE"
      $SYSCTL_CMD daemon-reload
      echo "✓ Service removed: $UNIT_NAME"
      echo "Log file preserved at: $LOG_PATH"
    fi
  else
    echo "Service not found: $UNIT_FILE"
  fi
  exit 0
fi

# Build SSH command
SSH_CMD="$SSH_BIN -N -g -o ExitOnForwardFailure=yes -o ServerAliveInterval=60"
if [[ -n "$SSH_KEY" ]]; then
  SSH_CMD="$SSH_CMD -i $SSH_KEY"
fi
SSH_CMD="$SSH_CMD -L ${LOCAL_BIND}:${LP1}:localhost:${RP1}"
SSH_CMD="$SSH_CMD -L ${LOCAL_BIND}:${LP2}:localhost:${RP2}"
SSH_CMD="$SSH_CMD -L ${LOCAL_BIND}:${LP3}:127.0.0.1:${RP3}"
SSH_CMD="$SSH_CMD ${DGX_USER}@${DGX_HOST}"

# Determine actual user (for system mode)
if [[ "$MODE" == "system" ]]; then
  ACTUAL_USER="${SUDO_USER:-$(logname 2>/dev/null || echo "$USER")}"
else
  ACTUAL_USER="$USER"
fi

# Generate systemd unit content
generate_systemd_unit() {
  if [[ "$MODE" == "system" ]]; then
    cat <<SYSUNIT
[Unit]
Description=DGX Spark SSH Tunnel (system-wide)
After=network-online.target
Wants=network-online.target

[Service]
User=$ACTUAL_USER
StandardOutput=append:${LOG_PATH}
StandardError=append:${LOG_PATH}
ExecStart=$SSH_CMD
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SYSUNIT
  else
    cat <<USRUNIT
[Unit]
Description=DGX Spark SSH Tunnel (user)
After=network-online.target
Wants=network-online.target

[Service]
StandardOutput=append:${LOG_PATH}
StandardError=append:${LOG_PATH}
ExecStart=$SSH_CMD
Restart=always
RestartSec=5

[Install]
WantedBy=default.target
USRUNIT
  fi
}

# Firewall management
open_firewall_port() {
  local port="$1"

  if [[ "$MODE" != "system" ]]; then
    # User mode: only print warnings, don't attempt sudo
    if command -v ufw >/dev/null 2>&1 || command -v firewall-cmd >/dev/null 2>&1; then
      echo "Note: Firewall detected. You may need to manually open port $port/tcp"
    fi
    return 0
  fi

  if command -v ufw >/dev/null 2>&1; then
    if [[ -n "$ALLOW_SUBNET" ]]; then
      ufw allow from "$ALLOW_SUBNET" to any port "$port" proto tcp 2>/dev/null || true
    else
      ufw allow "$port"/tcp 2>/dev/null || true
    fi
  elif command -v firewall-cmd >/dev/null 2>&1; then
    if [[ -n "$ALLOW_SUBNET" ]]; then
      firewall-cmd --permanent --add-rich-rule="rule family=ipv4 source address=${ALLOW_SUBNET} port protocol=tcp port=${port} accept" 2>/dev/null || true
      firewall-cmd --reload 2>/dev/null || true
    else
      firewall-cmd --permanent --add-port="${port}"/tcp 2>/dev/null || true
      firewall-cmd --reload 2>/dev/null || true
    fi
  fi
}

# Dry run mode - show configuration and exit
if [[ "$DRY_RUN" == "true" ]]; then
  echo "=== DRY RUN MODE ==="
  echo
  echo "Configuration:"
  echo "  Mode: $MODE"
  echo "  Bind address: $LOCAL_BIND"
  echo "  DGX user: $DGX_USER"
  echo "  DGX host: $DGX_HOST"
  if [[ -n "$SSH_KEY" ]]; then
    echo "  SSH key: $SSH_KEY"
  fi
  echo "  Port forwards:"
  echo "    ${LOCAL_BIND}:${LP1} -> ${DGX_HOST}:localhost:${RP1}"
  echo "    ${LOCAL_BIND}:${LP2} -> ${DGX_HOST}:localhost:${RP2}"
  echo "    ${LOCAL_BIND}:${LP3} -> ${DGX_HOST}:127.0.0.1:${RP3}"
  if [[ -n "$ALLOW_SUBNET" ]]; then
    echo "  Firewall: Allow from $ALLOW_SUBNET"
  fi
  echo
  echo "Unit file location: $UNIT_FILE"
  echo "Log file location: $LOG_PATH"
  echo
  echo "Generated systemd unit:"
  echo "---"
  generate_systemd_unit
  echo "---"
  echo
  echo "SSH command:"
  echo "$SSH_CMD"
  exit 0
fi

# Check port availability
validate_ports_available

# Test SSH connection
if ! test_ssh_connection; then
  echo
  read -p "SSH connection test failed. Continue anyway? (y/N) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
  fi
fi

# Create log directory and file
if [[ "$MODE" == "system" ]]; then
  touch "$LOG_PATH"
  chown "${ACTUAL_USER}:$(id -gn "$ACTUAL_USER" 2>/dev/null || echo "$ACTUAL_USER")" "$LOG_PATH" 2>/dev/null || true
  chmod 640 "$LOG_PATH" 2>/dev/null || true
else
  mkdir -p "$(dirname "$LOG_PATH")"
  touch "$LOG_PATH"
  chmod 640 "$LOG_PATH" 2>/dev/null || true
fi

# Create systemd unit
if [[ "$MODE" == "system" ]]; then
  generate_systemd_unit > "$UNIT_FILE"
else
  mkdir -p "$UNIT_DIR"
  generate_systemd_unit > "$UNIT_FILE"
fi

# Reload and enable service
$SYSCTL_CMD daemon-reload
$SYSCTL_CMD enable --now "$UNIT_NAME"

# Open firewall ports if binding to 0.0.0.0
if [[ "$LOCAL_BIND" == "0.0.0.0" ]]; then
  for port in "$LP1" "$LP2" "$LP3"; do
    open_firewall_port "$port"
  done
fi

# Wait for service to start
sleep 2

# Check listeners
echo
echo "Checking listeners:"
if command -v ss >/dev/null 2>&1; then
  ss -ltnp 2>/dev/null | grep -E ":(${LP1}|${LP2}|${LP3})\b" || echo "  (No listeners detected yet - service may still be starting)"
else
  netstat -ltnp 2>/dev/null | grep -E ":(${LP1}|${LP2}|${LP3})\b" || echo "  (No listeners detected yet - service may still be starting)"
fi

# Display summary
HOST_IPS=$(hostname -I 2>/dev/null || echo "127.0.0.1")
echo
echo "✓ Tunnel service installed and started in '$MODE' mode"
echo
echo "Port forwards:"
echo "  ${LOCAL_BIND}:${LP1} -> ${DGX_HOST}:localhost:${RP1}"
echo "  ${LOCAL_BIND}:${LP2} -> ${DGX_HOST}:localhost:${RP2}"
echo "  ${LOCAL_BIND}:${LP3} -> ${DGX_HOST}:127.0.0.1:${RP3}  (Jupyter)"
echo
echo "This host's IPs: ${HOST_IPS}"

if [[ -n "$JUPYTER_TOKEN" ]]; then
  FIRST_IP=$(echo "$HOST_IPS" | awk '{for(i=1;i<=NF;i++) if ($i ~ /^[0-9.]+$/) {print $i; exit}}')
  if [[ -n "$FIRST_IP" ]]; then
    echo
    echo "Access Jupyter via tunnel:"
    echo "  http://${FIRST_IP}:${LP3}/lab?token=${JUPYTER_TOKEN}"
  fi
else
  echo
  echo "Access Jupyter (if token known):"
  echo "  http://<HOST_IP>:${LP3}/lab?token=<TOKEN>"
fi

echo
echo "Service status:"
$SYSCTL_CMD status "$UNIT_NAME" --no-pager --lines=0 || true

echo
echo "View logs with:"
echo "  $JOURNAL_CMD $UNIT_NAME -f"
echo
echo "To uninstall, run:"
if [[ "$MODE" == "system" ]]; then
  echo "  sudo $0 --uninstall --mode system"
else
  echo "  $0 --uninstall --mode user"
fi
