# AI Install Guide

> **Audience: an AI coding agent (Claude Code, Codex, OpenCode, or any agent that loads AI Skills).**
> This is a runbook you execute on the user's machine to install and configure the Agents Neuron skill end-to-end. Follow it top to bottom. Each step lists a check, the command to run, and how to interpret the result. Stop and ask the user only at the explicit checkpoints marked **ASK**.

---

## What you are installing

Agents Neuron is an **AI Skill** — not tied to any single agent. It works with any coding agent that loads skills, including Claude Code, Codex, and OpenCode, and builds a personal knowledge wiki inside an Obsidian vault. Installation has three parts:

1. **The skill repo** — cloned somewhere stable on disk (the source of truth).
2. **Symlinks** — `skill/` is linked into two discovery locations so whichever agent the user runs picks it up:
   - `~/.agents/skills/neuron` — the cross-agent skills directory (Codex, OpenCode, and other agents that follow the shared `~/.agents/` convention).
   - `~/.claude/skills/neuron` — Claude Code's skills directory.
3. **Personal config** — `~/.agents-neuron/` (vault path + identity filter), created from templates and then edited for this user. Shared by every agent — it is agent-independent.

Nothing about the user lives in the repo; all personal state lives in `~/.agents-neuron/` and inside the user's Obsidian vault. The skill is invoked the same way in every agent: type `neuron <command>` in an agent session.

---

## Step 0 — Preflight checks

Run these before touching anything. Report any failure to the user with the suggested fix.

```sh
# A compatible AI agent present (required — this skill runs inside one).
# At least one of these should resolve:
command -v claude   && echo "found: Claude Code"
command -v codex    && echo "found: Codex"
command -v opencode && echo "found: OpenCode"

# Git present (required to clone)
command -v git || echo "MISSING: git"

# Bash present (3.2+ — the version macOS preinstalls is enough)
bash --version | head -1
```

**On the shell:** the user's login shell (zsh on every modern Mac) does **not** matter here. Neuron's scripts are bash scripts (`#!/usr/bin/env bash`) — they run under bash via their own shebang regardless of the interactive shell, so there is nothing to switch and nothing to install. macOS ships `/bin/bash` 3.2, and the scripts use no bash 4+ features (only indexed arrays), so the preinstalled bash is sufficient. Do **not** tell the user to `brew install bash` — it's unnecessary.

---

## Step 1 — Locate or clone the repo

First determine whether the repo is already on disk. Do **not** clone if it already exists.

```sh
# Are we already inside the repo? (look for the skill marker)
test -f skill/SKILL.md && grep -q "^name: neuron" skill/SKILL.md && echo "ALREADY IN REPO: $(pwd)"

# Is it cloned elsewhere? Search under the home directory for the skill marker.
# (Do not assume any particular folder layout — discover it.)
find ~ -maxdepth 4 -type f -name SKILL.md -path "*/skill/SKILL.md" 2>/dev/null \
  | xargs -I{} dirname {} | xargs -I{} dirname {}
```

- **If found**, `cd` into the repo root (the directory containing the `Makefile` and `skill/`) and skip to Step 2.
- **If not found**, clone it. Canonical remote:

```sh
git clone https://github.com/glonlas/agents-neuron.git ~/agents-neuron
cd ~/agents-neuron
```

