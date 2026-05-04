#!/usr/bin/env bash
# Emiscreen Smoke Check - Linux/macOS
# Usage: ./scripts/smoke-check.sh [-p PORT] [-t TIMEOUT] [-s SOURCE]

set -euo pipefail

PORT=8445
TIMEOUT=60
SOURCE="nas-omv"  # Use virtual display for headless testing

while getopts "p:t:s:" opt; do
    case $opt in
        p) PORT=$OPTARG ;;
        t) TIMEOUT=$OPTARG ;;
        s) SOURCE=$OPTARG ;;
        *) echo "Usage: $0 [-p PORT] [-t TIMEOUT] [-s SOURCE]"; exit 1 ;;
    esac
done

PASS=0
FAIL=0

pass() { echo "[PASS] $1"; PASS=$((PASS+1)); }
fail() { echo "[FAIL] $1"; FAIL=$((FAIL+1)); }

TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR; pkill -f 'emiscreen.server' || true" EXIT

echo "========================================"
echo "  Emiscreen Smoke Check"
echo "========================================"
echo "Port: $PORT | Timeout: ${TIMEOUT}s | Source: $SOURCE"
echo ""

# Step 1: Start server
echo "Step 1: Starting server..."
python3 -m emiscreen.server --source "$SOURCE" --port "$PORT" --no-adb --no-relay > "$TMPDIR/server.log" 2>&1 &
SERVER_PID=$!
echo "Server PID: $SERVER_PID"
sleep 3

# Step 2: Check HTTPS health
echo ""
echo "Step 2: Checking HTTPS endpoint..."
for i in $(seq 1 30); do
    if curl -sk "https://localhost:$PORT/health" > "$TMPDIR/health.json" 2>/dev/null; then
        pass "HTTPS /health responds"
        break
    fi
    sleep 1
done

if [ ! -f "$TMPDIR/health.json" ]; then
    fail "HTTPS /health did not respond"
    cat "$TMPDIR/server.log" | tail -20
    exit 1
fi

# Step 3: Verify health JSON
if [ "$(cat "$TMPDIR/health.json" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("status"))')" = "healthy" ]; then
    pass "Health status is 'healthy'"
else
    fail "Health status unexpected"
fi

# Step 4: Check viewer page
if curl -sk "https://localhost:$PORT/" | grep -q "viewer"; then
    pass "Viewer page contains 'viewer'"
else
    fail "Viewer page missing content"
fi

# Step 5: Check status endpoint
if curl -sk "https://localhost:$PORT/status" > "$TMPDIR/status.json" 2>/dev/null; then
    pass "Status endpoint responds"
else
    fail "Status endpoint failed"
fi

# Summary
echo ""
echo "========================================"
TOTAL=$((PASS+FAIL))
if [ $FAIL -eq 0 ]; then
    echo "  SMOKE CHECK PASSED ($PASS/$TOTAL)"
    exit 0
else
    echo "  SMOKE CHECK FAILED ($PASS passed, $FAIL failed)"
    exit 1
fi
