#!/bin/bash
# Emiscreen - One-Line Installer (Linux/macOS/WSL)
# Usage: curl -fsSL https://raw.githubusercontent.com/iCleyvin/emiscreen/main/install.sh | bash
# Or with options: curl -fsSL https://raw.githubusercontent.com/iCleyvin/emiscreen/main/install.sh | bash -s --firetv 192.168.1.100

set -e

INSTALLER_VERSION="1.0.0"
GITHUB_REPO="iCleyvin/emiscreen"
GITHUB_URL="https://github.com/${GITHUB_REPO}"
RAW_URL="https://raw.githubusercontent.com/${GITHUB_REPO}/main"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${CYAN}[${1}]${NC} ${2}"; }

# Parse arguments
SOURCE="ubuntu-desktop"
FIRETV_IP=""
FIRETV_PORT="5555"
RESOLUTION="1920x1080"
FPS="30"
AUTO_START=true
SKIP_CONFIRM=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --source|-s) SOURCE="$2"; shift 2 ;;
        --firetv|-f) FIRETV_IP="$2"; shift 2 ;;
        --port|-p) FIRETV_PORT="$2"; shift 2 ;;
        --resolution|-r) RESOLUTION="$2"; shift 2 ;;
        --fps) FPS="$2"; shift 2 ;;
        --no-start) AUTO_START=false; shift ;;
        --yes|-y) SKIP_CONFIRM=true; shift ;;
        --help|-h) 
            echo "Emiscreen One-Line Installer"
            echo ""
            echo "Usage: curl -fsSL ${RAW_URL}/install.sh | bash [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --source, -s SOURCE    Capture source (ubuntu-desktop, windows-pc, nas-omv)"
            echo "  --firetv, -f IP       FireTV IP address"
            echo "  --port PORT           FireTV ADB port (default: 5555)"
            echo "  --resolution, -r RES  Resolution (default: 1920x1080)"
            echo "  --fps N               Frame rate (default: 30)"
            echo "  --no-start            Don't start server after install"
            echo "  --yes, -y             Skip confirmation prompts"
            echo "  --help, -h            Show this help"
            exit 0
            ;;
        *) shift ;;
    esac
done

# Banner
echo -e "${BOLD}"
echo "============================================"
echo "  Emiscreen Installer v${INSTALLER_VERSION}"
echo "  ${GITHUB_URL}"
echo "============================================"
echo -e "${NC}"

# Detect OS
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if grep -q "Microsoft" /proc/version 2>/dev/null; then
            echo "wsl"
        elif [ -f /etc/debian_version ]; then
            echo "debian"
        elif [ -f /etc/redhat-release ]; then
            echo "rhel"
        else
            echo "linux"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
        echo "windows"
    else
        echo "unknown"
    fi
}

OS_TYPE=$(detect_os)
log_info "Detected OS: ${OS_TYPE}"

# Detect if running as root
NEEDS_SUDO=false
if [ "$EUID" -ne 0 ]; then
    NEEDS_SUDO=true
fi

SUDO=""
if [ "$NEEDS_SUDO" = true ]; then
    SUDO="sudo"
fi

# Check for SSH session (non-interactive detection)
if [ -n "$SSH_CONNECTION" ] || [ -n "$SSH_CLIENT" ]; then
    log_info "SSH session detected"
fi

# 1. Create project directory
PROJECT_DIR="${HOME}/emiscreen"
if [ -d "${PROJECT_DIR}" ]; then
    if [ "$SKIP_CONFIRM" = false ]; then
        echo -e "${YELLOW}Emiscreen directory already exists at ${PROJECT_DIR}${NC}"
        read -p "Overwrite? [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Installation cancelled"
            exit 0
        fi
    fi
fi

log_step "1/5" "Cloning repository..."
if [ ! -d "${PROJECT_DIR}" ]; then
    git clone --depth 1 https://github.com/iCleyvin/emiscreen.git "${PROJECT_DIR}"
fi

# 2. System dependencies
log_step "2/5" "Installing system dependencies..."

install_apt() {
    $SUDO apt update -qq
    $SUDO apt install -y -qq ffmpeg xdotool x11-utils xvfb adb openssl python3 python3-pip python3-venv curl 2>/dev/null || true
}

install_yum() {
    $SUDO dnf install -y epel-release 2>/dev/null || true
    $SUDO dnf install -y ffmpeg xdotool xorg-x11-utils xorg-x11-server-Xvfb android-tools openssl python3 python3-pip curl 2>/dev/null || true
}

