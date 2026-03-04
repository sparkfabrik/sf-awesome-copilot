---
name: drupal-migrate-detect-version
description: Detect the Drupal version of the source migration database (Drupal 7, 8, 9, or 10). Use after discovering the database connection with migrate-db-discover. Checks for version-specific table signatures.
---

# Detect Source Drupal Version

Determine whether the source migration database is Drupal 7 or Drupal 8+ by checking for version-specific table signatures.

---

## Prerequisites

- Source database connection must be verified (use `migrate-db-discover` skill first)
- You need the `db_key` and `drush_option` from the discovery step

---

## Steps

### Step 1 — Read project configuration

Check `.github/prompts/migrate-instructions.prompt.md` for the database key and schema name.
Use the `drush_option` from `migrate-db-discover` output.

### Step 2 — Query for version-specific tables

Run the following query against the source database:

```sql
SELECT IF(
  EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'field_config_instance'),
  'drupal7',
  IF(EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'config'), 'drupal8+', 'unknown')
) AS source_version;
```

Execute via:
```bash
docker compose run --rm drupal-tools ash -c "drush sql:query {drush_option} \"SELECT IF(EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'field_config_instance'), 'drupal7', IF(EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'config'), 'drupal8plus', 'unknown')) AS source_version;\""
```

### Step 3 — Determine specific version (optional, Drupal 8+ only)

If the source is Drupal 8+, you can further identify the major version:

```sql
SELECT data FROM config WHERE name = 'core.extension' LIMIT 1;
```

The `core_version_requirement` in the serialized data indicates D8 (`^8`), D9 (`^9`), or D10 (`^10`).

Alternatively, check the `system` config:
```sql
SELECT data FROM config WHERE name = 'system.site' LIMIT 1;
```

### Step 4 — Report results

Output:

```
Source Drupal version: {version}
- Drupal 7: field_config_instance + field_config tables for field metadata
- Drupal 8+: config table with PHP-serialized field configs
```

If `unknown`, warn:
> "⚠️ Could not detect Drupal version — neither `field_config_instance` (D7) nor `config` (D8+) tables were found. This may not be a standard Drupal database."

Then **STOP** and ask the user to confirm the source system.

---

## Output

- **source_version**: `drupal7`, `drupal8+`, or `unknown`
- **field_query_strategy**: `field_config_instance` (D7) or `config_table` (D8+)

---

## Guardrails

- This skill only detects the version — it does not query field data
- If version is unknown, stop and ask the user for clarification
- Use `DATABASE()` function instead of hard-coding the schema name when possible
