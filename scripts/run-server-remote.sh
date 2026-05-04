#!/usr/bin/env bash
# Emiscreen - Run server remotely on cleyvinserv
# Usage: ./scripts/run-server-remote.sh [options...]
# All extra arguments are passed to emiscreen.server

set -e

SERVER="cleyvinserv"
REMOTE_PATH="/mnt/datos/dev/emiscreen"
SERVER_ARGS="$*"

while [[ $# -gt 0 ]]; do
    case $1 in
        --server) SERVER="$2"; shift 2 ;;
        --path) REMOTE_PATH="$2"; shift 2 ;;
        *) shift ;;
    esac
done

# Re-parse remaining args after consuming ours
# Actually we consumed them above. Let's just pass everything.
# Simpler approach: just pass through.

echo "=== Emiscreen Remote Server Start ==="
echo "Server: ${SERVER}"
echo ""

# Sync first
echo "[1/2] Syncing code..."
"$(dirname "$0")/sync-to-server.sh" --server "${SERVER}" --path "${REMOTE_PATH}" --no-tests

# Build arg string
if [ -z "$SERVER_ARGS" ]; then
    SERVER_ARGS="--source ubuntu-desktop"
fi

echo ""
echo "[2/2] Starting server..."
echo "  Press Ctrl+C to stop (server will keep running in background)"
echo ""

ssh -t "${SERVER}" "cd ${REMOTE_PATH} && source .venv/bin/activate && export EMISCREEN_HOST=0.0.0.0 && python -m emiscreen.server ${SERVER_ARGS}"

echo ""
echo "Server session ended."
