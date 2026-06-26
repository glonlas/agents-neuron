#!/usr/bin/env bash
# Tests for skill/scripts/wiki-stats.sh
#
# Builds a throwaway HOME + vault, points the config at it, runs wiki-stats,
# and asserts on the emitted key=value pairs. Run directly or via `make test`.
set -uo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
STATS="${REPO_DIR}/skill/scripts/wiki-stats.sh"

# shellcheck source=tests/_helpers.sh
source "${REPO_DIR}/tests/_helpers.sh"

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

# An ingested source whose ONLY remaining frontmatter field is an EMPTY
# "wiki_pages:" sitting directly above the closing "---" must count as skipped.
# The "---" delimiter also matches /^ *-/, so a naive "next line is a list item?"
# check mistakes the empty field for a populated array and undercounts skipped.
cat > "${SANDBOX}/vault/Neuron-Sources/skipped.md" <<'EOF'
---
title: "Skipped Source"
source_type: text
imported: 2026-01-01
ingested: true
relevance_score: 0.9
wiki_pages:
---
Body.
EOF

echo ""
echo "wiki-stats: empty wiki_pages before closing delimiter counts as skipped"
OUT="$(HOME="${SANDBOX}/home" bash "$STATS" 2>&1)"

assert_match "ingested source with empty wiki_pages is counted skipped" \
    "skipped_sources=1" "$OUT"

# --- Summary ---
echo ""
printf "  %d passed, %d failed\n" "$pass" "$fail"
[ "$fail" -eq 0 ]
