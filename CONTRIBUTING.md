# Contributing to Agents Neuron

Thanks for your interest in contributing. Here's what you need to know.

## Setup

```sh
git clone https://github.com/glonlas/neuron.git
cd neuron
make install
# Edit ~/.agents-neuron/config.yaml to set vault_path to a test Obsidian vault
# Run: neuron bootstrap (in Claude Code)
```

## Architecture

Agents Neuron has two layers:

| Layer | What it does | Where |
|-------|-------------|-------|
| **Skills** (`.md`) | LLM instructions for semantic work (scoring, synthesis, page creation) | `SKILL.md` + `skills/*.md` |
| **Scripts** (`.sh`) | Deterministic operations (find files, update metadata, lint checks) | `scripts/*.sh` |

All scripts source `scripts/_config.sh` which provides:
- Config loading (`VAULT`, `WIKI`, `SOURCES`, `MIN_SCORE`, `PAGE_TYPES`)
- Cross-platform helpers (`SED_INPLACE`, `portable_date_ago`, `portable_stat_mtime`)

User-specific configuration lives in `~/.agents-neuron/` (outside the repo).

## Adding a new sub-skill

1. Create `skills/your-skill.md` with YAML frontmatter (`name`, `description`)
2. Add the command to the routing table in `SKILL.md`
3. If the skill needs deterministic file operations, add a script in `scripts/`

## Adding a new script

1. Source `_config.sh` at the top for paths and portable helpers
2. Use `set -euo pipefail`
3. Use `SED_INPLACE`, `portable_date_ago`, etc. Never use platform-specific commands directly
4. Output tab-separated or `key=value` format for LLM consumption
5. Quote all path variables (vault paths may contain spaces)

## Cross-platform requirement

All scripts must work on both **macOS** and **Linux**. Key differences handled by `_config.sh`:

- `sed -i ''` (macOS) vs `sed -i` (GNU) → use `SED_INPLACE` array
- `date -v` (macOS) vs `date -d` (GNU) → use `portable_date_ago`
- `stat -f` (macOS) vs `stat -c` (GNU) → use `portable_stat_mtime`

## Pull requests

- One logical change per PR
- Test on macOS if you have access; CI covers Linux
- If you modify a script, run it manually against a test vault to confirm it works
- Run `skill/scripts/doctor.sh` to validate setup before submitting

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
