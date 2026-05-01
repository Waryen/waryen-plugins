# LLM Wiki Schema — <vault-name>

This file is the operating contract for Claude Code acting as wiki maintainer. Read it in full at the start of every session. Every operation follows the workflows below exactly.

---

## Directory Layout

```
<vault-name>/
├── CLAUDE.md              ← this file (schema)
├── index.md               ← master content catalog (LLM-maintained)
├── log.md                 ← append-only activity log (LLM-maintained)
├── raw/                   ← immutable source documents (human-curated)
│   └── assets/            ← downloaded images and attachments
└── wiki/                  ← all LLM-generated pages
    ├── overview.md        ← master synthesis (always kept current)
    ├── sources/           ← one page per ingested source
    ├── entities/          ← companies, people, products, projects
    ├── concepts/          ← technologies, techniques, paradigms
    └── topics/            ← thematic analyses and syntheses
```

**Rules:**

- `raw/` is read-only. Never create, edit, or delete files there — **except** that the ingest workflow must delete the source file from `raw/` as its final step, after all wiki writes and the log entry are complete.
- Everything in `wiki/` is LLM-owned. Maintain it aggressively.
- `index.md` and `log.md` are updated on every operation (ingest, query-that-produces-a-page, lint).
- `CLAUDE.md` is co-evolved with the user. Update it when conventions change.

---

## Page Formats

### Source page — `wiki/sources/<slug>.md`

```yaml
---
title: <article title>
type: source
date: YYYY-MM-DD
source_url: <url or "local">
author: <author or publication>
tags: [tag1, tag2]
entities: [EntityName, ...]
concepts: [ConceptName, ...]
---
```

Body: 3–5 paragraph summary. Key claims. Notable quotes. What this changes or confirms relative to existing wiki knowledge. End with a `## Links` section with wikilinks to updated entity/concept/topic pages.

### Entity page — `wiki/entities/<slug>.md`

```yaml
---
title: <entity name>
type: entity
kind: company | person | product | project | organization
tags: [tag1, tag2]
---
```

Body sections: **What it is**, **Key developments** (reverse-chron bullets), **Products / Work** (if applicable), **Relationships** (wikilinks to related entities), **Open questions**. A `## Sources` section lists all source pages that mention this entity.

### Concept page — `wiki/concepts/<slug>.md`

```yaml
---
title: <concept name>
type: concept
tags: [tag1, tag2]
---
```

