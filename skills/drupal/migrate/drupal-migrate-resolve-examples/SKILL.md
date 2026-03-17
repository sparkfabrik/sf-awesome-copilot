---
name: drupal-migrate-resolve-examples
description: 'Resolve live URLs for representative example content during Drupal migration source analysis. Use whenever the user asks for a full source analysis, live examples, example page URLs, representative source content, or validation of public paths for nodes, paragraphs, taxonomy terms, or media. Compulsory in every full source analysis — runs automatically before any optional screenshot capture. Does not take screenshots (use drupal-migrate-live-screenshots for that).'
---

# migrate-resolve-examples

Resolve at least one representative live URL per relevant parent or referencing node bundle for a source Drupal entity bundle.

This skill populates the **Live examples** section of a migration source analysis report. It is a **required, automatic step** in every full source analysis — do **not** wait for user confirmation before running it.

Run it after prerequisite discovery/context skills have produced bundle and parent information, and before any optional screenshot capture. If the user asks for screenshots, example pages, or live content validation, make sure this skill runs first and let `drupal-migrate-live-screenshots` consume its output afterward.

Do **not** use this skill to take screenshots or to perform destination-field analysis.

---

## When to use

Use this skill whenever the user needs any of the following as part of Drupal migration analysis:

- A **full source analysis** that includes live examples
- One or more **representative public URLs** for a source bundle
- Validation that example source content resolves to real **public pages**
- The input needed for the optional `drupal-migrate-live-screenshots` step

Typical trigger phrases include: "analyze this paragraph bundle", "full source analysis", "show me live examples", "find example pages for this content type", "resolve URLs for representative nodes".

### When not to use

- If the task is only about **taking screenshots**, ensure this skill has already produced URLs, then use `drupal-migrate-live-screenshots`
- If the task is only about **field structure, counts, or destination mappings**, only run this skill if the workflow also needs live examples

---

## Workflow position

In a standard full source analysis, this skill runs after the analysis has enough context to identify valid example content:

1. Discover and verify the source DB
2. Detect Drupal version
3. Count bundle instances
4. Resolve parent context / active examples when needed
5. Query source fields and population
6. **Run this skill to resolve live example URLs** ← you are here
7. Optionally ask the user whether to run `drupal-migrate-live-screenshots`

If prior skills already produced the necessary parent node IDs or example entities in the current session, reuse that data instead of re-deriving it.

---

## Inputs

Required context (available from prior skills in the analysis workflow):

- Source bundle name (e.g., `button_action`)
- Parent node bundles and example node IDs (from `migrate-parent-context` + `migrate-verify-active`)
- Project config from `.github/prompts/migrate-instructions.prompt.md` — check for a `## Live URL Resolution` section that may override the default resolution strategy below

---

## Entity-Type Context

Before running any query, resolve entity-type-specific variables from:
**`.github/prompts/drupal-migrate-entity-type-context.prompt.md`**

Use `{has_direct_url}` and `{base_table}` from that reference to determine the resolution strategy.

---

## Steps

### Step 0 — Entity-type guard

Determine the resolution strategy based on entity type:

| Entity type | Strategy | Details |
|---|---|---|
| `node` | **Direct** | Resolve URL from `path_alias` for the node itself |
| `paragraph` | **Via parent node** | Use parent node IDs from `migrate-parent-context` / `migrate-verify-active`, then resolve parent node URLs |
| `taxonomy_term` | **Via referencing node** | Find published nodes that reference this term, then resolve those node URLs |
| `media` | **Via referencing node** | Find published nodes that reference this media entity, then resolve those node URLs |
| `user` | **Skip** | No public URL. Output: "N/A — no public URL" |

If `user`, output the skip note and stop. For all other types, continue.

When the entity type does not have a direct public URL (`paragraph`, `taxonomy_term`, `media`), ask the user:

> "Do you have any additional information (e.g., a URL map file, a CSV export, a custom route, or a database table) that maps this content to its live URL? If not, I will fall back to the canonical `/node/{nid}` path of the referencing or parent node."

If the user provides a custom source (file, table, pattern), use it to resolve the URL. Otherwise, continue with the default parent/referencing node path strategy below and use `/node/{nid}` as the fallback URL if no alias is found.

### 1. Check for project-specific URL resolution

Read `.github/prompts/migrate-instructions.prompt.md`. If it defines a `## Live URL Resolution` section with a custom method (e.g., `endpoint`, `json_file`, `url_pattern`), **follow those instructions instead of the default steps below**.

If no custom method is defined, proceed with the **default Drupal path_alias strategy**.

---

### Default strategy — path alias table

#### Pre-check: pathauto module and alias table

Before querying for aliases, verify that path aliasing is actually available on this site.

**Step A — Check pathauto module is installed**

*Drupal 7:*
```sql
SELECT status
FROM system
WHERE name = 'pathauto'
  AND type = 'module';
```
`status = 1` → pathauto is enabled. Any other result → pathauto is absent.

*Drupal 8/9/10/11:*
```sql
SELECT value
FROM key_value
WHERE collection = 'system.schema'
  AND name = 'pathauto';
```
A non-empty row → pathauto is installed. No row → pathauto is absent.

> **If pathauto is absent**: aliases may still exist if they were created manually, but there is likely no auto-generated alias for most content. Proceed with the alias query below; if no alias is found, fall back to the canonical `/node/{nid}` path and note in the output that pathauto is not installed.

