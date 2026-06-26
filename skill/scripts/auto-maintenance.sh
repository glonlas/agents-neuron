#!/usr/bin/env bash
# Token-frugal TTL gate for scheduled maintenance (ingest / filter evolve).
#
# Lets `neuron add` decide — with a single cheap call — whether the daily
# ingest and/or weekly filter-evolve passes are due, instead of running them
# on every add.
#
# Usage:
#   auto-maintenance.sh check          # print INGEST and EVOLVE status (2 lines)
#   auto-maintenance.sh touch ingest   # record that ingest just ran
#   auto-maintenance.sh touch evolve   # record that filter evolve just ran
#
# TTLs (overridable in config.yaml):
#   auto_ingest_ttl_hours   (default 24)
#   auto_evolve_ttl_days    (default 7)
#
# `check` output is exactly two lines, each value one of due|ok|never:
#   INGEST=due
#   EVOLVE=ok
# "due"   → TTL elapsed, run it.
# "never" → never run before, run it.
# "ok"    → ran recently, skip.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/_config.sh"

INGEST_STAMP="${CONFIG_DIR}/last-ingest"
EVOLVE_STAMP="${CONFIG_DIR}/last-evolve"

# TTLs from config, with defaults
INGEST_TTL_HOURS=$(awk '/^auto_ingest_ttl_hours:/{print $2}' "$CONFIG_FILE")
INGEST_TTL_HOURS="${INGEST_TTL_HOURS:-24}"
EVOLVE_TTL_DAYS=$(awk '/^auto_evolve_ttl_days:/{print $2}' "$CONFIG_FILE")
EVOLVE_TTL_DAYS="${EVOLVE_TTL_DAYS:-7}"

_epoch_mtime() {
    # epoch seconds of file mtime; non-zero exit if missing
    [ -f "$1" ] || return 1
    if $_IS_MACOS; then
        stat -f %m "$1"
    else
        stat -c %Y "$1"
    fi
}

_status() {
    local stamp="$1" ttl_secs="$2" mtime now age
    if ! mtime=$(_epoch_mtime "$stamp"); then
        echo "never"; return
    fi
    now=$(date +%s)
    age=$(( now - mtime ))
    if [ "$age" -ge "$ttl_secs" ]; then
        echo "due"
    else
        echo "ok"
    fi
}

cmd="${1:-check}"
case "$cmd" in
    check)
        echo "INGEST=$(_status "$INGEST_STAMP" "$(( INGEST_TTL_HOURS * 3600 ))")"
        echo "EVOLVE=$(_status "$EVOLVE_STAMP" "$(( EVOLVE_TTL_DAYS * 86400 ))")"
        ;;
    touch)
        case "${2:-}" in
            ingest) touch "$INGEST_STAMP" ;;
            evolve) touch "$EVOLVE_STAMP" ;;
            *) echo "ERROR: touch requires 'ingest' or 'evolve'" >&2; exit 1 ;;
        esac
        ;;
    *)
        echo "ERROR: unknown command '$cmd' (use check|touch)" >&2
        exit 1
        ;;
esac
