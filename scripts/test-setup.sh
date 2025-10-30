#!/usr/bin/env bash
# Test script for setup-dgx-tunnel.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETUP_SCRIPT="$SCRIPT_DIR/setup-dgx-tunnel.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

passed=0
failed=0

print_test() {
  echo
  echo "=========================================="
  echo "TEST: $1"
  echo "=========================================="
}

pass() {
  echo -e "${GREEN}✓ PASS${NC}: $1"
  ((passed++))
}

fail() {
  echo -e "${RED}✗ FAIL${NC}: $1"
  ((failed++))
}

warn() {
  echo -e "${YELLOW}⚠ WARN${NC}: $1"
}

# Test 1: Script exists and is readable
print_test "Script existence and readability"
if [[ -f "$SETUP_SCRIPT" ]]; then
  pass "Script exists at $SETUP_SCRIPT"
else
  fail "Script not found at $SETUP_SCRIPT"
  exit 1
fi

if [[ -r "$SETUP_SCRIPT" ]]; then
  pass "Script is readable"
else
  fail "Script is not readable"
fi

# Test 2: Script is executable
print_test "Script permissions"
if [[ -x "$SETUP_SCRIPT" ]]; then
  pass "Script is executable"
else
  warn "Script is not executable (will be fixed)"
fi

# Test 3: Shebang is present
print_test "Script format validation"
if head -n 1 "$SETUP_SCRIPT" | grep -q '^#!/'; then
  pass "Shebang is present"
else
  fail "Shebang is missing"
fi

# Test 4: Script syntax check
print_test "Bash syntax validation"
if bash -n "$SETUP_SCRIPT" 2>/dev/null; then
  pass "Script has valid bash syntax"
else
  fail "Script has syntax errors"
  bash -n "$SETUP_SCRIPT"
fi

# Test 5: Help flag works
print_test "Help flag functionality"
if "$SETUP_SCRIPT" --help >/dev/null 2>&1; then
  pass "--help flag works"
else
  fail "--help flag failed"
fi

if "$SETUP_SCRIPT" -h >/dev/null 2>&1; then
  pass "-h flag works"
else
  fail "-h flag failed"
fi

# Test 6: Dry run with defaults
print_test "Dry run with default configuration"
if output=$("$SETUP_SCRIPT" --dry-run 2>&1); then
  pass "Dry run with defaults succeeds"
  if echo "$output" | grep -q "DRY RUN MODE"; then
    pass "Dry run output contains expected header"
  else
    fail "Dry run output missing header"
  fi

  if echo "$output" | grep -q "12000"; then
    pass "Default port LP1 (12000) present in output"
  else
    fail "Default port LP1 (12000) not found"
  fi
else
  fail "Dry run with defaults failed"
  echo "$output"
fi

# Test 7: Dry run with custom ports
print_test "Dry run with custom ports"
if output=$("$SETUP_SCRIPT" --dry-run --lp1 9000 --rp1 8000 2>&1); then
  pass "Dry run with custom ports succeeds"
  if echo "$output" | grep -q "9000"; then
    pass "Custom port LP1 (9000) present in output"
  else
    fail "Custom port LP1 (9000) not found"
  fi
else
  fail "Dry run with custom ports failed"
fi

# Test 8: Invalid mode detection
print_test "Input validation - invalid mode"
if "$SETUP_SCRIPT" --mode invalid --dry-run 2>&1 | grep -q "Error.*mode"; then
  pass "Invalid mode is rejected"
else
  fail "Invalid mode not properly rejected"
fi

# Test 9: Invalid bind address detection
print_test "Input validation - invalid bind address"
if "$SETUP_SCRIPT" --bind 192.168.1.1 --dry-run 2>&1 | grep -q "Error.*bind"; then
  pass "Invalid bind address is rejected"
else
  fail "Invalid bind address not properly rejected"
fi

# Test 10: Invalid port detection
print_test "Input validation - invalid ports"
if "$SETUP_SCRIPT" --lp1 99999 --dry-run 2>&1 | grep -q "Error.*port"; then
  pass "Invalid port (99999) is rejected"
else
  fail "Invalid port (99999) not properly rejected"
fi

if "$SETUP_SCRIPT" --lp1 -1 --dry-run 2>&1 | grep -q "Error.*port"; then
  pass "Negative port (-1) is rejected"
else
  fail "Negative port (-1) not properly rejected"
fi

# Test 11: CIDR validation
print_test "Input validation - CIDR notation"
if "$SETUP_SCRIPT" --allow-subnet "not-a-cidr" --dry-run 2>&1 | grep -q "Error.*CIDR"; then
  pass "Invalid CIDR is rejected"
else
  fail "Invalid CIDR not properly rejected"
fi

