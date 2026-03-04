---
name: drupal-migrate-resolve-examples
description: Resolve live URLs for example nodes from the source Drupal database — one representative node per parent bundle. Compulsory step in every full source analysis. Does NOT take screenshots (use migrate-live-screenshots for that).
---

# migrate-resolve-examples

Resolves at least one representative live URL per parent node bundle for a given source paragraph (or entity) bundle. This is a **required, automatic step** — no user confirmation needed.

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

### 1. Check for project-specific URL resolution

Read `.github/prompts/migrate-instructions.prompt.md`. If it defines a `## Live URL Resolution` section with a custom method (e.g., `endpoint`, `json_file`, `url_pattern`), **follow those instructions instead of the default steps below**.

If no custom method is defined, proceed with the **default Drupal path_alias strategy**.

---

### Default strategy — Drupal `path_alias` table

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

#### 3. Resolve URL alias from `path_alias`

```sql
SELECT alias
FROM path_alias
WHERE path = '/node/{nid}'
  AND langcode = 'it'
ORDER BY id DESC
LIMIT 1;
```

If no Italian alias found, retry with `langcode = 'en'`, then fall back to the canonical path `/node/{nid}`.

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
| `luisspage` | 42 | `https://www.example.com/path/to/page` |
| `corso` | 187 | `https://www.example.com/path/to/corso` |

For `paragraph`, `taxonomy_term`, and `media` entities, the table shows the **parent/referencing node**, not the entity itself. Add a note clarifying:
> "URLs resolved via parent/referencing nodes (entity type `{entity_type}` has no direct public URL)"

This table populates the **Live examples** section of the Source Analysis Report (without the Screenshot column, which is filled by `migrate-live-screenshots`).

---

## Error Handling

- **`path_alias` table missing**: Fall back to canonical `/node/{nid}` paths. Note the fallback in the output.
- **No alias found after 3 attempts**: Mark entry as `URL not found`. Do not block the analysis.
- **Base URL unknown**: Ask the user once: _"What is the base URL of the production source site?"_
- **No active parent nodes**: Skip URL resolution for that bundle and note it in the output.
- **No referencing nodes found** (taxonomy_term/media): Note "No published nodes reference this entity" and continue.
