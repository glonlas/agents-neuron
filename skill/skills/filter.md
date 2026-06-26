---
name: neuron-filter
description: >
  Manage the identity-aware relevance filter. Three modes: show (display
  current identity and scoring), score (manually score a source), evolve
  (propose filter updates based on usage patterns). Triggers on: neuron filter.
---

# Wiki Filter

Manage the identity-aware relevance filter that determines what knowledge gets promoted from raw sources to wiki pages.

## Commands

Parse the user's input to determine the mode:

- `neuron filter show` → Show mode
- `neuron filter score <source>` → Score mode
- `neuron filter evolve` → Evolution mode
- `neuron filter` (no subcommand) → Default to Show mode

---

## Show Mode

Display the current state of the identity filter.

1. Read `CONFIG_DIR/filter-identity.md`.
2. Present to the user:
   - The identity description (who this wiki is for).
   - The scoring dimensions table with weights.
   - The current minimum relevance threshold.
   - The evolution log (history of filter changes).
3. Also show quick stats by running:
   ```sh
   SKILL_DIR/scripts/wiki-stats.sh
   ```
   Output is `key=value` pairs: entities, concepts, topics, recipes, comparisons, total_pages, total_sources, pending_sources, ingested_sources, skipped_sources, avg_relevance. Format these into a readable summary.

---

## Score Mode

Manually run the filter scoring on a specific source without ingesting it.

1. Identify the source file from the user's input:
   - If they give a filename: look in `SOURCES/`.
   - If they give a wikilink: resolve it.
   - If they paste content: treat it as hypothetical (don't save).
2. Read `CONFIG_DIR/filter-identity.md` for dimensions.
3. Score the source against each dimension.
4. Present the detailed breakdown:

```
Source: 2026-04-11-some-article.md
Title: "Building LLM Agents with Tool Use"

Dimension Scores:
  Engineering & Architecture:  0.7 × 0.25 = 0.175
  Crypto & DeFi:               0.0 × 0.20 = 0.000
  AI & LLM Agents:             0.9 × 0.20 = 0.180
  Personal Finance (SG):       0.0 × 0.10 = 0.000
  Media & Processing:           0.0 × 0.05 = 0.000
  Photography & Creative:       0.0 × 0.05 = 0.000
  Cooking & Food:                0.0 × 0.05 = 0.000
  Curiosity Wildcard:            0.3 × 0.10 = 0.030

Total: 0.385
Threshold: 0.4
Decision: BORDERLINE — would be skipped by default.

Recommendation: This source has strong AI/Engineering relevance.
Consider rounding up if it contains actionable patterns for agent building.
```

This is informational only. It does not change any files.

---

## Evolution Mode

Analyze usage patterns and propose adjustments to the identity filter. This is the Baljanak "learning filter" mechanism.

### Step 1: Gather Evidence

Read the following:

1. **Query log** (`CONFIG_DIR/query-log.md`):
   - What topics does the user actually query?
   - Are there repeated queries about topics with low filter weights?

2. **Wiki stats** (via script):
   ```sh
   SKILL_DIR/scripts/wiki-stats.sh
   ```
   Shows which page types are growing vs stagnant.

3. **Skipped sources** — run lint to find orphans:
   ```sh
   SKILL_DIR/scripts/lint-checks.sh --check orphans
   ```
   Cross-reference orphaned sources with the query log: were any skipped topics later queried?

4. **Backlinks from non-wiki notes**:
   - Grep the vault (outside `Neuron/` and `Neuron-Sources/`) for wikilinks pointing into `Neuron/`.
   - Pages that other notes link to are high-engagement pages.

### Step 2: Analyze Patterns

From the evidence, identify:

- **Underweighted dimensions**: Topics the user queries or links to frequently, but that have low filter weights. These dimensions should be boosted.
- **Overweighted dimensions**: Topics with high weights but few queries, few pages, or pages that never get linked. These might be candidates for weight reduction.
- **Missing dimensions**: Topics that appear in queries or sources but aren't captured by any existing dimension. Propose adding a new dimension.
- **Threshold adjustment**: If too many useful sources are being skipped (user queries things that were filtered out), lower the threshold. If the wiki is getting noisy, raise it.

### Step 3: Propose Changes

Present the proposed changes clearly:

```markdown
## Filter Evolution Proposal — {today}

### Evidence Summary
- Analyzed: {N} queries, {M} wiki pages, {K} skipped sources
- Period: last 90 days

### Proposed Changes

1. **Increase "AI & LLM Agents" weight**: 0.20 → 0.25
   - Reason: 60% of queries are AI-related. Currently underweighted.

2. **Decrease "Cooking & Food" weight**: 0.05 → 0.03
   - Reason: No queries or new pages in this domain in 90 days.

3. **Add new dimension "Home Automation"**: weight 0.05
   - Reason: 3 sources about Raspberry Pi/surveillance imported but scored low.

4. **Lower threshold**: 0.4 → 0.35
   - Reason: 4 skipped sources were later queried by the user.

### Impact
- These changes apply to FUTURE ingests only.
- Existing wiki pages are NOT affected.
- {N} currently pending sources would change scoring.
```

After presenting the proposal, record that the evolve pass ran so the weekly TTL
gate (used by `neuron add`) knows it is up to date:
```sh
SKILL_DIR/scripts/auto-maintenance.sh touch evolve
```
Do this whether or not the user ends up approving changes — the weekly pass has
run; resetting the timer prevents it from re-triggering on every subsequent add.

### Step 4: Apply (with approval)

**CRITICAL: Do NOT apply changes automatically.** Wait for the user to approve.

If approved:
1. Update `CONFIG_DIR/filter-identity.md` with the new weights/dimensions/threshold.
2. Append to the "Evolution log" section at the bottom:
   ```
   ### {today} — Evolution pass
   - {description of changes made}
   - Evidence: {brief summary}
   - Approved by user.
   ```
3. Do NOT re-score or re-ingest existing sources. Changes are forward-only.

If rejected or partially approved:
- Apply only the approved changes.
- Log which changes were rejected and why (if the user explains).

---

## Invariants

1. **Filter changes are forward-only.** Never retroactively remove wiki pages based on new filter settings.
2. **Human in the loop.** The filter never updates itself autonomously.
3. **Weights must sum to 1.0.** When adjusting weights, rebalance the others proportionally.
4. **Evolution log is append-only.** Never delete previous entries.
