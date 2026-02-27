---
name: migrate-field-population
description: Measure field population percentages for a source entity bundle. For each field, counts how many active instances actually contain data. Fields at 0% are non-migration candidates. Use after querying fields with migrate-query-fields.
---

# Measure Field Population

For each field on a source bundle, measure what percentage of active instances actually contain data.

---

## Project Configuration

Before executing, check for a project-specific configuration file at:
`.github/prompts/migrate-instructions.prompt.md`

If it exists, read the **Database Connection** section for the drush database option and any custom table names.

---

## Prerequisites

- Source database connection verified (`migrate-db-discover`)
- Fields queried (`migrate-query-fields`)
- For paragraphs: active instance count from `migrate-verify-active`

---

## Input

- **entity_type**: `node`, `paragraph`, `taxonomy_term`, or `user`
- **bundle**: The bundle machine name
- **fields**: List of field machine names (from `migrate-query-fields`)
- **active_instances**: Count of active instances (from `migrate-verify-active` for paragraphs, or `migrate-count-instances` for others)

---

## Entity-Type Context

Before running any query, resolve entity-type-specific variables from:
**`.github/prompts/entity-type-context.prompt.md`**

Use `{main_table}`, `{id_column}`, `{bundle_column}`, and `{field_data_prefix}` from that reference.

---

## Steps

### Step 1 — Query population for each field

For each field, determine the value column based on its type, then count populated rows.

**Parameterized query (all entity types, D8+):**
```sql
SELECT
  COUNT(DISTINCT m.{id_column}) AS total_instances,
  SUM(f.{field_name}_{value_suffix} IS NOT NULL) AS populated
FROM {main_table} m
LEFT JOIN {field_data_prefix}{field_name} f ON f.entity_id = m.{id_column}
WHERE m.{bundle_column} = '{bundle}';
```

Replace `{value_suffix}` based on field type:
- **Text / string / boolean**: `_value`
- **Entity reference**: `_target_id`
- **Link**: `_uri`
- **Image**: `_target_id`
- **Entity reference revisions**: `_target_id`

See `.github/prompts/entity-type-context.prompt.md` → "Value Column Suffix Patterns" for full list.

> **Important**: Use `entity_id` only in the JOIN (not `revision_id`) to avoid false negatives from revision mismatches.

**Batch optimization** — when querying many fields, combine into a single query:
```sql
SELECT
  COUNT(DISTINCT m.{id_column}) AS total_instances,
  SUM(f1.{field1}_{suffix} IS NOT NULL) AS pop_field1,
  SUM(f2.{field2}_{suffix} IS NOT NULL) AS pop_field2
FROM {main_table} m
LEFT JOIN {field_data_prefix}{field1} f1 ON f1.entity_id = m.{id_column}
LEFT JOIN {field_data_prefix}{field2} f2 ON f2.entity_id = m.{id_column}
WHERE m.{bundle_column} = '{bundle}';
```

> ⚠️ Batch only works well for up to ~5 fields at a time — beyond that, MySQL may produce cartesian explosion on multi-value fields. Split into groups of 3-5.

### Step 2 — Compute percentages

For each field:
```
population_pct = ROUND(populated / active_instances * 100)
```

**Denominator choice:**
- For `paragraph`: use active count from `migrate-verify-active` (not total from `migrate-count-instances`)
- For `node`, `taxonomy_term`, `media`, `user`: use total from `migrate-count-instances`

### Step 3 — Report results

Add a **Population** column to the field table:

```
#### Field population — `{bundle}` ({active_instances} active instances)

| Field | Population |
|---|---|
| `field_p_title` | 100% |
| `field_p_email` | ~48% |
| `field_p_linkedin` | 0% |
```

Flag 0% fields:
> "Fields at 0% population are non-migration candidates and should be explicitly excluded."

---

## Output

- **field_populations**: List of (field_name, populated_count, total_count, percentage)
- **zero_population_fields**: Fields with 0% that are candidates for exclusion

---

## Guardrails

- Use `entity_id` only (not `revision_id`) in LEFT JOINs to avoid false negatives
- Choose the correct value column based on field type (`_value`, `_target_id`, `_uri`, etc.)
- Run population queries in parallel where possible to minimise elapsed time
- If a field table doesn't exist, report it as "table not found" rather than failing
- Use `~` prefix for percentages that are not exact (e.g., `~48%`)
