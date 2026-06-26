#!/usr/bin/env bash
# Run all deterministic lint checks on the wiki.
#
# Output: JSON-like blocks per check category.
# Non-deterministic checks (semantic type errors, duplicate detection)
# are left to the LLM.
#
# Usage: lint-checks.sh [--check orphans|broken-links|frontmatter|index-drift|stale-sources|all]
#        Default: all
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/_config.sh"

# Accept: lint-checks.sh | lint-checks.sh --check orphans | lint-checks.sh orphans
CHECK_NAME="all"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --check) CHECK_NAME="$2"; shift 2;;
        *)       CHECK_NAME="$1"; shift;;
    esac
done

REQUIRED_FIELDS="title type created updated sources tags"

# ---------- helpers ----------

# Extract all [[...]] wikilinks from a file (content + frontmatter).
# Strips the |display alias and any #heading / ^block anchor so the link
# resolves to its target page (Obsidian treats [[Page#Heading]] as Page).
extract_wikilinks() {
    grep -oE '\[\[[^]]+\]\]' "$1" 2>/dev/null \
        | sed 's/\[\[//;s/\]\]//' \
        | sed 's/|.*//;s/#.*//;s/\^.*//' \
        | sort -u
}

# Check if a wikilink target exists as a file in the vault
wikilink_exists() {
    local link="$1"
    # Try exact path .md
    [ -f "${VAULT}/${link}.md" ] && return 0
    [ -f "${VAULT}/${link}" ] && return 0
    return 1
}

# Extract frontmatter value; returns "(array)" for multi-line YAML list fields
fm_value() {
    awk -v field="$1" '
        /^---$/ { fm_count++; next }
        fm_count == 1 {
            if ($0 ~ ("^" field ":")) {
                val = $0
                sub("^" field ": *", "", val)
                if (val != "") { print val; exit }
                # Empty inline value: peek at the next line for a YAML list item.
                # Exclude the closing "---" delimiter, which also matches /^ *-/
                # but means the field is genuinely empty, not an array.
                if ((getline nextline) > 0 && nextline ~ /^ *-/ && nextline !~ /^---$/) print "(array)"
                exit
            }
        }
        fm_count >= 2 { exit }
    ' "$2" | head -1
}

# ---------- checks ----------

run_orphan_sources() {
    echo "=== ORPHAN_SOURCES ==="
    [ ! -d "$SOURCES" ] && return
    find "$SOURCES" -name "*.md" -type f 2>/dev/null | sort | while IFS= read -r f; do
        ingested=$(sed -n 's/^ingested: *\(.*\)/\1/p' "$f" | head -1)
        [ "$ingested" != "true" ] && continue
        wiki_pages=$(sed -n 's/^wiki_pages: *\(.*\)/\1/p' "$f" | head -1)
        if [ -z "$wiki_pages" ] && grep -q '^wiki_pages:' "$f"; then
            # Peek at the line after "wiki_pages:" for a YAML list item. Exclude
            # the closing "---" delimiter, which also matches /^ *-/ but means the
            # field is genuinely empty, not an array (mirrors fm_value above).
            next_line=$(grep -A1 '^wiki_pages:' "$f" | tail -1)
            [ "$next_line" != "---" ] && printf '%s\n' "$next_line" | grep -q '^ *-' && wiki_pages="(array)"
        fi
        score=$(sed -n 's/^relevance_score: *\(.*\)/\1/p' "$f" | head -1)
        if [ "$wiki_pages" = "[]" ] || [ -z "$wiki_pages" ]; then
            # Only flag if score was above threshold (real orphan, not just filtered out)
            if [ -n "$score" ] && [ "$score" != "null" ]; then
                above=$(awk "BEGIN{print ($score >= $MIN_SCORE) ? 1 : 0}")
                if [ "$above" = "1" ]; then
                    rel="${f#"${VAULT}"/}"
                    printf "  %s\t(score: %s, no wiki pages)\n" "$rel" "$score"
                fi
            fi
        fi
    done
}

