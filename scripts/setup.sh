#!/bin/bash
# Emiscreen - Setup Script for Ubuntu/Debian
# Installs all dependencies required to run the Emiscreen server

set -e

echo "============================================"
echo "  Emiscreen - Setup Script"
echo "============================================"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check if running as root for system packages
NEEDS_SUDO=false
if [ "$EUID" -ne 0 ]; then
    NEEDS_SUDO=true
fi

SUDO=""
if [ "$NEEDS_SUDO" = true ]; then
    SUDO="sudo"
fi

# 1. System dependencies
log_info "Installing system dependencies..."

# Check if apt is available
if command -v apt &> /dev/null; then
    $SUDO apt update -qq
    $SUDO apt install -y -qq \
        ffmpeg \
        xdotool \
        x11-utils \
        xvfb \
        adb \
        openssl \
        python3 \
        python3-pip \
        python3-venv \
        2>/dev/null || true
    log_info "System packages installed"
elif command -v dnf &> /dev/null; then
    $SUDO dnf install -y \
        ffmpeg \
        xdotool \
        xorg-x11-utils \
        xorg-x11-server-Xvfb \
        android-tools \
        openssl \
        python3 \
        python3-pip \
        python3-virtualenv
    log_info "System packages installed (dnf)"
else
    log_warn "Package manager not detected. Please install manually:"
    log_warn "  ffmpeg, xdotool, xvfb, adb, openssl, python3, python3-pip"
fi

# 2. Python virtual environment
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VENV_DIR="${PROJECT_DIR}/.venv"

if [ ! -d "${VENV_DIR}" ]; then
    log_info "Creating Python virtual environment..."
    python3 -m venv "${VENV_DIR}"
fi

# Activate venv
source "${VENV_DIR}/bin/activate"

# 3. Python dependencies
log_info "Installing Python dependencies..."
pip install --upgrade pip -q
pip install -r "${PROJECT_DIR}/requirements.txt" -q
log_info "Python dependencies installed"

# 4. Generate SSL certificates
if [ ! -f "${PROJECT_DIR}/certs/cert.pem" ] || [ ! -f "${PROJECT_DIR}/certs/key.pem" ]; then
    log_info "Generating SSL certificates..."
    bash "${PROJECT_DIR}/scripts/generate-certs.sh"
fi

# 5. Verify installation
log_info "Verifying installation..."

ERRORS=0

# Check ffmpeg
if command -v ffmpeg &> /dev/null; then
    FFMPEG_VER=$(ffmpeg -version 2>/dev/null | head -1)
    log_info "  ffmpeg: ${FFMPEG_VER}"
else
    log_error "  ffmpeg: NOT FOUND"
    ERRORS=$((ERRORS + 1))
fi

# Check xdotool
if command -v xdotool &> /dev/null; then
    log_info "  xdotool: $(xdotool --version 2>/dev/null || echo 'installed')"
else
    log_warn "  xdotool: NOT FOUND (input relay will be limited)"
fi

# Check adb
if command -v adb &> /dev/null; then
    log_info "  adb: $(adb version 2>/dev/null | head -1)"
else
    log_warn "  adb: NOT FOUND (FireTV control disabled)"
fi

# Check Python packages
python3 -c "import aiortc; print(f'  aiortc: {aiortc.__version__}')" 2>/dev/null || {
    log_error "  aiortc: NOT INSTALLED"
    ERRORS=$((ERRORS + 1))
}

echo ""
if [ $ERRORS -eq 0 ]; then
    log_info "============================================"
    log_info "  Setup complete! Emiscreen is ready."
    log_info "============================================"
    echo ""
    echo "Next steps:"
    echo "  1. Connect FireTV: ./scripts/connect-firetv.sh <FIRETV_IP>"
    echo "  2. Start server:   ./scripts/start.sh --source ubuntu-desktop --firetv <FIRETV_IP>"
    echo ""
else
    log_error "Setup completed with ${ERRORS} error(s). Please fix them before running."
    exit 1
fi
