#!/usr/bin/env bash
# Compute wiki statistics.
#
# Output (key=value, one per line):
#   entities=3
#   concepts=5
#   topics=2
#   recipes=4
#   comparisons=1
#   total_pages=15
#   total_sources=22
#   pending_sources=3
#   ingested_sources=19
#   skipped_sources=7
#   avg_relevance=0.62
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/_config.sh"

count_md() {
    local dir="$1"
    if [ -d "$dir" ]; then
        find "$dir" -name "*.md" ! -name "_index.md" 2>/dev/null | wc -l | tr -d ' '
    else
        echo 0
    fi
}

# Count pages per type dynamically from config
total_pages=0
while IFS= read -r ptype; do
    [ -z "$ptype" ] && continue
    dir_name=$(_type_to_dir "$ptype")
    count=$(count_md "${WIKI}/${dir_name}")
    total_pages=$((total_pages + count))
    # Use the same pluralizer as the directory name (lowercased) so the key
    # matches the documented output (entity → entities, not entitys).
    key=$(printf '%s' "$dir_name" | tr '[:upper:]' '[:lower:]')
    echo "${key}=${count}"
done <<< "$PAGE_TYPES"
echo "total_pages=${total_pages}"

# Source stats
total_sources=0
pending_sources=0
ingested_sources=0
skipped_sources=0
score_sum=0
score_count=0

if [ -d "$SOURCES" ]; then
    while IFS= read -r f; do
        [ -z "$f" ] && continue
        total_sources=$((total_sources + 1))

        ingested=$(sed -n 's/^ingested: *\(.*\)/\1/p' "$f" | head -1)
        score=$(sed -n 's/^relevance_score: *\(.*\)/\1/p' "$f" | head -1)
        wiki_pages=$(sed -n 's/^wiki_pages: *\(.*\)/\1/p' "$f" | head -1)
        if [ -z "$wiki_pages" ] && grep -q '^wiki_pages:' "$f"; then
            # Peek at the line after "wiki_pages:" for a YAML list item. Exclude
            # the closing "---" delimiter, which also matches /^ *-/ but means the
            # field is genuinely empty, not an array (mirrors fm_value in lint-checks.sh).
            next_line=$(grep -A1 '^wiki_pages:' "$f" | tail -1)
            [ "$next_line" != "---" ] && printf '%s\n' "$next_line" | grep -q '^ *-' && wiki_pages="(array)"
        fi

        if [ "$ingested" = "false" ]; then
            pending_sources=$((pending_sources + 1))
        else
            ingested_sources=$((ingested_sources + 1))
            # Skipped = ingested but no wiki pages created
            if [ "$wiki_pages" = "[]" ] || [ -z "$wiki_pages" ]; then
                skipped_sources=$((skipped_sources + 1))
            fi
        fi

        # Accumulate scores for average (only non-null, non-zero)
        if [ -n "$score" ] && [ "$score" != "null" ] && [ "$score" != "0" ]; then
            score_sum=$(awk -v s="$score_sum" -v n="$score" 'BEGIN{printf "%.4f", s + n}')
            score_count=$((score_count + 1))
        fi
    done < <(find "$SOURCES" -name "*.md" -type f 2>/dev/null | sort)
fi

if [ "$score_count" -gt 0 ]; then
    avg_relevance=$(awk -v s="$score_sum" -v c="$score_count" 'BEGIN{printf "%.2f", s / c}')
else
    avg_relevance="n/a"
fi

cat <<EOF
total_sources=${total_sources}
pending_sources=${pending_sources}
ingested_sources=${ingested_sources}
skipped_sources=${skipped_sources}
avg_relevance=${avg_relevance}
EOF
