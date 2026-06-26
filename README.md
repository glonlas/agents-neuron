# Agents Neuron

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Linux-lightgrey.svg)]()
[![Claude Code](https://img.shields.io/badge/Claude%20Code-skill-blueviolet.svg)]()

A [Claude Code](https://claude.ai/code) skill that turns your reading into a personal, compounding knowledge wiki inside [Obsidian](https://obsidian.md/). Import anything — URLs, notes, pasted text — and Agents Neuron filters it through your identity profile, keeps only what matters, and builds structured wiki pages with full source traceability.

Supports **multiple Obsidian vaults** as sources (e.g. a personal vault and a work vault) — Agents Neuron scans all of them and writes everything into one unified wiki.

```
Sources (URLs, notes, text)  →  neuron add   →  raw sources (immutable)
                                    ↓
                             neuron ingest  →  score against identity filter
                                              below threshold → archived
                                              above threshold → wiki page
                                    ↓
                             neuron query   →  answers with citations
                             neuron lint    →  health checks
                             neuron filter  →  evolve relevance over time
```

Inspired by [Karpathy's original write-up](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f) and [Baljanak's learning filter](https://gist.github.com/baljanak/f233d3e321d353d34f2f6663369b3105). Built from scratch.

---

## Getting started

**Prerequisites:** [Claude Code](https://claude.ai/code), Bash 4+

```sh
git clone https://github.com/glonlas/neuron.git && cd neuron
make install                        # symlinks + seed ~/.agents-neuron/ config
# Edit ~/.agents-neuron/config.yaml # set vault_path
neuron bootstrap                      # run in Claude Code to init vault
```

Validate: `skill/scripts/doctor.sh` | Uninstall: `make uninstall`

---

## Example

```
# In Claude Code
neuron add https://www.reddit.com/r/LocalLLaMA/comments/1s49lvh/gguf_llamacpp_vs_mlx_round_2_your_feedback_tested/
neuron ingest
```

Agents Neuron fetches the thread, scores it against your identity filter, and — if it clears your relevance threshold — creates a structured wiki page (e.g. `Neuron/Comparisons/GGUF llama.cpp vs MLX.md`) with inline citations back to the source.

---

## Automation

**macOS (recommended)** — use the provided launchd helper:

```sh
./helpers/setup-launchd.sh           # install agents
./helpers/setup-launchd.sh --uninstall  # remove them
```

Installs three agents: daily `neuron ingest` at 08:00, weekly `neuron lint` and `neuron filter evolve` on Mondays at 09:00. Logs to `~/.agents-neuron/launchd.log`.

**Linux / cron** — add to your crontab with `crontab -e` (use the full path from `which claude`):

```sh
0 8 * * *   /path/to/claude -p "neuron ingest"        >> ~/.agents-neuron/cron.log 2>&1
0 9 * * 1   /path/to/claude -p "neuron lint"          >> ~/.agents-neuron/cron.log 2>&1
5 9 * * 1   /path/to/claude -p "neuron filter evolve" >> ~/.agents-neuron/cron.log 2>&1
```

Pair with `neuron scan` in your morning terminal session to pull overnight note changes.

---

## Quick reference

| Command | What it does |
|---------|-------------|
| `neuron scan` | Pull recently modified vault notes into the wiki |
| `neuron add <url\|text>` | Import a single source |
| `neuron ingest` | Score pending sources, create wiki pages |
| `neuron query <question>` | Answer from wiki with citations |
| `neuron lint` | Health check |
| `neuron filter evolve` | Tune relevance weights from usage patterns |

---

## Documentation

| Doc | Contents |
|-----|----------|
| [Commands](docs/commands.md) | Full command reference, daily usage patterns, recommended cadence |
| [Configuration](docs/configuration.md) | config.yaml, identity filter setup, scoring dimensions |
| [Architecture](docs/architecture.md) | File structure, scripts vs LLM split, page types, cross-platform support |
| [Troubleshooting](docs/troubleshooting.md) | Common errors and doctor.sh |
| [Contributing](CONTRIBUTING.md) | How to add skills, scripts, and submit PRs |

---

## Credits

- [Andrej Karpathy](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f) — the original personal knowledge wiki concept
- [Baljanak](https://gist.github.com/baljanak/f233d3e321d353d34f2f6663369b3105) — identity-aware learning filter

## License

[MIT](LICENSE)
