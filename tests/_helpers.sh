#!/usr/bin/env bash
# Shared assertion helpers for the neuron test suite.
#
# Sourced by tests/test-*.sh. Not a test itself (the `_` prefix keeps it out
# of the `tests/test-*.sh` glob that `make test` runs).
#
# Defines: pass / fail counters and assert_match / assert_no_match.
# Each test file is responsible for the final summary + exit status.

pass=0
fail=0

# assert_match <description> <pattern> <output>
assert_match() {
    if printf '%s\n' "$3" | grep -qF "$2"; then
        echo "  OK   $1"
        pass=$((pass + 1))
    else
        echo "  FAIL $1 (expected to find: $2)"
        fail=$((fail + 1))
    fi
}

# assert_no_match <description> <pattern> <output>
assert_no_match() {
    if printf '%s\n' "$3" | grep -qF "$2"; then
        echo "  FAIL $1 (unexpectedly found: $2)"
        fail=$((fail + 1))
    else
        echo "  OK   $1"
        pass=$((pass + 1))
    fi
}
