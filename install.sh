#!/usr/bin/env bash
# install.sh – native Linux installer for printcam-proxy
#
# Installs printcam-proxy as a systemd service on any mainstream Linux distro.
# Supported package managers: apt/apt-get, dnf, yum, pacman, zypper, apk (Alpine).
#
# Usage:
#   sudo bash install.sh                        # interactive prompts
#   sudo RTSP_URL=rtsp://... bash install.sh    # non-interactive with env vars
#
# Environment variables (all optional – defaults shown in brackets):
#   RTSP_URL   [rtsp://10.0.0.238:554/unicast]  Source RTSP stream
#   PORT       [8889]                           HTTP port to listen on
#   FPS        [15]                             Output frame rate
#   QUALITY    [5]                              JPEG quality (2-31, lower = better)
#   INSTALL_DIR[/opt/printcam-proxy]            Where to install server.py
#   SERVICE    [printcam-proxy]                 systemd service name

set -euo pipefail

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()    { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }
die()     { error "$*"; exit 1; }

# ---------------------------------------------------------------------------
# Pre-flight checks
# ---------------------------------------------------------------------------
[[ "$(uname -s)" == "Linux" ]] || die "This installer only supports Linux."

if [[ $EUID -ne 0 ]]; then
    die "Please run as root or with sudo:\n  sudo bash $0"
fi

command -v systemctl >/dev/null 2>&1 || die "systemd is required but systemctl was not found."

# ---------------------------------------------------------------------------
# Locate server.py (same directory as this script, or current directory)
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER_SRC="${SCRIPT_DIR}/server.py"
[[ -f "$SERVER_SRC" ]] || SERVER_SRC="$(pwd)/server.py"
[[ -f "$SERVER_SRC" ]] || die "server.py not found. Run this script from the printcam-proxy directory."

# ---------------------------------------------------------------------------
# Configuration (env vars override interactive prompts)
# ---------------------------------------------------------------------------
INSTALL_DIR="${INSTALL_DIR:-/opt/printcam-proxy}"
SERVICE="${SERVICE:-printcam-proxy}"
ENV_FILE="/etc/printcam-proxy.env"
SERVICE_FILE="/etc/systemd/system/${SERVICE}.service"

prompt_with_default() {
    local var_name="$1"
    local prompt_text="$2"
    local default_val="$3"
    # Skip prompt when variable is already set
    if [[ -n "${!var_name:-}" ]]; then
        return
    fi
    read -r -p "${prompt_text} [${default_val}]: " input
    printf -v "$var_name" '%s' "${input:-$default_val}"
}

echo ""
echo "=== printcam-proxy – Linux installer ==="
echo ""

prompt_with_default RTSP_URL "RTSP source URL"    "rtsp://10.0.0.238:554/unicast"
prompt_with_default PORT     "HTTP listen port"   "8889"
prompt_with_default FPS      "Output frame rate"  "15"
prompt_with_default QUALITY  "JPEG quality (2-31, lower = better)" "5"

# Basic validation
[[ "$PORT" =~ ^[0-9]+$ ]] && [[ "$PORT" -ge 1 ]] && [[ "$PORT" -le 65535 ]] \
    || die "PORT must be a number between 1 and 65535 (got: $PORT)"
[[ "$FPS" =~ ^[0-9]+$ ]] && [[ "$FPS" -ge 1 ]] \
    || die "FPS must be a positive integer (got: $FPS)"
[[ "$QUALITY" =~ ^[0-9]+$ ]] && [[ "$QUALITY" -ge 2 ]] && [[ "$QUALITY" -le 31 ]] \
    || die "QUALITY must be between 2 and 31 (got: $QUALITY)"