if output=$("$SETUP_SCRIPT" --allow-subnet "192.168.0.0/24" --dry-run 2>&1); then
  pass "Valid CIDR is accepted"
else
  fail "Valid CIDR was rejected"
fi

# Test 12: User mode vs system mode
print_test "Mode-specific behavior"
if output=$("$SETUP_SCRIPT" --mode user --dry-run 2>&1); then
  if echo "$output" | grep -q ".config/systemd/user"; then
    pass "User mode uses correct systemd path"
  else
    fail "User mode systemd path incorrect"
  fi
else
  fail "User mode dry run failed"
fi

# Test 13: SSH key validation
print_test "SSH key validation"
if "$SETUP_SCRIPT" --ssh-key /nonexistent/key --dry-run 2>&1 | grep -q "Error.*SSH key"; then
  pass "Nonexistent SSH key is rejected"
else
  fail "Nonexistent SSH key not properly rejected"
fi

# Test 14: Uninstall dry run
print_test "Uninstall functionality"
if output=$("$SETUP_SCRIPT" --uninstall --dry-run --mode user 2>&1); then
  if echo "$output" | grep -q "Would stop and disable"; then
    pass "Uninstall dry run shows expected actions"
  else
    fail "Uninstall dry run output unexpected"
  fi
else
  fail "Uninstall dry run failed"
fi

# Test 15: Required command detection
print_test "Dependency checking"
# This test is hard to do without actually removing ssh, so we'll check the error message exists
if grep -q "ssh command not found" "$SETUP_SCRIPT"; then
  pass "Script checks for ssh command"
else
  fail "Script doesn't check for ssh command"
fi

# Test 16: Systemd unit generation
print_test "Systemd unit generation"
if output=$("$SETUP_SCRIPT" --mode system --dry-run 2>&1); then
  if echo "$output" | grep -q "\[Unit\]"; then
    pass "Systemd unit structure is generated"
  else
    fail "Systemd unit structure missing"
  fi

  if echo "$output" | grep -q "ExecStart="; then
    pass "ExecStart directive is present"
  else
    fail "ExecStart directive missing"
  fi

  if echo "$output" | grep -q "Restart=always"; then
    pass "Auto-restart is configured"
  else
    fail "Auto-restart not configured"
  fi
else
  fail "Systemd unit generation failed"
fi

# Test 17: SSH command construction
print_test "SSH command construction"
if output=$("$SETUP_SCRIPT" --dry-run 2>&1); then
  if echo "$output" | grep -q "ExitOnForwardFailure=yes"; then
    pass "SSH hardening option present"
  else
    fail "SSH hardening option missing"
  fi

  if echo "$output" | grep -q "ServerAliveInterval"; then
    pass "Keep-alive option present"
  else
    fail "Keep-alive option missing"
  fi

  if echo "$output" | grep -q -- "-L"; then
    pass "Port forwarding options present"
  else
    fail "Port forwarding options missing"
  fi
else
  fail "SSH command construction failed"
fi

# Test 18: Token handling
print_test "Jupyter token handling"
if output=$("$SETUP_SCRIPT" --token "test-token-123" --dry-run 2>&1); then
  pass "Token parameter is accepted"
else
  fail "Token parameter failed"
fi

# Test 19: Unknown argument handling
print_test "Unknown argument handling"
if "$SETUP_SCRIPT" --nonexistent-flag 2>&1 | grep -q "Unknown"; then
  pass "Unknown arguments are rejected"
else
  fail "Unknown arguments not properly rejected"
fi

# Test 20: Multiple port forwards
print_test "Multiple port forward configuration"
if output=$("$SETUP_SCRIPT" --dry-run --lp1 10001 --rp1 20001 --lp2 10002 --rp2 20002 --lp3 10003 --rp3 20003 2>&1); then
  pass "Multiple custom port forwards accepted"

  count=$(echo "$output" | grep -c "10001\|10002\|10003" || true)
  if [[ $count -ge 3 ]]; then
    pass "All three custom local ports present in output"
  else
    fail "Not all custom ports found in output (found $count/3)"
  fi
else
  fail "Multiple port forwards configuration failed"
fi

# Summary
echo
echo "=========================================="
echo "TEST SUMMARY"
echo "=========================================="
echo -e "${GREEN}Passed: $passed${NC}"
if [[ $failed -gt 0 ]]; then
  echo -e "${RED}Failed: $failed${NC}"
else
  echo -e "${GREEN}Failed: 0${NC}"
fi
echo "Total: $((passed + failed))"
echo

if [[ $failed -eq 0 ]]; then
  echo -e "${GREEN}All tests passed!${NC}"
  exit 0
else
  echo -e "${RED}Some tests failed.${NC}"
  exit 1
fi
