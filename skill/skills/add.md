---
name: neuron-add
description: >
  Acquire a source into Neuron-Sources. Accepts URLs (fetches and converts
  to markdown), pasted text, or references to existing vault notes. Each source
  becomes an immutable markdown file with metadata frontmatter.
  Triggers on: neuron add.
---

# Wiki Import

Acquire a raw source and save it to the `Neuron-Sources/` folder in the Obsidian vault. Sources are immutable after import — they represent the original material exactly as received.

## Input Modes

Detect the input type from the user's message:

### 1. URL Import
User provides a URL (e.g., `neuron add https://example.com/article`).

1. Use WebFetch to retrieve the page content. Prompt: "Extract the main article content as clean markdown. Remove navigation, ads, footers, and boilerplate. Preserve headings, lists, code blocks, and important formatting."
2. If WebFetch fails or returns insufficient content, inform the user and suggest pasting the content manually.
3. Save the extracted content as a source file.

### 2. Text Import
User pastes or provides text directly (e.g., `neuron add` followed by a block of text, or "import this: ...").

1. Take the provided text as-is.
2. Save as a source file.

### 3. File Import
User references an existing vault note (e.g., `neuron add [[Some Note]]` or `neuron add /path/to/file.md`).

1. Read the referenced file.
2. Save a COPY as a source file (do not move or modify the original).

## Source File Format

Save to: `SOURCES/{current_year}/{YYYY-MM-DD}-{slug}.md`

Where:
- `SOURCES` = `VAULT/Neuron-Sources` (from config.yaml)
- `{current_year}` = e.g., `2026`
- `{YYYY-MM-DD}` = today's date
- `{slug}` = lowercase-kebab-case derived from the title or URL. Max 60 characters. Examples:
  - URL `https://example.com/agents-neuron-overview` → `agents-neuron-overview`
  - Title "How to Deploy FastAPI" → `how-to-deploy-fastapi`
  - If no title, use a descriptive slug from the content

### Frontmatter

```yaml
---
title: "Original Title or User-Provided Title"
source_type: url | text | file
source_url: "https://..." | null
imported: YYYY-MM-DD
ingested: false
relevance_score: null
wiki_pages: []
---
```

### Body

The raw content follows the frontmatter. For URL imports, this is the extracted markdown. For text imports, the user's text. For file imports, the file content.

Do NOT summarize, restructure, or editorialize the source content. Store it as-is. The ingestion step handles transformation.

## Duplicate Detection

Before saving, check for duplicates using the script:
```sh
SKILL_DIR/scripts/check-duplicate.sh --url "https://..."
SKILL_DIR/scripts/check-duplicate.sh --title "Article Title"
```

Output (if duplicate found): `DUPLICATE \t filepath \t imported_date`
Exit code 1 = no duplicate found (safe to import).

If a duplicate is found, warn the user: "A source with this URL was already imported on {date}: {path}. Import anyway? (y/n)"

## Post-Import

After saving the source file:
1. Confirm to the user: "Imported: `{source_path}` ({word_count} words)"
2. Remind them: "Run `neuron ingest` to filter and create wiki pages from pending sources."

## Scheduled Maintenance (TTL-gated)

After the import (or batch import) is complete, run the daily ingest and weekly
filter-evolve passes **automatically — but only when they are due**. Do NOT run
them on every `neuron add`; the TTL gate below decides.

### Step 1: Check what's due (one cheap call)

Run the gate script once:
```sh
SKILL_DIR/scripts/auto-maintenance.sh check
```

It prints exactly two lines, e.g.:
```
INGEST=due
EVOLVE=ok
```
Each value is `due` (TTL elapsed — run it), `never` (never run — run it), or
`ok` (ran recently — skip). This is the only check; do not read timestamps or
inspect other files yourself.

### Step 2: Run what's due, in order

If **both** are due, run ingest **first**, then evolve. Specifically:

1. **If `INGEST` is `due` or `never`:**
   - Read `SKILL_DIR/skills/ingest.md` and follow it to ingest pending sources.
   - (The ingest skill records its own timestamp on completion.)

2. **If `EVOLVE` is `due` or `never`:**
   - Read `SKILL_DIR/skills/filter.md` and follow its **Evolution Mode** to run a
     filter-evolve pass and present a proposal.
   - (The filter skill records its own timestamp when the evolve pass runs.)

If both are `ok`, do nothing further — just finish the import normally.

Note: ingest and filter evolve are human-in-the-loop (evolve requires approval
before applying). Running them here means presenting their normal output to the
user; it does not bypass any approval step.

## Batch Import

If the user provides multiple URLs or texts at once, import each one sequentially. Report a summary at the end:
```
Imported 3 sources:
- Neuron-Sources/2026/2026-04-11-karpathy-agents-neuron.md (2,340 words)
- Neuron-Sources/2026/2026-04-11-baljanak-learning-filter.md (1,890 words)
- Neuron-Sources/2026/2026-04-11-fastapi-deployment-guide.md (3,100 words)
```

## Error Handling

- If WebFetch fails, suggest the user paste the content manually.
- If the vault path doesn't exist or Neuron-Sources/ is missing, suggest running `neuron bootstrap` first.
- If the year subfolder doesn't exist, create it with `mkdir -p`.