[[ "$RTSP_URL" == rtsp://* ]] \
    || warn "RTSP_URL does not start with 'rtsp://' – proceeding anyway."

# ---------------------------------------------------------------------------
# Detect package manager and install dependencies
# ---------------------------------------------------------------------------
install_packages() {
    local pkgs=("$@")
    if command -v apt-get >/dev/null 2>&1; then
        info "Using apt-get to install: ${pkgs[*]}"
        apt-get update -qq
        DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${pkgs[@]}"
    elif command -v dnf >/dev/null 2>&1; then
        info "Using dnf to install: ${pkgs[*]}"
        dnf install -y "${pkgs[@]}"
    elif command -v yum >/dev/null 2>&1; then
        info "Using yum to install: ${pkgs[*]}"
        yum install -y "${pkgs[@]}"
    elif command -v pacman >/dev/null 2>&1; then
        info "Using pacman to install: ${pkgs[*]}"
        pacman -Sy --noconfirm "${pkgs[@]}"
    elif command -v zypper >/dev/null 2>&1; then
        info "Using zypper to install: ${pkgs[*]}"
        zypper install -y "${pkgs[@]}"
    elif command -v apk >/dev/null 2>&1; then
        info "Using apk to install: ${pkgs[*]}"
        apk add --no-cache "${pkgs[@]}"
    else
        die "No supported package manager found (tried apt-get, dnf, yum, pacman, zypper, apk).\nPlease install ffmpeg and python3 manually, then re-run this script."
    fi
}

MISSING_PKGS=()
command -v python3 >/dev/null 2>&1 || MISSING_PKGS+=("python3")
command -v ffmpeg  >/dev/null 2>&1 || MISSING_PKGS+=("ffmpeg")

if [[ ${#MISSING_PKGS[@]} -gt 0 ]]; then
    info "Installing missing dependencies: ${MISSING_PKGS[*]}"
    install_packages "${MISSING_PKGS[@]}"
else
    info "python3 and ffmpeg are already installed – skipping package installation."
fi

# Verify installs succeeded
command -v python3 >/dev/null 2>&1 || die "python3 installation failed or not in PATH."
command -v ffmpeg  >/dev/null 2>&1 || die "ffmpeg installation failed or not in PATH."

PYTHON3_VER=$(python3 --version 2>&1)
FFMPEG_VER=$(ffmpeg -version 2>&1 | head -n1)
info "  ${PYTHON3_VER}"
info "  ${FFMPEG_VER}"

# ---------------------------------------------------------------------------
# Install server.py
# ---------------------------------------------------------------------------
info "Installing server.py to ${INSTALL_DIR}/"
mkdir -p "$INSTALL_DIR"
install -m 755 "$SERVER_SRC" "${INSTALL_DIR}/server.py"

# ---------------------------------------------------------------------------
# Write environment file
# ---------------------------------------------------------------------------
info "Writing configuration to ${ENV_FILE}"
cat > "$ENV_FILE" <<EOF
# printcam-proxy configuration
# Edit this file and run: sudo systemctl restart ${SERVICE}
RTSP_URL=${RTSP_URL}
PORT=${PORT}
FPS=${FPS}
QUALITY=${QUALITY}
EOF
chmod 600 "$ENV_FILE"

# ---------------------------------------------------------------------------
# Create systemd service
# ---------------------------------------------------------------------------
info "Creating systemd service: ${SERVICE_FILE}"
cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=printcam-proxy – RTSP to MJPEG proxy for OctoPrint
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
EnvironmentFile=${ENV_FILE}
ExecStart=$(command -v python3) ${INSTALL_DIR}/server.py
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# ---------------------------------------------------------------------------
# Enable and start the service
# ---------------------------------------------------------------------------
info "Reloading systemd and enabling service..."
systemctl daemon-reload
systemctl enable --now "${SERVICE}"

# Give the service a moment to start
sleep 2

if systemctl is-active --quiet "${SERVICE}"; then
    info "Service is running."
else
    warn "Service is not running. Showing last 20 log lines:"
    journalctl -u "${SERVICE}" -n 20 --no-pager || true
    die "Service failed to start. Check the logs above."
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
HOST_IP=$(hostname -I 2>/dev/null | awk '{print $1}')
HOST_IP="${HOST_IP:-localhost}"

echo ""
echo -e "${GREEN}=== Installation complete ===${NC}"
echo ""
echo "  Stream URL:   http://${HOST_IP}:${PORT}/?action=stream"
echo "  Snapshot URL: http://${HOST_IP}:${PORT}/?action=snapshot"
echo ""
echo "Useful commands:"
echo "  sudo systemctl status  ${SERVICE}"
echo "  sudo journalctl -fu    ${SERVICE}"
echo "  sudo systemctl restart ${SERVICE}"
echo "  sudo nano              ${ENV_FILE}   # edit configuration"
echo ""