Body sections: **Definition**, **Current state** (what's true now), **Key players** (wikilinks to entities), **Open problems / debates**, **Evolution** (how understanding has shifted). A `## Sources` section lists relevant source pages.

### Topic page — `wiki/topics/<slug>.md`

```yaml
---
title: <topic title>
type: topic
tags: [tag1, tag2]
---
```

Free-form synthesis. Can include tables, comparisons, timelines. Link heavily to entities and concepts. A `## Sources` section lists contributing sources.

### Overview — `wiki/overview.md`

No frontmatter constraints. The living synthesis of everything in the wiki: major themes, key players, open questions, where the field is moving. Updated on every ingest (lightweight touch: add bullets or update relevant sections) and on explicit user request (full rewrite). Should always be readable as a standalone document.

---

## Workflows

### INGEST

Triggered when user drops a file in `raw/` or pastes content and says "ingest".

**Steps (in order):**

1. **Read** the source document in full.
2. **Discuss** with the user: What are the 2–3 most important takeaways? Does anything contradict existing wiki knowledge? What should be emphasized?
3. **Write** `wiki/sources/<slug>.md` (slug = kebab-case title, max 6 words).
4. **Update or create** entity pages for every named company, person, product, or project mentioned significantly.
5. **Update or create** concept pages for every technology or idea that is meaningfully discussed.
6. **Update** `wiki/overview.md`: add bullets or update relevant sections to reflect this source. Always do this — do not skip. Full rewrites only on explicit user request.
7. **Append** to `log.md`: `## [YYYY-MM-DD] ingest | <source title>`
8. **Update** `index.md`: add the source page; update any entity/concept entries that changed.
9. **Delete** the source file at the path provided in step 1 from `raw/`.
10. **Report** to user: list every file touched with a one-line summary of what changed.

**Rule:** Never skip steps 7, 8, and 9. Even small ingests update the log, index, and remove the source file.

### QUERY

Triggered when user asks a question against the wiki.

**Steps:**

1. Read `index.md` to identify relevant pages.
2. Read the relevant pages.
3. Synthesize an answer with inline wikilink citations (e.g., `[[OpenAI]]`, `[[sources/llm-agents-survey]]`).
4. **If the answer is non-trivial** (a comparison, an analysis, a synthesis the wiki didn't have): ask the user "Should I file this as a wiki page?" If yes, write it to `wiki/topics/<slug>.md`, update index and log.

### LINT

Triggered when user asks to "lint", "health-check", or "audit" the wiki.

**Check for and report:**

- Contradictions between pages (flag both pages, propose resolution)
- Stale claims superseded by newer sources (propose update)
- Orphan pages (no inbound wikilinks)
- Concepts or entities mentioned in multiple pages but lacking their own page
- Missing cross-references (entity/concept page that doesn't link to a relevant source)
- Data gaps: topics we have partial coverage on that could be filled with a web search

After reporting, ask user which issues to fix. Fix approved issues, update log.

### ADD-SOURCE (web)

When user provides a URL to fetch:

1. Use WebFetch to retrieve the content.
2. Save the markdown to `raw/<slug>.md`.
3. Proceed with the INGEST workflow.

---

## Cross-reference conventions

- Always use Obsidian wikilinks: `[[PageTitle]]` or `[[path/to/page|Display Text]]`.
- Entity and concept pages use the page title exactly as the link target.
- Source pages are linked as `[[sources/slug]]` or `[[sources/slug|Article Title]]`.
- Every entity/concept page must have at least one inbound link from a source page.
- When updating an entity page after a new ingest, add the new source to its `## Sources` section.

---

## Index conventions (`index.md`)

The index is organized into sections: **Sources**, **Entities**, **Concepts**, **Topics**.

Each entry is one line:

```
- [[path/to/page|Title]] — one-line description (N sources)
```

Keep entries sorted alphabetically within each section. The LLM updates the index on every write operation.

---

## Log conventions (`log.md`)

Append-only. Each entry:

```markdown
## [YYYY-MM-DD] <operation> | <title>

<2–4 sentence summary of what was done and what changed.>
```

Operations: `ingest`, `query`, `lint`, `add-source`, `schema-update`.

Never edit past entries. Only append.

---

## Naming conventions

| Type       | File path pattern               | Example                                           |
| ---------- | ------------------------------- | ------------------------------------------------- |
| Source     | `wiki/sources/<kebab-slug>.md`  | `wiki/sources/attention-is-all-you-need.md`       |
| Entity     | `wiki/entities/<kebab-slug>.md` | `wiki/entities/openai.md`                         |
| Concept    | `wiki/concepts/<kebab-slug>.md` | `wiki/concepts/retrieval-augmented-generation.md` |
| Topic      | `wiki/topics/<kebab-slug>.md`   | `wiki/topics/llm-agents-2026.md`                  |
| Raw source | `raw/<kebab-slug>.md`           | `raw/deepmind-gemini-report.md`                   |

---

## What NOT to do

- Do not summarize without filing. Answers that synthesize the wiki belong in it.
- Do not create entity/concept pages for things mentioned once in passing. Significance threshold: mentioned in 2+ sources, or deeply discussed in 1.
- Do not let `index.md` lag behind. Every file write is followed by an index update in the same operation.
- Do not write walls of text on entity pages. Bullets and sections. Scannable.
- Do not hallucinate claims not in the sources. If uncertain, flag with `> **Note:** needs verification`.
- Do not modify `raw/` files. Deletion of the source file after ingest is the only permitted `raw/` operation.

---

## Session startup checklist

At the start of every new session:

1. Read this file (`CLAUDE.md`).
2. Read `index.md` to get the current state of the wiki.
3. Read the last 5 entries of `log.md` to understand recent activity.
4. Greet the user with a one-line status: how many sources, entities, concepts, topics are in the wiki.

---
