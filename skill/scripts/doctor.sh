#!/usr/bin/env bash
# Validate that Agents Neuron is correctly set up.
#
# Usage: doctor.sh
#
# Checks config, vault paths, script permissions, and bash version.
# Prints a pass/fail summary.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_DIR="${HOME}/.agents-neuron"
CONFIG_FILE="${CONFIG_DIR}/config.yaml"

pass=0
fail=0
warn=0

ok()   { pass=$((pass + 1)); echo "  OK   $1"; }
fail() { fail=$((fail + 1)); echo "  FAIL $1"; }
warn() { warn=$((warn + 1)); echo "  WARN $1"; }

echo "Agents Neuron doctor"
echo "============="
echo ""

# --- Bash version ---
echo "Environment:"
bash_major="${BASH_VERSINFO[0]:-0}"
bash_minor="${BASH_VERSINFO[1]:-0}"
# Scripts use only indexed arrays and POSIX-ish constructs — bash 3.2
# (preinstalled on macOS) is sufficient. No bash 4+ features are used.
if [ "$bash_major" -gt 3 ] || { [ "$bash_major" -eq 3 ] && [ "$bash_minor" -ge 2 ]; }; then
    ok "bash ${BASH_VERSION}"
else
    fail "bash ${BASH_VERSION} (need 3.2+)"
fi

# --- Config ---
echo ""
echo "Configuration:"
if [ -f "$CONFIG_FILE" ]; then
    ok "config.yaml exists at ${CONFIG_FILE}"
else
    fail "config.yaml not found at ${CONFIG_FILE} — run 'make install'"
fi

if [ -f "${CONFIG_DIR}/filter-identity.md" ]; then
    ok "filter-identity.md exists"
else
    warn "filter-identity.md not found — run 'neuron bootstrap' or create manually"
fi

if [ -f "${CONFIG_DIR}/query-log.md" ]; then
    ok "query-log.md exists"
else
    warn "query-log.md not found — will be created on first query"
fi

# --- Vault path ---
echo ""
echo "Vault:"
if [ -f "$CONFIG_FILE" ]; then
    VAULT=$(sed -n 's/^vault_path: *"\{0,1\}\(.*[^"]\)"\{0,1\}$/\1/p' "$CONFIG_FILE" | head -1)
    VAULT="${VAULT/#\~/$HOME}"
    if [ -z "$VAULT" ]; then
        fail "vault_path not set in config.yaml"
    elif [ -d "$VAULT" ]; then
        ok "vault exists at ${VAULT}"

        WIKI_FOLDER=$(awk '/^wiki_folder:/{print $2}' "$CONFIG_FILE" | sed 's/^"//;s/"$//')
        WIKI_FOLDER="${WIKI_FOLDER:-Agents-Neuron}"
        SOURCES_FOLDER=$(awk '/^sources_folder:/{print $2}' "$CONFIG_FILE" | sed 's/^"//;s/"$//')
        SOURCES_FOLDER="${SOURCES_FOLDER:-Neuron-Sources}"

        if [ -d "${VAULT}/${WIKI_FOLDER}" ]; then
            ok "${WIKI_FOLDER}/ exists"
        else
            warn "${WIKI_FOLDER}/ not found — run 'neuron bootstrap'"
        fi

        if [ -d "${VAULT}/${SOURCES_FOLDER}" ]; then
            ok "${SOURCES_FOLDER}/ exists"
        else
            warn "${SOURCES_FOLDER}/ not found — run 'neuron bootstrap'"
        fi
    else
        fail "vault not found at ${VAULT}"
    fi
else
    fail "skipped vault checks (no config.yaml)"
fi

# --- User vaults ---
echo ""
echo "User vaults:"
if [ -f "$CONFIG_FILE" ]; then
    vault_count=0
    while IFS= read -r uv; do
        [ -z "$uv" ] && continue
        uv="${uv/#\~/$HOME}"
        vault_count=$((vault_count + 1))
        if [ -d "$uv" ]; then
            ok "$(basename "$uv") at ${uv}"
        else
            fail "not found: ${uv}"
        fi
    done < <(awk '
        /^user_vaults:/ { found=1; next }
        found && /^[[:space:]]*-[[:space:]]/ {
            line = $0
            gsub(/^[[:space:]]*-[[:space:]]*"?/, "", line)
            gsub(/"?[[:space:]]*$/, "", line)
            if (line != "") print line
        }
        found && /^[^[:space:]-]/ { exit }
    ' "$CONFIG_FILE")
    if [ "$vault_count" -eq 0 ]; then
        warn "no user_vaults configured (neuron scan will not work)"
    fi
else
    fail "skipped user vault checks (no config.yaml)"
fi

# --- Script permissions ---
echo ""
echo "Scripts:"
for script in "${SCRIPT_DIR}"/*.sh; do
    [ ! -f "$script" ] && continue
    name=$(basename "$script")
    [ "$name" = "doctor.sh" ] && continue
    if [ -x "$script" ]; then
        ok "${name} is executable"
    else
        fail "${name} is not executable — run: chmod +x ${script}"
    fi
done

# --- Summary ---
echo ""
echo "─────────────────────────"
printf "  %d passed, %d failed, %d warnings\n" "$pass" "$fail" "$warn"
if [ "$fail" -gt 0 ]; then
    echo "  Fix the failures above before using Neuron."
    exit 1
else
    echo "  Neuron is ready."
    exit 0
fi
