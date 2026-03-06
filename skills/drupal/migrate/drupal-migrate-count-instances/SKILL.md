---
name: drupal-migrate-count-instances
description: Count entity instances in the source migration database using revision-safe queries. Use when you need to know how many nodes, paragraphs, taxonomy terms, or users of a specific bundle exist. Always uses COUNT(DISTINCT) to avoid inflated counts from revisions.
---

# Count Source Entity Instances

Count entity instances in the source database using revision-safe `COUNT(DISTINCT)` queries.

---

## Prerequisites

- Source database connection verified (`migrate-db-discover`)
- Source Drupal version detected (`migrate-detect-version`)

---

## Input

- **entity_type**: `node`, `paragraph`, `taxonomy_term`, or `user`
- **bundle**: The machine name of the bundle (e.g., `luisspage`, `simple_text_with_title`, `news_tag`)

If the entity type is not specified, infer it from the bundle name:
- If the name matches known node type patterns, assume `node`
- If it contains words like `group`, `modal`, `card`, `person`, `text`, `banner`, assume `paragraph`
- If still ambiguous, ask the user

---

## Entity-Type Context

Before running any query, resolve entity-type-specific variables from:
**`.github/prompts/drupal-migrate-entity-type-context.prompt.md`**

Use `{main_table}`, `{id_column}`, `{bundle_column}`, and `{status_column}` from that reference.

---

## Steps

### Step 1 — Determine the main table

| Entity type | Main table (D8+) | Main table (D7) | ID column | Bundle column |
|---|---|---|---|---|
| `node` | `node_field_data` | `node` | `nid` | `type` |
| `paragraph` | `paragraphs_item_field_data` | `paragraphs_item` | `id` (D8+), `item_id` (D7) | `type` |
| `taxonomy_term` | `taxonomy_term_field_data` | `taxonomy_term_data` | `tid` | `vid` |
| `media` | `media_field_data` | — | `mid` | `bundle` |
| `user` | `users_field_data` | `users` | `uid` | — |

Check the project config (`.github/prompts/migrate-instructions.prompt.md`) for any custom table name overrides.

If the query fails, check for similarly named tables:
```sql
SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_NAME LIKE '%{entity_type}%'
ORDER BY TABLE_NAME;
```

### Step 2 — Count total instances

**Drupal 8+:**
```sql
SELECT {bundle_column}, COUNT(DISTINCT {id_column}) AS instances
FROM {main_table}
WHERE {bundle_column} = '{bundle}'
GROUP BY {bundle_column};
```

**Drupal 7 (nodes):**
```sql
SELECT type, COUNT(DISTINCT nid) AS instances
FROM node
WHERE type = '{bundle}'
GROUP BY type;
```

**Drupal 7 (taxonomy terms):**
```sql
SELECT v.name AS vocabulary, COUNT(DISTINCT td.tid) AS instances
FROM taxonomy_term_data td
JOIN taxonomy_vocabulary v ON td.vid = v.vid
WHERE v.machine_name = '{bundle}'
GROUP BY v.name;
```

### Step 2b — Count active (published) instances

For entity types that have a `{status_column}` (node, taxonomy_term, media, user), count active instances:

```sql
SELECT COUNT(DISTINCT {id_column}) AS active_instances
FROM {main_table}
WHERE {bundle_column} = '{bundle}'
  AND {status_column} = 1;
```

> **Paragraphs** do not have a meaningful status column. Active/orphaned counts for paragraphs are determined by `migrate-verify-active` instead.

### Step 3 — Report results

Output:

```
Entity: {entity_type}.{bundle}
Total instances (revision-safe): {count}
Active (published) instances: {active_count}
```

If count is 0:
> "⚠️ No instances of `{entity_type}.{bundle}` found in the source database. Verify the bundle name is correct."

---

## Output

- **entity_type**: The entity type queried
- **bundle**: The bundle name
- **instance_count**: The revision-safe count
- **id_column**: The column used for DISTINCT counting

---

## Guardrails

- **NEVER use `COUNT(*)`** — always use `COUNT(DISTINCT {id_column})` to avoid inflated counts from revisions and language variants
- `paragraphs_item_field_data` contains one row per entity × revision × language — `COUNT(*)` can inflate counts 5–70×
- If the table doesn't exist, try alternative table names and inform the user
- Run queries via `drush sql:query` with the appropriate database option
