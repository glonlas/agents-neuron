#!/usr/bin/env bash
# Tests for skill/scripts/lint-checks.sh
#
# Each test builds a throwaway HOME + vault, points the config at it, runs a
# lint check, and asserts on the output. Run directly or via `make test`.
set -uo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
LINT="${REPO_DIR}/skill/scripts/lint-checks.sh"

pass=0
fail=0

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

# --- Build a sandbox vault ---
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT

mkdir -p "${SANDBOX}/home/.agents-neuron"
WIKI="${SANDBOX}/vault/Agents-Neuron/Concepts"
mkdir -p "$WIKI" "${SANDBOX}/vault/Neuron-Sources"

cat > "${SANDBOX}/home/.agents-neuron/config.yaml" <<EOF
vault_path: "${SANDBOX}/vault"
wiki_folder: "Agents-Neuron"
sources_folder: "Neuron-Sources"
page_types:
  - entity
  - concept
min_relevance_score: 0.4
EOF

# Target page that exists
cat > "${WIKI}/Other Page.md" <<'EOF'
---
title: "Other Page"
type: concept
---
Body.
EOF

# Page with links that should NOT be flagged as broken:
#   - a link to an existing page carrying a #heading anchor
#   - a same-file #heading link
# ...and one link that SHOULD be flagged (target does not exist).
cat > "${WIKI}/Linking Page.md" <<'EOF'
---
title: "Linking Page"
type: concept
---
See [[Agents-Neuron/Concepts/Other Page#Some Heading]] for details.
Also see [[#Local Section]] in this same file.
And [[Agents-Neuron/Concepts/Does Not Exist]] which is genuinely missing.
EOF

echo "lint-checks: broken-links anchor handling"
OUT="$(HOME="${SANDBOX}/home" bash "$LINT" broken-links 2>&1)"

assert_no_match "anchored link to existing page is not flagged" \
    "Other Page" "$OUT"
assert_no_match "same-file heading link is not flagged" \
    "Local Section" "$OUT"
assert_match "genuinely missing target is still flagged" \
    "Does Not Exist" "$OUT"

# --- Summary ---
echo ""
printf "  %d passed, %d failed\n" "$pass" "$fail"
[ "$fail" -eq 0 ]
