#!/usr/bin/env bash
# Emiscreen - Sync to cleyvinserv (bash)
# Usage: ./scripts/sync-to-server.sh

set -e

SERVER="cleyvinserv"
REMOTE_PATH="/mnt/datos/dev/emiscreen"
NO_TESTS=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --server) SERVER="$2"; shift 2 ;;
        --path) REMOTE_PATH="$2"; shift 2 ;;
        --no-tests) NO_TESTS=true; shift ;;
        *) shift ;;
    esac
done

echo "=== Emiscreen Sync to ${SERVER} ==="
echo "Remote path: ${REMOTE_PATH}"
echo ""

# 1. Sync code
echo "[1/4] Syncing code..."
if command -v rsync &> /dev/null; then
    rsync -avz --delete \
        --exclude='.venv' --exclude='__pycache__' --exclude='.git' \
        --exclude='*.pyc' --exclude='*.pyo' --exclude='.pytest_cache' \
        --exclude='firetv-app/.gradle' --exclude='firetv-app/app/build' \
        --exclude='firetv-app/app/.cxx' --exclude='*.apk' \
        ./ "${SERVER}:${REMOTE_PATH}/"
else
    echo "rsync not found, using scp fallback..."
    ssh "${SERVER}" "mkdir -p ${REMOTE_PATH} && rm -rf ${REMOTE_PATH}/emiscreen ${REMOTE_PATH}/scripts ${REMOTE_PATH}/tests ${REMOTE_PATH}/docs ${REMOTE_PATH}/firetv-app ${REMOTE_PATH}/*.md ${REMOTE_PATH}/*.txt ${REMOTE_PATH}/*.toml ${REMOTE_PATH}/*.yml ${REMOTE_PATH}/*.py ${REMOTE_PATH}/*.sh ${REMOTE_PATH}/*.ps1"
    scp -r -C ./emiscreen ./scripts ./tests ./docs ./firetv-app ./*.md ./*.txt ./*.toml ./*.yml ./*.py ./*.sh ./*.ps1 "${SERVER}:${REMOTE_PATH}/"
fi
echo "  Sync complete."

# 2. Ensure venv and deps
echo ""
echo "[2/4] Ensuring Python environment..."
ssh "${SERVER}" "cd ${REMOTE_PATH} && if [ ! -d .venv ]; then python3 -m venv .venv; fi && source .venv/bin/activate && pip install -q -r requirements.txt"
echo "  Environment ready."

# 3. Run tests
if [ "$NO_TESTS" = false ]; then
    echo ""
    echo "[3/4] Running tests..."
    ssh "${SERVER}" "cd ${REMOTE_PATH} && source .venv/bin/activate && python -m pytest tests/ -v"
fi

# 4. Verify imports
echo ""
echo "[4/4] Verifying server imports..."
ssh "${SERVER}" "cd ${REMOTE_PATH} && source .venv/bin/activate && python -c 'from emiscreen.server import EmiscreenServer; from emiscreen.capture.base import CaptureSource; print(\"Imports OK\")'"

echo ""
echo "============================================"
echo "  Sync complete!"
echo "============================================"
echo ""
echo "Next steps:"
echo "  Build APK:   ./scripts/build-apk-remote.sh"
echo "  Run server:  ssh ${SERVER} 'cd ${REMOTE_PATH} && source .venv/bin/activate && python -m emiscreen.server --source ubuntu-desktop'"