install_brew() {
    brew install ffmpeg adb python@3.12 2>/dev/null || true
}

case "$OS_TYPE" in
    debian) install_apt ;;
    linux) install_apt ;;
    rhel) install_yum ;;
    macos) install_brew ;;
    wsl)
        if command -v apt &> /dev/null; then
            install_apt
        else
            log_warn "WSL detected but apt not found. Install dependencies manually."
        fi
        ;;
    windows)
        log_warn "Use PowerShell installer for Windows: iwr https://raw.githubusercontent.com/iCleyvin/emiscreen/main/install.ps1 | iex"
        ;;
esac

# 3. Python environment
log_step "3/5" "Setting up Python environment..."
cd "${PROJECT_DIR}"

VENV_DIR="${PROJECT_DIR}/.venv"
if [ ! -d "${VENV_DIR}" ]; then
    python3 -m venv "${VENV_DIR}"
fi

source "${VENV_DIR}/bin/activate"
pip install --upgrade pip -q
pip install -r requirements.txt -q

# 4. SSL certificates
log_step "4/5" "Generating SSL certificates..."
mkdir -p "${PROJECT_DIR}/certs"

if [ ! -f "${PROJECT_DIR}/certs/cert.pem" ]; then
    openssl req -new -x509 -keyout "${PROJECT_DIR}/certs/key.pem" -out "${PROJECT_DIR}/certs/cert.pem" \
        -days 3650 -nodes -subj "/CN=emiscreen.local" \
        -addext "subjectAltName=DNS:emiscreen.local,DNS:localhost,IP:127.0.0.1" 2>/dev/null || \
    openssl req -new -x509 -keyout "${PROJECT_DIR}/certs/key.pem" -out "${PROJECT_DIR}/certs/cert.pem" \
        -days 3650 -nodes -subj "/CN=emiscreen.local" 2>/dev/null
fi

# 5. Configuration
log_step "5/5" "Configuring Emiscreen..."

# Create environment file
cat > "${PROJECT_DIR}/.env" << EOF
EMISCREEN_PORT=8445
EMISCREEN_SOURCE=${SOURCE}
EMISCREEN_RESOLUTION=${RESOLUTION}
EMISCREEN_FPS=${FPS}
EMISCREEN_FIRETV_IP=${FIRETV_IP}
EMISCREEN_FIRETV_PORT=${FIRETV_PORT}
EOF

# Make scripts executable
chmod +x "${PROJECT_DIR}/scripts/"*.sh 2>/dev/null || true

# Auto-connect FireTV if IP provided
if [ -n "${FIRETV_IP}" ]; then
    log_info "FireTV IP configured: ${FIRETV_IP}"
    if command -v adb &> /dev/null; then
        log_info "Testing ADB connection to FireTV..."
        if adb connect "${FIRETV_IP}:${FIRETV_PORT}" 2>/dev/null | grep -q "connected"; then
            log_info "FireTV connected successfully"
        else
            log_warn "Could not connect to FireTV. Enable ADB debugging on your FireTV."
        fi
    fi
fi

echo ""
echo -e "${BOLD}============================================${NC}"
echo -e "${BOLD}  Installation Complete!${NC}"
echo -e "${BOLD}============================================${NC}"
echo ""
echo "  Location:    ${PROJECT_DIR}"
echo "  Source:      ${SOURCE}"
echo "  Resolution:  ${RESOLUTION}"
echo "  FPS:         ${FPS}"
if [ -n "${FIRETV_IP}" ]; then
echo "  FireTV:      ${FIRETV_IP}:${FIRETV_PORT}"
fi
echo ""
echo "  To start:"
if [ "$AUTO_START" = true ]; then
    echo -e "    cd ${PROJECT_DIR}"
    echo -e "    source .venv/bin/activate"
    if [ -n "${FIRETV_IP}" ]; then
    echo -e "    python -m emiscreen.server --source ${SOURCE} --firetv ${FIRETV_IP} --resolution ${RESOLUTION} --fps ${FPS}"
    else
    echo -e "    python -m emiscreen.server --source ${SOURCE}"
    fi
else
    echo -e "    cd ${PROJECT_DIR} && ./scripts/start.sh --source ${SOURCE} --firetv ${FIRETV_IP}"
fi
echo ""
echo "  Or use Docker:"
echo "    cd ${PROJECT_DIR} && docker compose up -d"
echo ""