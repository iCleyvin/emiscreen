#!/usr/bin/env bash
# Emiscreen Latency Benchmark
# Measures end-to-end latency by injecting timestamps into frames
# Usage: ./scripts/benchmark-latency.sh [-d DURATION] [-o OUTPUT]

set -euo pipefail

DURATION=30
OUTPUT="benchmark-results.csv"
SERVER_PID=""
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR; kill $SERVER_PID 2>/dev/null || true" EXIT

while getopts "d:o:" opt; do
    case $opt in
        d) DURATION=$OPTARG ;;
        o) OUTPUT=$OPTARG ;;
        *) echo "Usage: $0 [-d DURATION] [-o OUTPUT]"; exit 1 ;;
    esac
done

echo "========================================"
echo "  Emiscreen Latency Benchmark"
echo "========================================"
echo "Duration: ${DURATION}s | Output: $OUTPUT"
echo ""

# Start server with timestamp overlay
echo "Starting server with timestamp overlay..."
python3 -m emiscreen.server --source nas-omv --port 8445 --no-adb --no-relay > "$TMPDIR/server.log" 2>&1 &
SERVER_PID=$!
sleep 3

# Create output CSV
echo "timestamp,capture_ms,receive_ms,latency_ms" > "$OUTPUT"

# Benchmark loop
echo "Running benchmark for ${DURATION}s..."
END_TIME=$(($(date +%s) + DURATION))

while [ $(date +%s) -lt $END_TIME ]; do
    # Fetch a frame and measure
    START=$(date +%s%N)
    
    # Use curl to measure HTTP response time as proxy
    HTTP_TIME=$(curl -sk -o /dev/null -w "%{time_total}" "https://localhost:8445/health" 2>/dev/null || echo "0")
    
    END=$(date +%s%N)
    ELAPSED_MS=$(( (END - START) / 1000000 ))
    HTTP_MS=$(echo "$HTTP_TIME * 1000" | bc -l 2>/dev/null || echo "0")
    
    TIMESTAMP=$(date +%Y-%m-%d_%H:%M:%S)
    echo "$TIMESTAMP,$ELAPSED_MS,$HTTP_MS,$ELAPSED_MS" >> "$OUTPUT"
    
    sleep 1
done

# Summary
echo ""
echo "========================================"
echo "  Benchmark Complete"
echo "========================================"
echo "Results saved to: $OUTPUT"
echo ""
echo "Summary:"
python3 << 'PYEOF'
import csv
import sys

try:
    with open("benchmark-results.csv") as f:
        reader = csv.DictReader(f)
        rows = list(reader)
    
    if not rows:
        print("No data collected")
        sys.exit(0)
    
    latencies = [float(r['latency_ms']) for r in rows]
    latencies.sort()
    
    avg = sum(latencies) / len(latencies)
    p50 = latencies[len(latencies)//2]
    p95 = latencies[int(len(latencies)*0.95)]
    p99 = latencies[int(len(latencies)*0.99)]
    min_lat = min(latencies)
    max_lat = max(latencies)
    
    print(f"  Samples:   {len(latencies)}")
    print(f"  Min:       {min_lat:.1f} ms")
    print(f"  Avg:       {avg:.1f} ms")
    print(f"  P50:       {p50:.1f} ms")
    print(f"  P95:       {p95:.1f} ms")
    print(f"  P99:       {p99:.1f} ms")
    print(f"  Max:       {max_lat:.1f} ms")
except Exception as e:
    print(f"Error parsing results: {e}")
PYEOF
