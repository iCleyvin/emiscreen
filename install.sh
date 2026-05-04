#!/bin/bash
# Emiscreen - One-Line Installer (Linux/macOS/WSL)
# Usage: curl -fsSL https://raw.githubusercontent.com/iCleyvin/emiscreen/main/install.sh | bash

set -e

VERSION="3.0.0"
REPO="iCleyvin/emiscreen"
INSTALL_DIR="${HOME}/.local/emiscreen"
BIN_DIR="${HOME}/.local/bin"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Parse args
SOURCE="ubuntu-desktop"
FIRETV_IP=""
RESOLUTION="1920x1080"
FPS="30"

while [[ $# -gt 0 ]]; do
    case $1 in
        --source|-s) SOURCE="$2"; shift 2 ;;
        --firetv|-f) FIRETV_IP="$2"; shift 2 ;;
        --resolution|-r) RESOLUTION="$2"; shift 2 ;;
        --fps) FPS="$2"; shift 2 ;;
        --help|-h)
            echo "Emiscreen Installer v$VERSION"
            echo "Usage: curl -fsSL .../install.sh | bash"
            echo "Options: --source, --firetv, --resolution, --fps"
            exit 0 ;;
        *) shift ;;
    esac
done

echo -e "${BOLD}=== Emiscreen v$VERSION ===${NC}"

# =============================================================================
# CLEANUP: Remove old installations
# =============================================================================
echo -e "${YELLOW}[Cleanup] Removing old installations...${NC}"

rm -rf "${HOME}/emiscreen" 2>/dev/null || true
rm -rf "${HOME}/.local/emiscreen" 2>/dev/null || true
rm -f "${HOME}/.local/bin/emiscreen" 2>/dev/null || true

# Remove old PATH additions from shell configs
for rc in .bashrc .zshrc .profile; do
    if [ -f "${HOME}/$rc" ]; then
        sed -i '/emiscreen/d' "${HOME}/$rc" 2>/dev/null || true
    fi
done

echo -e "  Old artifacts cleaned"

# =============================================================================
# INSTALL: Fresh installation
# =============================================================================
echo -e "${YELLOW}[Install] Downloading Emiscreen...${NC}"

mkdir -p "${INSTALL_DIR}"
mkdir -p "${BIN_DIR}"

# Download and extract
cd /tmp
rm -rf emiscreen-main emiscreen_main.zip 2>/dev/null || true

curl -fsSL "https://github.com/${REPO}/archive/refs/heads/main.zip" -o emiscreen_main.zip
unzip -q emiscreen_main.zip
mv emiscreen-main/* "${INSTALL_DIR}/"
rm -rf emiscreen-main emiscreen_main.zip

echo -e "  ${GREEN}Installed to: ${INSTALL_DIR}${NC}"

# =============================================================================
# DEPENDENCIES
# =============================================================================
echo -e "${YELLOW}[Dependencies] Installing...${NC}"

SUDO=""
if [ "$EUID" -ne 0 ]; then
    SUDO="sudo"
fi

if command -v apt &> /dev/null; then
    $SUDO apt update -qq
    $SUDO apt install -y -qq ffmpeg xdotool x11-utils xvfb openssl python3 python3-pip python3-venv curl 2>/dev/null || true
elif command -v dnf &> /dev/null; then
    $SUDO dnf install -y ffmpeg xdotool xorg-x11-utils xorg-x11-server-Xvfb openssl python3 python3-pip curl 2>/dev/null || true
elif command -v brew &> /dev/null; then
    brew install ffmpeg python@3.12 2>/dev/null || true
fi

# =============================================================================
# PYTHON SETUP
# =============================================================================
echo -e "${YELLOW}[Python] Setting up...${NC}"

cd "${INSTALL_DIR}"

if [ ! -d ".venv" ]; then
    python3 -m venv .venv
fi

source .venv/bin/activate
pip install --upgrade pip -q
pip install -r requirements.txt -q

echo -e "  ${GREEN}Python environment ready${NC}"

# =============================================================================
# SSL CERTIFICATES
# =============================================================================
echo -e "${YELLOW}[SSL] Certificates...${NC}"
echo -e "  ${GREEN}Will be auto-generated on first server start (includes LAN IP)${NC}"

# =============================================================================
# CREATE LAUNCHER
# =============================================================================
echo -e "${YELLOW}[Launcher] Creating...${NC}"

# Create launcher script
cat > "${INSTALL_DIR}/emiscreen.sh" << 'LAUNCHER'
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/.venv/bin/activate"
exec python -m emiscreen.server "$@"
LAUNCHER

chmod +x "${INSTALL_DIR}/emiscreen.sh"

# Symlink to ~/.local/bin
rm -f "${BIN_DIR}/emiscreen" 2>/dev/null || true
ln -s "${INSTALL_DIR}/emiscreen.sh" "${BIN_DIR}/emiscreen"

# Add to PATH in shell rc
SHELL_RC="${HOME}/.bashrc"
[ -f "${HOME}/.zshrc" ] && SHELL_RC="${HOME}/.zshrc"

if ! grep -q "\.local/bin" "${SHELL_RC}" 2>/dev/null; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "${SHELL_RC}"
fi

echo -e "  ${GREEN}Command 'emiscreen' available${NC}"

# =============================================================================
# ENVIRONMENT CONFIG
# =============================================================================
cat > "${INSTALL_DIR}/.env" << EOF
EMISCREEN_PORT=8445
EMISCREEN_SOURCE=${SOURCE}
EMISCREEN_RESOLUTION=${RESOLUTION}
EMISCREEN_FPS=${FPS}
EMISCREEN_FIRETV_IP=${FIRETV_IP}
EOF

# Test FireTV if provided
if [ -n "${FIRETV_IP}" ] && command -v adb &> /dev/null; then
    echo -e "${YELLOW}[FireTV] Testing connection...${NC}"
    if adb connect "${FIRETV_IP}:5555" 2>/dev/null | grep -q "connected"; then
        echo -e "  ${GREEN}Connected!${NC}"
    fi
fi

# =============================================================================
# DONE
# =============================================================================
echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  Emiscreen installed successfully!${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo -e "  Location: ${INSTALL_DIR}"
echo ""
echo -e "  ${BOLD}Open a NEW terminal and run:${NC}"
echo -e "    ${GREEN}emiscreen${NC}"
if [ -n "${FIRETV_IP}" ]; then
echo -e "    ${GREEN}emiscreen --firetv ${FIRETV_IP}${NC}"
fi
echo ""
echo -e "  Then open: ${BOLD}https://localhost:8445${NC} in your browser"
echo ""