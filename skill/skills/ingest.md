---
name: neuron-ingest
description: >
  Filter pending sources by relevance and transform qualifying ones into
  Obsidian-native wiki pages. The core engine of Agents Neuron. Reads the identity
  filter, scores each source, creates/updates wiki pages with frontmatter,
  wikilinks, and source citations. Triggers on: neuron ingest.
---

# Wiki Ingest

The core transformation engine. Reads pending sources, scores them against the identity filter, and creates or updates wiki pages for qualifying content.

## Pre-flight

1. Read `CONFIG_DIR/config.yaml` for paths.
2. Read `CONFIG_DIR/filter-identity.md` for scoring dimensions and threshold.
3. Read `SKILL_DIR/references/page-standards.md` for page templates and frontmatter requirements.
4. Read `WIKI/_index.md` to know what wiki pages already exist.

## Step 1: Find Pending Sources

Run the script:
```sh
SKILL_DIR/scripts/find-pending-sources.sh
```

Output is tab-separated: `filepath \t title \t word_count`, one per line.
If exit code is 1, there are no pending sources — inform the user: "No pending sources to ingest. Run `neuron add` to add sources."

Read each listed source file.

## Step 2: Score Each Source

For each pending source, apply the identity filter:

1. Read the source content.
2. For each scoring dimension in `filter-identity.md`, rate relevance 0.0–1.0.
3. Compute the weighted sum.
4. Compare against `min_relevance_score` threshold.

### If score < threshold:
- Update the source file's frontmatter: set `ingested: true` and `relevance_score: {score}`.
- Do NOT create a wiki page.
- Log: "Skipped: {source_file} (score: {score}, threshold: {threshold})"

### If score >= threshold:
- Proceed to page creation (Step 3).
- Update the source file's frontmatter: set `ingested: true`, `relevance_score: {score}`.

**Present the scoring to the user** before creating pages:

```
Source: 2026-04-11-karpathy-agents-neuron.md
Scores:
  Engineering & Architecture: 0.6 × 0.25 = 0.150
  AI & LLM Agents:           0.9 × 0.20 = 0.180
  Curiosity Wildcard:         0.5 × 0.10 = 0.050
  Total: 0.380 → rounds up (novel insight about LLM knowledge maintenance)
Action: CREATE wiki page(s)
```

## Step 3: Determine Page Actions

For each qualifying source, analyze its content and decide:

### Does it update an existing wiki page?
- Search existing wiki pages (from `_index.md`) for overlap.
- If a source covers the same entity/concept as an existing page, UPDATE that page:
  - Add new information from the source.
  - Add the source to the page's `sources` frontmatter list.
  - Update the `updated` date.
  - Add inline citations for new claims.

### Does it warrant a new wiki page?
- If the source introduces something not yet in the wiki, CREATE a new page.
- Determine the page type (entity, concept, topic, recipe, comparison) based on content:
  - Describes a specific tool/project/person → **entity**
  - Explains an idea/pattern/principle → **concept**
  - Covers a broad area → **topic**
  - Provides step-by-step instructions → **recipe**
  - Compares two or more things → **comparison**

### One source can produce multiple pages.
A long article might introduce a new entity AND a new concept. Create separate pages for each.

### One source might produce zero NEW pages.
If it only updates existing pages, that's fine. No new page needed.

## Step 4: Create/Update Wiki Pages

For each page to create or update:

1. **Read the page template** from `page-standards.md` for the appropriate type.
2. **Generate frontmatter** following the common frontmatter spec:
   - `title`: Clear, descriptive title.
   - `type`: The page type.
   - `created`: Today's date (for new pages) or preserve original (for updates).
   - `updated`: Today's date.
   - `sources`: Wikilinks to ALL contributing source files.
   - `related`: Wikilinks to related wiki pages (scan existing pages for connections).
   - `tags`: `agents-neuron/{type}` plus domain tags.
   - `relevance_score`: The filter score.
   - `aliases`: Short names, abbreviations, alternate spellings.

3. **Write page content** following the template structure for the page type.
   - Every factual claim must have an inline citation: `[[Neuron-Sources/YYYY/YYYY-MM-DD-slug|Display Name]]`
   - Use wikilinks to reference other wiki pages: `[[Neuron/Concepts/Some Concept]]`
   - Keep content concise and structured. This is a wiki, not an essay.

4. **Save the file** to `WIKI/{Type}/{Page Title}.md`
   - File name = page title with spaces, Title Case.
   - Example: `WIKI/Concepts/Agents Neuron.md`

## Step 5: Update Source Frontmatter

For each ingested source, run the script:
```sh
SKILL_DIR/scripts/update-source-meta.sh <filepath> --ingested true --score <score> --wiki-pages '["[[Neuron/Type/Page]]"]'
```

This deterministically updates the frontmatter fields. Do NOT manually edit source frontmatter.

## Step 6: Update _index.md

Read the current `_index.md` and update the appropriate sections. Between the `<!-- TYPE_START -->` and `<!-- TYPE_END -->` markers, maintain an alphabetical list of pages:

```markdown
<!-- CONCEPTS_START -->
- [[Neuron/Concepts/Event Sourcing]] — Pattern for modeling state as a sequence of events
- [[Neuron/Concepts/Agents Neuron]] — Persistent knowledge base maintained by LLM
<!-- CONCEPTS_END -->
```

Each entry: `- [[wikilink]] — one-line description`

## Step 7: Report

Summarize what happened:

```
Ingested 2 sources:

✓ 2026-04-11-karpathy-agents-neuron.md (score: 0.53)
  → Created: Neuron/Concepts/Agents Neuron.md
  → Created: Neuron/Entities/RAG.md

✗ 2026-04-11-generic-press-release.md (score: 0.02)
  → Skipped (below threshold)

Wiki now has: 2 entities, 1 concept, 0 topics, 0 recipes, 0 comparisons
```

## Step 8: Record the run timestamp

After reporting, record that ingest ran so the daily TTL gate (used by
`neuron add`) knows it is up to date:
```sh
SKILL_DIR/scripts/auto-maintenance.sh touch ingest
```
Do this on every completed ingest — manual or auto-triggered — even if there
were no pending sources to process.

## Conflict Handling

If a source contradicts information in an existing wiki page:
1. Do NOT silently overwrite.
2. Add a "Conflicting evidence" note in the affected section:
   ```
   > **Note**: [[source-a|Source A]] states X, but [[source-b|Source B]] states Y. Needs resolution.
   ```
3. Flag this in the report so the user can resolve it.
