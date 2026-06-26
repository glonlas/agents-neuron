# Commands

## Reference

| Command | What it does |
|---------|-------------|
| `neuron bootstrap` | One-time setup: creates vault folders and drafts your identity filter |
| `neuron scan` | Scan vault for recently modified notes and auto-import/ingest them |
| `neuron scan --since 3d` | Scan notes modified in the last N days (or `--since YYYY-MM-DD`) |
| `neuron scan --all` | Scan the entire vault regardless of last scan time |
| `neuron add <url|text|file>` | Manually import a single source into `Neuron-Sources/` |
| `neuron ingest` | Process all pending sources through the filter; create wiki pages |
| `neuron query <question>` | Synthesize an answer from wiki pages with inline citations |
| `neuron lint` | Health check: broken links, orphans, duplicates, stale pages |
| `neuron filter show` | Display current identity filter and scoring dimensions |
| `neuron filter score <source>` | Manually score a source without ingesting it |
| `neuron filter evolve` | Analyze usage patterns and propose filter weight adjustments |

---

## Daily usage

### Your own notes → wiki (daily)

Run this each morning or after a writing session to pull your own vault notes into the wiki:

```
neuron scan
```

It finds every note modified since the last scan, shows you the list, asks for confirmation, then imports and ingests them. Notes that score below your relevance threshold are skipped — only what actually matters to you becomes a wiki page.

First run (no prior scan): defaults to the last 7 days. Override with:

```
neuron scan --since 7d
neuron scan --since 2026-04-01
neuron scan --all        # entire vault, use once on first setup
```

### External content → wiki (as needed)

When you read something worth keeping — an article, a thread, a doc:

```
neuron add https://some-article.com
neuron ingest
```

Or import multiple sources at once, then batch-ingest:

```
neuron add https://article-1.com
neuron add https://article-2.com
neuron ingest
```

### Query what you know

```
neuron query what do I know about event sourcing?
neuron query compare FastAPI vs Express
neuron query how do I deploy Caddy with HTTPS?
```

Answers cite the specific wiki pages used. If there are gaps it tells you what to import.

### Maintenance

```
neuron lint              # find broken links, orphans, duplicates
neuron filter evolve     # tune relevance weights based on actual usage
```

See [Filter Weights](filter-weights.md) for how scoring works and exactly what `neuron filter evolve` proposes and changes.

---

## Recommended cadence

| When | Command |
|------|---------|
| Morning / after writing | `neuron scan` |
| Read something worth keeping | `neuron add <url>` then `neuron ingest` |
| Before starting a project | `neuron query <topic>` |
| Monthly | `neuron lint` + `neuron filter evolve` |