**Step B — Confirm the alias table exists**

*Drupal 7* uses `url_alias`. *Drupal 8+* uses `path_alias`. Confirm using:
```sql
SHOW TABLES LIKE 'path_alias';  -- D8+
SHOW TABLES LIKE 'url_alias';   -- D7
```
If neither table exists, skip alias resolution entirely and output canonical paths only.

---

#### 2. Select representative node IDs

**For `node` entity type** — pick one published node per bundle:

```sql
SELECT DISTINCT n.nid
FROM node_field_data n
WHERE n.type = '{node_bundle}'
  AND n.status = 1
ORDER BY n.nid ASC
LIMIT 1;
```

**For `paragraph` entity type** — use the parent node IDs already identified by `migrate-parent-context` / `migrate-verify-active`. Pick one published parent node per parent bundle.

**For `taxonomy_term` entity type** — find published nodes referencing this term:

```sql
-- First discover which node__field_* tables reference this vocabulary
SELECT TABLE_NAME
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_NAME LIKE 'node__field_%'
  AND COLUMN_NAME = '{field_name}_target_id';

-- Then find referencing nodes
SELECT DISTINCT n.nid, n.type
FROM node_field_data n
JOIN node__{field_name} f ON f.entity_id = n.nid
WHERE f.{field_name}_target_id IN (
  SELECT tid FROM taxonomy_term_field_data WHERE vid = '{bundle}' LIMIT 1
)
AND n.status = 1
LIMIT 3;
```

**For `media` entity type** — find published nodes referencing this media entity:

```sql
-- First discover which node__field_* tables have entity_reference to media
SELECT TABLE_NAME
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_NAME LIKE 'node__field_%'
  AND COLUMN_NAME LIKE '%_target_id';

-- Then find referencing nodes
SELECT DISTINCT n.nid, n.type
FROM node_field_data n
JOIN node__{field_name} f ON f.entity_id = n.nid
WHERE f.{field_name}_target_id IN (
  SELECT mid FROM media_field_data WHERE bundle = '{bundle}' LIMIT 1
)
AND n.status = 1
LIMIT 3;
```

> Prefer nodes with a clean path alias (i.e., an entry exists in `path_alias`).

#### 3. Resolve URL alias — version-specific query

The alias table schema differs between Drupal 7 and Drupal 8+. Use the version detected by `drupal-migrate-detect-version`.

**Drupal 8 / 9 / 10 / 11** — `path_alias` table:

```sql
SELECT alias
FROM path_alias
WHERE path = '/node/{nid}'
  AND langcode = 'it'
  AND status = 1
ORDER BY id DESC
LIMIT 1;
```

If no Italian alias found, retry with `langcode = 'en'`, then with any `langcode`. If still nothing, fall back to `/node/{nid}`.

> Note: In D8+, `path` always includes a leading slash (e.g. `/node/42`). The `status = 1` condition filters out inactive/deleted aliases.

**Drupal 7** — `url_alias` table:

```sql
SELECT alias
FROM url_alias
WHERE source = 'node/{nid}'
  AND language IN ('it', 'und')
ORDER BY pid DESC
LIMIT 1;
```

If no Italian alias found, retry with `language IN ('en', 'und')`, then `language = 'und'` alone. Fall back to `node/{nid}` (no leading slash in D7).

> Note: In D7, `source` has **no leading slash** (e.g. `node/42`). Use `'und'` for language-neutral aliases.

> **UUID query** (when needed): Always use `{base_table}`, not `{main_table}`:
> ```sql
> SELECT uuid FROM node WHERE nid = {nid};
> ```

#### 4. Build the full URL

Combine the **site base URL** (from project config, or ask the user if unknown) with the resolved alias:

```
{base_url}{alias}
```

Example: `https://www.example.com/path/to/page`

If no alias is resolved after 3 candidate node IDs, mark the entry as `URL not found` and continue.

---

### 5. Output

Return a table for inclusion in the analysis report:

| Node type | Node ID | URL |
|---|---|---|
| `page` | 42 | `https://www.example.com/path/to/page` |
| `article` | 187 | `https://www.example.com/path/to/article` |

For `paragraph`, `taxonomy_term`, and `media` entities, the table shows the **parent/referencing node**, not the entity itself. Add a note clarifying:
> "URLs resolved via parent/referencing nodes (entity type `{entity_type}` has no direct public URL)"

This table populates the **Live examples** section of the Source Analysis Report (without the Screenshot column, which is filled by `migrate-live-screenshots`).

If this skill ran automatically inside a larger source-analysis workflow, present the table directly as part of that report instead of treating it as a separate deliverable.

---

## Error Handling

- **`path_alias` / `url_alias` table missing**: Fall back to canonical paths (`/node/{nid}` for D8+, `node/{nid}` for D7). Note the fallback in the output.
- **pathauto not installed**: Aliases may still exist from manual creation. Proceed with the query; if no alias is found, fall back to the canonical path and note the absence of pathauto.
- **No alias found after 3 attempts**: Mark entry as `URL not found`. Do not block the analysis.
- **Base URL unknown**: Ask the user once: _"What is the base URL of the production source site?"_
- **No active parent nodes**: Skip URL resolution for that bundle and note it in the output.
- **No referencing nodes found** (taxonomy_term/media): Note "No published nodes reference this entity" and continue.
