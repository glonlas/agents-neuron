#!/usr/bin/env bash
# Tests for skill/scripts/wiki-stats.sh
#
# Builds a throwaway HOME + vault, points the config at it, runs wiki-stats,
# and asserts on the emitted key=value pairs. Run directly or via `make test`.
set -uo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
STATS="${REPO_DIR}/skill/scripts/wiki-stats.sh"

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

# --- Build a sandbox vault ---
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT

mkdir -p "${SANDBOX}/home/.agents-neuron"
ENTITIES="${SANDBOX}/vault/Agents-Neuron/Entities"
CONCEPTS="${SANDBOX}/vault/Agents-Neuron/Concepts"
mkdir -p "$ENTITIES" "$CONCEPTS" "${SANDBOX}/vault/Neuron-Sources"

cat > "${SANDBOX}/home/.agents-neuron/config.yaml" <<EOF
vault_path: "${SANDBOX}/vault"
wiki_folder: "Agents-Neuron"
sources_folder: "Neuron-Sources"
page_types:
  - entity
  - concept
min_relevance_score: 0.4
EOF

cat > "${ENTITIES}/Some Entity.md" <<'EOF'
---
title: "Some Entity"
type: entity
---
Body.
EOF

cat > "${CONCEPTS}/Some Concept.md" <<'EOF'
---
title: "Some Concept"
type: concept
---
Body.
EOF

echo "wiki-stats: page-type key pluralization"
OUT="$(HOME="${SANDBOX}/home" bash "$STATS" 2>&1)"

# The "entity" page type must be reported under the documented "entities" key,
# not the naive "entitys" that a bare +s suffix would produce.
assert_match    "entity type emits 'entities=' key" "entities=1" "$OUT"
assert_no_match "no malformed 'entitys=' key"        "entitys="   "$OUT"
assert_match    "concept type emits 'concepts=' key" "concepts=1" "$OUT"

# --- Summary ---
echo ""
printf "  %d passed, %d failed\n" "$pass" "$fail"
[ "$fail" -eq 0 ]
