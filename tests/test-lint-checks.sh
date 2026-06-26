#!/usr/bin/env bash
# Tests for skill/scripts/lint-checks.sh
#
# Each test builds a throwaway HOME + vault, points the config at it, runs a
# lint check, and asserts on the output. Run directly or via `make test`.
set -uo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
LINT="${REPO_DIR}/skill/scripts/lint-checks.sh"

# shellcheck source=tests/_helpers.sh
source "${REPO_DIR}/tests/_helpers.sh"

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

# Page whose only frontmatter problem is an EMPTY array field sitting directly
# above the closing "---". The empty field must be reported as missing — it must
# not be mistaken for a populated YAML list (the "---" line matches /^ *-/).
cat > "${WIKI}/Empty Tags.md" <<'EOF'
---
title: "Empty Tags"
type: concept
created: 2026-01-01
updated: 2026-01-01
sources:
  - "[[Agents-Neuron/Concepts/Other Page]]"
tags:
---
Body.
EOF

echo ""
echo "lint-checks: empty array field before closing delimiter"
OUT="$(HOME="${SANDBOX}/home" bash "$LINT" frontmatter 2>&1)"

assert_match "empty 'tags:' before '---' is flagged as missing" \
    "Empty Tags.md	missing: tags" "$OUT"

# An ingested, above-threshold source whose "wiki_pages:" is empty and sits
# directly above the closing "---" is a genuine orphan. The "---" delimiter
# matches /^ *-/, so a naive list-item peek mistakes the empty field for a
# populated array and the orphan goes unreported.
cat > "${SANDBOX}/vault/Neuron-Sources/orphan.md" <<'EOF'
---
title: "Orphan Source"
source_type: text
imported: 2026-01-01
ingested: true
relevance_score: 0.9
wiki_pages:
---
Body.
EOF

echo ""
echo "lint-checks: orphan source with empty wiki_pages before delimiter"
OUT="$(HOME="${SANDBOX}/home" bash "$LINT" orphans 2>&1)"

assert_match "ingested above-threshold source with empty wiki_pages is flagged orphan" \
    "orphan.md" "$OUT"

# --- Summary ---
echo ""
printf "  %d passed, %d failed\n" "$pass" "$fail"
[ "$fail" -eq 0 ]
