#!/bin/bash
# Runs every automated test. Fails if any check fails or any script error is printed.
set -uo pipefail
G="${GODOT:-godot}"
cd "$(dirname "$0")/.."
out=$("$G" --headless --path . --script tests/test_core.gd 2>&1); echo "$out" | grep -E "Core tests|FAIL"
echo "$out" | grep -q "0 failed" || exit 1
out=$("$G" --headless --path . tests/ui_flows.tscn 2>&1); echo "$out" | grep -E "UI flows|FAIL|SCRIPT ERROR"
echo "$out" | grep -q "SCRIPT ERROR" && exit 1
echo "$out" | grep -q ", 0 failed" || exit 1
echo "All tests passed"
