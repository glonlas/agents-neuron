# Configuration

All user-specific configuration lives in `~/.agents-neuron/` — **outside the repo**. This keeps the skill reusable and shareable.

## Config files

| File | Purpose |
|------|---------|
| `~/.agents-neuron/config.yaml` | Wiki vault path, user vaults to scan, and settings |
| `~/.agents-neuron/filter-identity.md` | Your identity prompt: who this wiki is for and what matters |
| `~/.agents-neuron/query-log.md` | Query history, used by `neuron filter evolve` |
| `~/.agents-neuron/last-scan` | Timestamp of last `neuron scan` run |
| `~/.agents-neuron/last-ingest` | Timestamp of last `neuron ingest` run (drives the daily auto-ingest TTL) |
| `~/.agents-neuron/last-evolve` | Timestamp of last `neuron filter evolve` pass (drives the weekly auto-evolve TTL) |

`make install` copies example templates from `schema/*.example.*` into `~/.agents-neuron/` on first run. Existing files are never overwritten.

## config.yaml

```yaml
# The vault where wiki pages and sources are written
vault_path: "~/path/to/your/wiki-vault"

# Your personal note vaults that neuron scan reads from
user_vaults:
  - "~/path/to/your/main-notes-vault"
  - "~/path/to/another-vault"   # add as many as needed

# Customizable folder names (defaults shown)
wiki_folder: "Agents-Neuron"
sources_folder: "Neuron-Sources"

# Page types and scoring
page_types:
  - entity
  - concept
  - topic
  - recipe
  - comparison

tag_prefix: "agents-neuron"
min_relevance_score: 0.4

# Scheduled maintenance (runs automatically after `neuron add`, when due)
auto_ingest_ttl_hours: 24   # ingest at most once per day
auto_evolve_ttl_days: 7     # filter evolve at most once per week
```

---

## Scheduled maintenance after `neuron add`

`neuron add` keeps the wiki current without you remembering to run things. After
each import it makes one cheap TTL check (`scripts/auto-maintenance.sh check`)
and then:

- Runs `neuron ingest` if the last ingest was more than `auto_ingest_ttl_hours`
  ago (default 24h) — so pending sources get turned into wiki pages **at least
  once a day**, not on every add.
- Runs a `neuron filter evolve` pass if the last one was more than
  `auto_evolve_ttl_days` ago (default 7d) — so the filter is tuned **about once a
  week**.

If both are due, ingest runs first, then evolve. The timestamps live in
`~/.agents-neuron/last-ingest` and `~/.agents-neuron/last-evolve`; running either
command manually also resets its timer. Set the TTLs higher to run these less
often, or lower to run them more aggressively.

---

## Identity filter

### Generating your filter-identity.md

The fastest way to seed a personalized `filter-identity.md` is to ask an LLM what it already knows about you from your conversation history. Paste this prompt into ChatGPT (or any LLM you've been talking to):

```
Based on everything you know about me from our conversations — my job, projects,
interests, goals, and the topics I regularly ask about — please generate a
filter-identity.md file for my personal Agents Neuron wiki.

Be specific and honest. The more precise the identity, the sharper the filtering.

Structure:

# Identity Filter

## Who is this wiki for?
[2-3 sentences: my role, primary domains, key interests]

## What matters (scoring dimensions)

| Dimension | Weight | Description |
|-----------|--------|-------------|
[6-9 rows tailored to me, weights summing to 1.0]

## Minimum relevance threshold
Score: **0.4** out of 1.0

## Scoring instructions
[Brief guidance with a concrete example using my domains]

## Evolution log
*No changes yet.*

Make the dimensions specific to what I actually care about. Weights should reflect
how central each domain is to my life and work.
```

Save the output to `~/.agents-neuron/filter-identity.md`. Alternatively, `neuron bootstrap` will draft it automatically from your vault structure.

### How the filter works

The filter defines scoring dimensions and weights. Each source is scored 0-1 against each dimension; the weighted sum is compared against a minimum threshold (default: 0.4). Sources below the threshold are marked ingested but don't get wiki pages — they stay in `Neuron-Sources/` for reference without cluttering the wiki.

Run `neuron filter evolve` periodically to tune weights based on what you actually query and link to. All filter changes require your approval and apply to future ingests only — existing pages are never retroactively removed.
