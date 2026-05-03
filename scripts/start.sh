#!/bin/bash
# Emiscreen - Start Server Script
# Usage: ./start.sh [--source SOURCE] [--firetv IP] [--resolution RES] [--fps N]

set -e

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VENV_DIR="${PROJECT_DIR}/.venv"

# Activate virtual environment
if [ -d "${VENV_DIR}" ]; then
    source "${VENV_DIR}/bin/activate"
else
    echo "Virtual environment not found. Run ./scripts/setup.sh first."
    exit 1
fi

# Generate certs if needed
if [ ! -f "${PROJECT_DIR}/certs/cert.pem" ]; then
    bash "${PROJECT_DIR}/scripts/generate-certs.sh"
fi

# Parse arguments
SOURCE="ubuntu-desktop"
FIRETV_IP=""
RESOLUTION=""
FPS=""
VERBOSE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --source|-s)
            SOURCE="$2"
            shift 2
            ;;
        --firetv|-f)
            FIRETV_IP="$2"
            shift 2
            ;;
        --resolution|-r)
            RESOLUTION="$2"
            shift 2
            ;;
        --fps)
            FPS="$2"
            shift 2
            ;;
        --verbose|-v)
            VERBOSE="--verbose"
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --source, -s SOURCE    Capture source (ubuntu-desktop, windows-pc, nas-omv)"
            echo "  --firetv, -f IP        FireTV IP address for ADB control"
            echo "  --resolution, -r RES   Capture resolution (e.g., 1920x1080)"
            echo "  --fps N                Capture frame rate"
            echo "  --verbose, -v          Enable debug logging"
            echo "  --help, -h             Show this help"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Build command
CMD="python -m emiscreen.server --source ${SOURCE}"

if [ -n "${FIRETV_IP}" ]; then
    CMD="${CMD} --firetv ${FIRETV_IP}"
fi

if [ -n "${RESOLUTION}" ]; then
    CMD="${CMD} --resolution ${RESOLUTION}"
fi

if [ -n "${FPS}" ]; then
    CMD="${CMD} --fps ${FPS}"
fi

if [ -n "${VERBOSE}" ]; then
    CMD="${CMD} --verbose"
fi

echo "============================================"
echo "  Emiscreen - Starting Server"
echo "============================================"
echo "  Source:     ${SOURCE}"
echo "  FireTV:     ${FIRETV_IP:-disabled}"
echo "  Resolution: ${RESOLUTION:-default}"
echo "  FPS:        ${FPS:-default}"
echo "============================================"
echo ""

# Run server
exec ${CMD}