run_broken_links() {
    echo "=== BROKEN_WIKILINKS ==="
    [ ! -d "$WIKI" ] && return
    find "$WIKI" -name "*.md" -type f 2>/dev/null | sort | while IFS= read -r f; do
        page_rel="${f#"${VAULT}"/}"
        extract_wikilinks "$f" | while IFS= read -r link; do
            [ -z "$link" ] && continue
            if ! wikilink_exists "$link"; then
                printf "  %s\t→\t[[%s]]\n" "$page_rel" "$link"
            fi
        done
    done
}

run_missing_frontmatter() {
    echo "=== MISSING_FRONTMATTER ==="
    [ ! -d "$WIKI" ] && return
    find "$WIKI" -name "*.md" -not -name "_index.md" -type f 2>/dev/null | sort | while IFS= read -r f; do
        page_rel="${f#"${VAULT}"/}"
        missing=""
        for field in $REQUIRED_FIELDS; do
            val=$(fm_value "$field" "$f")
            if [ -z "$val" ]; then
                missing="${missing}${missing:+, }${field}"
            fi
        done
        if [ -n "$missing" ]; then
            printf "  %s\tmissing: %s\n" "$page_rel" "$missing"
        fi
    done
}

run_index_drift() {
    echo "=== INDEX_DRIFT ==="
    INDEX="${WIKI}/_index.md"
    [ ! -f "$INDEX" ] && echo "  _index.md not found" && return

    # Pages on disk but not in index
    find "$WIKI" -name "*.md" -not -name "_index.md" -type f 2>/dev/null | sort | while IFS= read -r f; do
        page_name="$(basename "$f" .md)"
        # Check if page appears anywhere in _index.md (as a wikilink)
        if ! grep -q "$page_name" "$INDEX" 2>/dev/null; then
            page_rel="${f#"${VAULT}"/}"
            printf "  NOT_IN_INDEX\t%s\n" "$page_rel"
        fi
    done

    # Links in index pointing to non-existent files
    extract_wikilinks "$INDEX" | while IFS= read -r link; do
        [ -z "$link" ] && continue
        if ! wikilink_exists "$link"; then
            printf "  DEAD_IN_INDEX\t[[%s]]\n" "$link"
        fi
    done
}

run_stale_sources() {
    echo "=== STALE_PENDING_SOURCES ==="
    [ ! -d "$SOURCES" ] && return
    cutoff=$(portable_date_days_ago 30)
    find "$SOURCES" -name "*.md" -type f 2>/dev/null | sort | while IFS= read -r f; do
        ingested=$(sed -n 's/^ingested: *\(.*\)/\1/p' "$f" | head -1)
        [ "$ingested" != "false" ] && continue
        imported=$(sed -n 's/^imported: *\(.*\)/\1/p' "$f" | head -1)
        if [ -n "$imported" ] && [[ "$imported" < "$cutoff" ]]; then
            rel="${f#"${VAULT}"/}"
            printf "  %s\t(imported: %s, still pending)\n" "$rel" "$imported"
        fi
    done
}

run_source_integrity() {
    echo "=== SOURCE_INTEGRITY ==="
    [ ! -d "$SOURCES" ] && return
    src_required="title source_type imported ingested"
    find "$SOURCES" -name "*.md" -type f 2>/dev/null | sort | while IFS= read -r f; do
        missing=""
        for field in $src_required; do
            val=$(fm_value "$field" "$f")
            if [ -z "$val" ]; then
                missing="${missing}${missing:+, }${field}"
            fi
        done
        if [ -n "$missing" ]; then
            rel="${f#"${VAULT}"/}"
            printf "  %s\tmissing: %s\n" "$rel" "$missing"
        fi
    done
}

# ---------- dispatch ----------

case "$CHECK_NAME" in
    orphans)          run_orphan_sources ;;
    broken-links)     run_broken_links ;;
    frontmatter)      run_missing_frontmatter ;;
    index-drift)      run_index_drift ;;
    stale-sources)    run_stale_sources ;;
    source-integrity) run_source_integrity ;;
    all)
        run_orphan_sources
        run_broken_links
        run_missing_frontmatter
        run_index_drift
        run_stale_sources
        run_source_integrity
        ;;
    *)
        echo "Unknown check: ${CHECK_NAME}" >&2
        echo "Available: orphans, broken-links, frontmatter, index-drift, stale-sources, source-integrity, all" >&2
        exit 1
        ;;
esac
