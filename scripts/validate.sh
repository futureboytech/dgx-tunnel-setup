#!/usr/bin/env bash
# Quick validation script for setup-dgx-tunnel.sh
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

passed=0
failed=0

pass() {
  echo "✓ $1"
  ((passed++))
}

fail() {
  echo "✗ FAILED: $1"
  ((failed++))
}

echo "Running validation checks..."
echo

# Test 1: Help
pass "Testing --help flag"
scripts/setup-dgx-tunnel.sh --help > /dev/null

# Test 2: Dry run
pass "Testing --dry-run with default config"
scripts/setup-dgx-tunnel.sh --dry-run --mode user > /dev/null

# Test 3: Custom ports
pass "Testing custom ports"
scripts/setup-dgx-tunnel.sh --dry-run --mode user --lp1 9000 --rp1 8000 > /dev/null

# Test 4: Invalid mode
if scripts/setup-dgx-tunnel.sh --mode invalid --dry-run &>/dev/null; then
  fail "Invalid mode detection"
else
  pass "Invalid mode detection"
fi

# Test 5: Invalid bind
if scripts/setup-dgx-tunnel.sh --bind 10.0.0.1 --dry-run &>/dev/null; then
  fail "Invalid bind detection"
else
  pass "Invalid bind detection"
fi

# Test 6: Invalid port
if scripts/setup-dgx-tunnel.sh --lp1 99999 --dry-run &>/dev/null; then
  fail "Invalid port detection"
else
  pass "Invalid port detection"
fi

# Test 7: CIDR validation - invalid
if scripts/setup-dgx-tunnel.sh --allow-subnet "invalid" --dry-run &>/dev/null; then
  fail "Invalid CIDR detection"
else
  pass "Invalid CIDR detection"
fi

# Test 7b: CIDR validation - valid
pass "Valid CIDR acceptance"
scripts/setup-dgx-tunnel.sh --allow-subnet "192.168.0.0/24" --dry-run --mode user > /dev/null

# Test 8: SSH key validation - nonexistent
if scripts/setup-dgx-tunnel.sh --ssh-key /nonexistent --dry-run &>/dev/null; then
  fail "Nonexistent SSH key detection"
else
  pass "Nonexistent SSH key detection"
fi

# Test 9: Uninstall dry-run
pass "Testing --uninstall with dry-run"
scripts/setup-dgx-tunnel.sh --uninstall --dry-run --mode user > /dev/null

# Test 10: Token parameter
pass "Testing token parameter"
scripts/setup-dgx-tunnel.sh --token "test123" --dry-run --mode user > /dev/null

# Test 11: Both modes work
pass "Testing system mode (dry-run)"
scripts/setup-dgx-tunnel.sh --dry-run --mode system > /dev/null

# Test 12: Both bind addresses work
pass "Testing bind to 127.0.0.1"
scripts/setup-dgx-tunnel.sh --dry-run --mode user --bind 127.0.0.1 > /dev/null

echo
echo "=========================================="
echo "Results: $passed passed, $failed failed"
echo "=========================================="

if [[ $failed -eq 0 ]]; then
  echo "All validation checks passed!"
  exit 0
else
  echo "Some checks failed!"
  exit 1
fi
