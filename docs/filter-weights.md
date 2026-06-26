# Filter Weights

This page explains two things:

1. **How weights decide what becomes a wiki page**: the scoring math.
2. **How weights change over time**: what `neuron filter evolve` does and why.

If you only read one section, read [The scoring formula](#the-scoring-formula).

---

## What a weight is

Your identity filter (`~/.agents-neuron/filter-identity.md`) lists the topics you
care about. Each topic is a **dimension**. Each dimension has a **weight**, a
number that says how much that topic counts toward keeping a source.

```
| Dimension                  | Weight | Description                          |
|----------------------------|--------|--------------------------------------|
| Engineering & Architecture | 0.25   | Software design, systems, DevOps     |
| AI & LLM Agents            | 0.20   | Agents, tool use, model behavior     |
| Crypto & DeFi              | 0.20   | On-chain, trading, protocols         |
| Personal Finance (SG)      | 0.10   | Investing, CPF, SGD planning         |
| Media & Processing         | 0.05   | Video/image pipelines                |
| Photography & Creative     | 0.05   | Cameras, composition                 |
| Cooking & Food             | 0.05   | Recipes, technique                   |
| Curiosity Wildcard         | 0.10   | Anything genuinely novel             |
```

Two rules govern the weights:

- **Weights sum to 1.0.** Boosting one dimension means lowering others. The
  filter rebalances so the total stays at 1.0.
- **Higher weight = stronger pull.** A source about a heavy dimension clears the
  bar more easily than the same-quality source about a light one.

---

## The scoring formula

When a source is scored (during `neuron ingest`, or manually with
`neuron filter score`), every dimension gets a **relevance rating** from `0.0`
to `1.0`: "how much is this source about that topic?" Then:

```
score = Σ (rating × weight)   for every dimension
```

The total is compared against your **threshold** (default `0.4`):

| Result            | What happens                                              |
|-------------------|----------------------------------------------------------|
| `score ≥ threshold` | Source becomes one or more wiki pages.                  |
| `score < threshold` | Source is marked `ingested` but gets **no** wiki page. It stays searchable in `Neuron-Sources/`. |

### Worked example

A source titled *"Building LLM Agents with Tool Use"*:

```
Engineering & Architecture:  0.7 × 0.25 = 0.175
AI & LLM Agents:             0.9 × 0.20 = 0.180
Crypto & DeFi:               0.0 × 0.20 = 0.000
Personal Finance (SG):       0.0 × 0.10 = 0.000
Media & Processing:          0.0 × 0.05 = 0.000
Photography & Creative:      0.0 × 0.05 = 0.000
Cooking & Food:              0.0 × 0.05 = 0.000
Curiosity Wildcard:          0.3 × 0.10 = 0.030
                                         -------
Total:                                    0.385
Threshold:                                0.400
Decision:                                 BORDERLINE
```

The score lands just under the bar. Borderline sources (roughly `0.35–0.45`)
with a genuinely novel insight are rounded up; shallow ones already covered by
existing pages are skipped. That judgment is part of the scoring instructions in
your filter file.

### Why the weight matters

Same source, but imagine you had set `AI & LLM Agents` to `0.30` (and trimmed
others to keep the sum at 1.0). The AI line becomes `0.9 × 0.30 = 0.270`, the
total clears `0.4`, and the page is created automatically. **The weight is the
difference between "kept" and "skipped."**

---

## How weights change: `neuron filter evolve`

Your interests drift. The filter you wrote on day one will be wrong by month
three. `neuron filter evolve` re-tunes the weights from what you **actually do**
with the wiki, instead of what you guessed you'd care about.

### What it reads (the evidence)

| Source of evidence            | What it reveals                                  |
|-------------------------------|--------------------------------------------------|
| Query log (`query-log.md`)    | Topics you keep asking about                      |
| Wiki stats (`wiki-stats.sh`)  | Which page types grow vs. sit stagnant            |
| Orphaned / skipped sources    | Sources filtered out that you later queried       |
| Backlinks from your own notes | Pages your other notes link to (high engagement)  |

### What it proposes

From that evidence it suggests four kinds of change:

1. **Boost an underweighted dimension**: you query it often, but its weight is
   low, so good sources keep getting skipped.
2. **Trim an overweighted dimension**: high weight, but no queries, no new
   pages, no backlinks in a long stretch.
3. **Add a missing dimension**: a topic shows up in sources or queries that no
   existing dimension captures.
4. **Adjust the threshold**: lower it if useful sources are being filtered out;
   raise it if the wiki is getting noisy.

A proposal looks like this:

```markdown
## Filter Evolution Proposal: 2026-06-27

### Evidence Summary
- Analyzed: 42 queries, 118 wiki pages, 9 skipped sources
- Period: last 90 days

### Proposed Changes
1. Increase "AI & LLM Agents" weight: 0.20 → 0.25
   - Reason: 60% of queries are AI-related. Currently underweighted.
2. Decrease "Cooking & Food" weight: 0.05 → 0.03
   - Reason: No queries or new pages in this domain in 90 days.
3. Add new dimension "Home Automation": weight 0.05
   - Reason: 3 Raspberry Pi sources imported but scored too low to keep.
4. Lower threshold: 0.4 → 0.35
   - Reason: 4 skipped sources were later queried.

### Impact
- Applies to FUTURE ingests only.
- Existing wiki pages are NOT affected.
```

### Nothing changes without your approval

`neuron filter evolve` **never edits the filter on its own.** It prints the
proposal and waits. Then:

- **Approve all**: every change is written to `filter-identity.md`.
- **Approve some**: only the changes you accept are written.
- **Reject**: nothing changes.

Whatever you decide, an entry is appended to the **evolution log** at the bottom
of `filter-identity.md` so you have a dated history of how the filter drifted.

---

## The rules that never bend

These invariants hold no matter what evolve proposes:

| Rule                       | Meaning                                                       |
|----------------------------|--------------------------------------------------------------|
| **Forward-only**           | New weights affect future ingests. Existing pages are never retroactively deleted. |
| **Human in the loop**      | The filter never updates itself autonomously.                |
| **Weights sum to 1.0**     | Adjusting one weight rebalances the others.                  |
| **Append-only log**        | Evolution-log entries are never deleted.                     |

The forward-only rule is the important one: tightening your filter will **not**
purge pages you already have. If you want old low-value pages gone, remove them
yourself; `neuron lint` will help you find stale and orphaned ones.

---

## When evolve runs

You can run it by hand anytime:

```
neuron filter evolve
```

It also runs **automatically about once a week**. After `neuron add`, Neuron
checks the timestamp in `~/.agents-neuron/last-evolve`; if the last pass was more
than `auto_evolve_ttl_days` (default 7) ago, it runs an evolve pass. Running it
manually resets that timer. See
[Scheduled maintenance](configuration.md#scheduled-maintenance-after-neuron-add)
for the full TTL behavior.

A good manual cadence is **monthly**, alongside `neuron lint`.

---

## Related

- [Configuration → Identity filter](configuration.md#identity-filter): how to
  write and seed `filter-identity.md`.
- [Commands](commands.md): the full `neuron filter` command reference.
- [Architecture](architecture.md): where the filter sits in the pipeline.