> **ASK** the user where to clone it if they have a preferred location for source repos. Otherwise default to `~/agents-neuron` (home directory) — pick whatever the user actually uses; do not assume any particular folder layout. The install symlinks point back to wherever the repo lives, so the path just needs to be stable (don't put it in `/tmp` or a temp worktree).

Confirm you are at the repo root before continuing:

```sh
test -f Makefile && test -f skill/SKILL.md && echo "REPO ROOT OK: $(pwd)"
```

---

## Step 2 — Install symlinks and seed config

This is a single `make` target. It is idempotent — safe to re-run, never overwrites existing config.

```sh
make install
```

What it does:

- Creates `~/.agents-neuron/` and copies templates from `schema/*.example.*` into it:
  - `config.yaml` ← `schema/config.example.yaml`
  - `filter-identity.md` ← `schema/filter-identity.example.md`
  - `query-log.md` ← `schema/query-log.example.md`
- Symlinks `skill/` into both `~/.agents/skills/neuron` and `~/.claude/skills/neuron`.

Verify the symlinks resolve to this repo:

```sh
ls -l ~/.claude/skills/neuron ~/.agents/skills/neuron
```

Each should point at `<repo>/skill`.

---

## Step 3 — Configure the vault path

Edit `~/.agents-neuron/config.yaml`. The two fields that matter for a first run:

| Field | Meaning | Required? |
|-------|---------|-----------|
| `vault_path` | The Obsidian vault where Neuron writes wiki pages + sources | **Yes** |
| `user_vaults` | Personal note vaults that `neuron scan` reads from | Optional (needed only for `neuron scan`) |

> **ASK** the user for their Obsidian vault path. Do not guess it. If they don't have a vault yet, an empty folder works — Neuron creates its subfolders on bootstrap.

Discover candidate vaults to offer the user (Obsidian marks every vault with a `.obsidian/` folder):

```sh
find ~ -maxdepth 4 -type d -name ".obsidian" 2>/dev/null | sed 's:/.obsidian::'
```

Then set `vault_path` (and optionally `user_vaults`) in `~/.agents-neuron/config.yaml`. Use the Edit tool rather than `sed` so the change is reviewable. Paths may use `~` and must be quoted if they contain spaces.

---

## Step 4 — Generate the identity filter

The identity filter (`~/.agents-neuron/filter-identity.md`) defines what content is relevant to this user. The template copied in Step 2 is a generic placeholder — replace it.

Two paths, in order of preference:

**A. Let `neuron bootstrap` draft it (Step 5)** from the user's existing vault structure. Good default — do this if the user already has notes.

**B. Seed it from an LLM that knows the user.** Give the user this prompt to paste into ChatGPT or any LLM they've conversed with, then save the output to `~/.agents-neuron/filter-identity.md`:

> Based on everything you know about me — my job, projects, interests, and the topics I regularly ask about — generate a `filter-identity.md` for my personal knowledge wiki. Include: who the wiki is for (2–3 sentences), a scoring-dimensions table (6–9 rows, weights summing to 1.0), a minimum relevance threshold (default 0.4), brief scoring instructions with a concrete example from my domains, and an empty evolution log.

The full prompt and dimension format live in [configuration.md](configuration.md#generating-your-filter-identitymd).

---

## Step 5 — Bootstrap the vault

This runs **inside your AI agent** (Claude Code, Codex, OpenCode, …), not in a plain shell — it is a skill command. Invoke it in an agent session:

```
neuron bootstrap
```

It initializes the vault folder structure (`Agents-Neuron/` wiki + `Neuron-Sources/`) and, if the identity filter is still the placeholder, drafts a real one from the vault. All writes are explained before they happen.

---

## Step 6 — Validate the install

Run the bundled doctor script. Exit code 0 means ready.

```sh
skill/scripts/doctor.sh
```

It checks: bash 4+, `config.yaml` present, `filter-identity.md` and `query-log.md` present, `vault_path` set and existing, the wiki/sources folders, each `user_vaults` entry, and that all scripts are executable. Resolve any `FAIL` before telling the user the install is complete. `WARN` lines are non-blocking (e.g. folders not yet created — they appear after `neuron bootstrap`).

If a script is reported non-executable:

```sh
chmod +x skill/scripts/*.sh
```

---

## Step 7 — Smoke test (optional but recommended)

In an agent session (any of Claude Code, Codex, OpenCode), confirm the skill responds:

```
neuron add https://obsidian.md/
neuron ingest
```

`neuron add` imports the source; `neuron ingest` scores it and, if it clears the threshold, writes a wiki page with a citation. Confirm a file appeared under the vault's `Agents-Neuron/` folder.

---

## Step 8 — Automation (optional)

Offer to set up scheduled jobs only if the user wants hands-off operation. These run the skill **non-interactively**, so they invoke whichever agent's headless command the user has installed:

| Agent | Headless invocation |
|-------|---------------------|
| Claude Code | `claude -p "neuron ingest"` |
| Codex | `codex exec "neuron ingest"` |
| OpenCode | `opencode run "neuron ingest"` |

**macOS** — the bundled launchd helper (daily `ingest` at 08:00, weekly `lint` + `filter evolve` Mondays):

```sh
./helpers/setup-launchd.sh             # install
./helpers/setup-launchd.sh --uninstall # remove
```

The helper currently targets **Claude Code** — it resolves the `claude` binary via `PATH` and errors if it isn't found (make sure Step 0 found it first). Logs go to `~/.agents-neuron/launchd.log`. To automate with Codex or OpenCode instead, use the cron form below with that agent's headless command.

**Linux / any agent** — cron entries (use the absolute path from `which <agent>`; the example uses Claude Code):

```cron
0 8 * * *   /path/to/claude -p "neuron ingest"        >> ~/.agents-neuron/cron.log 2>&1
0 9 * * 1   /path/to/claude -p "neuron lint"          >> ~/.agents-neuron/cron.log 2>&1
5 9 * * 1   /path/to/claude -p "neuron filter evolve" >> ~/.agents-neuron/cron.log 2>&1
```

Swap `claude -p` for `codex exec` or `opencode run` to schedule under a different agent.

---

## Uninstall

```sh
make uninstall   # removes symlinks, prompts before deleting ~/.agents-neuron/
```

The cloned repo is left in place — delete it manually if desired. Launchd/cron jobs must be removed separately (`./helpers/setup-launchd.sh --uninstall` or `crontab -e`).

---

## Failure quick-reference

| Symptom | Cause | Fix |
|---------|-------|-----|
| `make: command not found` | No `make` | Install build tools (`xcode-select --install` on macOS) |
| doctor: `bash ... (need 3.2+)` | No bash on `PATH` (very unusual) | macOS preinstalls `/bin/bash`; ensure `PATH` includes `/bin` |
| doctor: `config.yaml not found` | `make install` never ran | Run Step 2 from the repo root |
| doctor: `vault not found` | `vault_path` wrong/unset | Fix Step 3 |
| Agent doesn't see `neuron` | Symlinks missing or repo moved | Re-run `make install` from the current repo location; confirm `~/.agents/skills/neuron` (Codex/OpenCode) and `~/.claude/skills/neuron` (Claude) resolve |
| `setup-launchd.sh`: `'claude' not found` | `claude` not on `PATH` (helper is Claude-only) | Open a fresh shell; verify with `which claude`, or use the cron form with your agent's headless command |

See [troubleshooting.md](troubleshooting.md) for the full list.
