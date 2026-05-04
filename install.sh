#!/bin/bash
# Emiscreen - One-Line Installer (Linux/macOS/WSL)
# Usage: curl -fsSL https://raw.githubusercontent.com/iCleyvin/emiscreen/main/install.sh | bash
# After install, just type: emiscreen

set -e

INSTALLER_VERSION="2.0.0"
GITHUB_REPO="iCleyvin/emiscreen"
GITHUB_URL="https://github.com/${GITHUB_REPO}"
RAW_URL="https://raw.githubusercontent.com/${GITHUB_REPO}/main"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_step() { echo -e "${CYAN}[${1}]${NC} $2"; }

# Arguments
SOURCE="ubuntu-desktop"
FIRETV_IP=""
RESOLUTION="1920x1080"
FPS="30"
SKIP_CONFIRM=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --source|-s) SOURCE="$2"; shift 2 ;;
        --firetv|-f) FIRETV_IP="$2"; shift 2 ;;
        --resolution|-r) RESOLUTION="$2"; shift 2 ;;
        --fps) FPS="$2"; shift 2 ;;
        --yes|-y) SKIP_CONFIRM=true; shift ;;
        --help|-h)
            echo "Emiscreen One-Line Installer v${INSTALLER_VERSION}"
            echo ""
            echo "Usage: curl -fsSL ${RAW_URL}/install.sh | bash [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --source, -s SOURCE   Capture source (ubuntu-desktop, nas-omv)"
            echo "  --firetv, -f IP      FireTV IP address"
            echo "  --resolution, -r RES  Resolution (default: 1920x1080)"
            echo "  --fps N               Frame rate (default: 30)"
            echo "  --yes, -y             Skip confirmation"
            echo ""
            echo "After install, run from ANY terminal:"
            echo "  emiscreen"
            echo "  emiscreen --firetv 192.168.1.100"
            exit 0
            ;;
        *) shift ;;
    esac
done

echo -e "${BOLD}"
echo "============================================"
echo "  Emiscreen Installer v${INSTALLER_VERSION}"
echo "  Remote Display via WebRTC"
echo "============================================"
echo -e "${NC}"

# Detect OS
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if grep -q "Microsoft" /proc/version 2>/dev/null; then echo "wsl"
        elif [ -f /etc/debian_version ]; then echo "debian"
        elif [ -f /etc/redhat-release ]; then echo "rhel"
        else echo "linux"; fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then echo "macos"
    else echo "unknown"; fi
}

OS_TYPE=$(detect_os)
log_info "OS: ${OS_TYPE}"

SUDO=""
if [ "$EUID" -ne 0 ] && [ "$OS_TYPE" != "wsl" ]; then
    SUDO="sudo"
fi

# 1. Install dependencies
log_step "1/4" "Installing dependencies..."

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
    debian|linux) install_apt ;;
    rhel) install_yum ;;
    macos) install_brew ;;
    wsl) log_warn "WSL detected - install deps manually if needed" ;;
esac

# 2. Clone/update repo
log_step "2/4" "Downloading Emiscreen..."

PROJECT_DIR="${HOME}/emiscreen"

if [ -d "${PROJECT_DIR}" ]; then
    log_info "Updating existing installation..."
    cd "${PROJECT_DIR}" && git pull 2>/dev/null || true
else
    git clone --depth 1 https://github.com/iCleyvin/emiscreen.git "${PROJECT_DIR}"
fi

log_info "Installed to: ${PROJECT_DIR}"

# 3. Setup Python
log_step "3/4" "Setting up Python environment..."

cd "${PROJECT_DIR}"

if [ ! -d ".venv" ]; then
    python3 -m venv .venv
fi

source .venv/bin/activate
pip install --upgrade pip -q
pip install -r requirements.txt -q

# 4. Create launcher
log_step "4/4" "Creating launcher..."

# Create shell wrapper
cat > emiscreen.sh << 'WRAPPER'
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/.venv/bin/activate"
exec python -m emiscreen.server "$@"
WRAPPER

chmod +x emiscreen.sh

# Install to ~/.local/bin for user-level access
LOCAL_BIN="${HOME}/.local/bin"
mkdir -p "${LOCAL_BIN}"

# Remove old symlink if exists
rm -f "${LOCAL_BIN}/emiscreen" 2>/dev/null || true

# Create symlink
ln -s "${PROJECT_DIR}/emiscreen.sh" "${LOCAL_BIN}/emiscreen"

# Also make it executable from project dir
chmod +x "${PROJECT_DIR}/emiscreen.sh"

# Add to PATH in shellrc if not already there
SHELL_RC="${HOME}/.bashrc"
if [ -f "${HOME}/.zshrc" ]; then SHELL_RC="${HOME}/.zshrc"; fi

if ! grep -q ".local/bin" "${SHELL_RC}" 2>/dev/null; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "${SHELL_RC}"
fi

# SSL certificates
mkdir -p certs
if [ ! -f "certs/cert.pem" ]; then
    openssl req -new -x509 -keyout certs/key.pem -out certs/cert.pem \
        -days 3650 -nodes -subj "/CN=emiscreen.local" \
        -addext "subjectAltName=DNS:emiscreen.local,DNS:localhost,IP:127.0.0.1" 2>/dev/null || \
    openssl req -new -x509 -keyout certs/key.pem -out certs/cert.pem \
        -days 3650 -nodes -subj "/CN=emiscreen.local" 2>/dev/null || true
fi

# Environment file
cat > .env << EOF
EMISCREEN_PORT=8445
EMISCREEN_SOURCE=${SOURCE}
EMISCREEN_RESOLUTION=${RESOLUTION}
EMISCREEN_FPS=${FPS}
EMISCREEN_FIRETV_IP=${FIRETV_IP}
EOF

# Test FireTV connection
if [ -n "${FIRETV_IP}" ] && command -v adb &> /dev/null; then
    if adb connect "${FIRETV_IP}:5555" 2>/dev/null | grep -q "connected"; then
        log_info "FireTV connected!"
    fi
fi

echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  Installation Complete!${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo -e "  Location: ${PROJECT_DIR}"
echo ""
echo -e "  ${BOLD}Open a NEW terminal and run:${NC}"
echo -e "    ${GREEN}emiscreen${NC}"
echo ""
if [ -n "${FIRETV_IP}" ]; then
echo -e "    ${GREEN}emiscreen --firetv ${FIRETV_IP}${NC}"
fi
echo ""
echo -e "  Then open: ${BOLD}https://localhost:8445${NC} in your browser"
echo ""