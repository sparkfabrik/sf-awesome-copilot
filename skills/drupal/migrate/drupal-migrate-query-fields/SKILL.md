---
name: drupal-migrate-query-fields
description: Query source entity fields from the migration database. Supports both Drupal 7 (field_config_instance) and Drupal 8+ (config table) patterns. Produces a structured field list with label, machine name, type, cardinality, required, and translatable.
---

# Query Source Entity Fields

Extract field definitions for a specific entity bundle from the source migration database.

---

## Project Configuration

Before executing, check for a project-specific configuration file at:
`.github/prompts/migrate-instructions.prompt.md`

If it exists, read the **Database Connection** section for the drush database option and any custom table names.

---

## Prerequisites

- Source database connection verified (`migrate-db-discover`)
- Source Drupal version detected (`migrate-detect-version`)

---

## Input

- **entity_type**: `node`, `paragraph`, `taxonomy_term`, or `user`
- **bundle**: The bundle machine name
- **source_version**: `drupal7` or `drupal8+`

---

## Entity-Type Context

Before running any query, resolve entity-type-specific variables from:
**`.github/prompts/drupal-migrate-entity-type-context.prompt.md`**

Use `{main_table}`, `{base_table}`, `{id_column}`, `{field_data_prefix}`, `{config_prefix}`, and `{storage_prefix}` from that reference.

> **UUID location**: UUIDs are always in `{base_table}`, **never** in `{main_table}`.

---

## Steps

### Step 0 — Enumerate base fields

Before querying configurable fields, list the **base fields** for the entity type from the
Entity-Type Context reference (`.github/prompts/drupal-migrate-entity-type-context.prompt.md`, section "Base Fields Per Entity Type").

Include these in the field report with:
- Population: `100%` (base fields always exist)
- Required: `✓`
- Translatable: per entity type (typically `✓` for node title, `✗` for IDs)
- Cardinality: `1`

### Step 1 — Query field configs

**Drupal 8+** — Fetch field instance configs:
```sql
SELECT name, data FROM config
WHERE name LIKE CONCAT('field.field.', '{entity_type}', '.', '{bundle}', '.%')
ORDER BY name;
```

Parse the PHP-serialized `data` to extract:
- `label` (`s:5:"label";s:N:"..."`)
- `required` (`s:8:"required";b:1`)
- `translatable` (`s:12:"translatable";b:1`)

Then fetch field storage configs for type and cardinality:
```sql
SELECT name, data FROM config
WHERE name IN (
  SELECT CONCAT('field.storage.', '{entity_type}', '.', SUBSTRING_INDEX(name, '.', -1))
  FROM config
  WHERE name LIKE CONCAT('field.field.', '{entity_type}', '.', '{bundle}', '.%')
)
ORDER BY name;
```

Parse to extract:
- `field_type` (from storage: `s:4:"type";s:N:"..."`)
- `cardinality` (from storage: `s:11:"cardinality";i:1` or `i:-1`)

**Drupal 7** — Fetch from field_config tables:
```sql
SELECT
  fci.field_name,
  fci.label,
  fcs.type         AS field_type,
  fcs.cardinality,
  fci.required,
  fcs.translatable
FROM field_config_instance fci
JOIN field_config fcs ON fci.field_name = fcs.field_name
WHERE fci.entity_type = '{entity_type}'
  AND fci.bundle      = '{bundle}'
  AND fci.deleted = 0
  AND fcs.deleted = 0
ORDER BY fci.field_name;
```

### Step 2 — Cross-check with INFORMATION_SCHEMA (fallback)

If parsing serialized data is ambiguous, verify field types by inspecting column names:

```sql
SELECT
  REPLACE(TABLE_NAME, CONCAT('{entity_type}', '__'), '') AS field_name,
  GROUP_CONCAT(COLUMN_NAME ORDER BY ORDINAL_POSITION SEPARATOR ', ') AS value_columns
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_NAME LIKE CONCAT('{entity_type}', '__field_%')
  AND COLUMN_NAME NOT IN ('bundle','deleted','entity_id','revision_id','langcode','delta')
GROUP BY TABLE_NAME
ORDER BY TABLE_NAME;
```

Use column suffix patterns to infer types:

| Suffix(es) | Field type |
|---|---|
| `_value` only | `string` / `text_long` |
| `_value` + `_format` | `text_formatted_long` |
| `_target_id` + `_target_revision_id` | `entity_reference_revisions` |
| `_target_id` only | `entity_reference` |
| `_uri` + `_title` + `_options` | `link` |
| `_target_id` + `_alt` + `_width` + `_height` | `image` |
| `_value` (boolean storage) | `boolean` |

### Step 3 — Report results

Output the structured field table:

```
#### Source fields — `{bundle}`

| Label | Machine name | Field type | Cardinality | Required | Translatable |
|---|---|---|---|---|---|
| Title | `field_p_title` | string | 1 | ✓ | ✓ |
| Body | `field_p_body` | text_formatted_long | 1 | | ✓ |
| Items | `field_items` | entity_reference_revisions | -1 | | |
```

- Use `✓` for Required/Translatable when true; leave blank otherwise
- Cardinality: use numeric value (`1`, `3`, …) or `unlimited` for `-1`

---

## Output

- **fields**: List of field objects with:
  - `label`, `machine_name`, `field_type`, `cardinality`, `required`, `translatable`

---

## Guardrails

- Support both D7 and D8+ query patterns
- If config table parsing fails, fall back to INFORMATION_SCHEMA column inspection
- Report ALL fields, including entity reference and revision fields — these are important for understanding data relationships
- Do not skip fields even if their type cannot be fully determined — report them with a "unknown" type note
