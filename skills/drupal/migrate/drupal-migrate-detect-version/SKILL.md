---
name: drupal-migrate-detect-version
description: 'Detect the Drupal major version of a source migration database and choose the correct follow-up query strategy. Use after source DB discovery, or whenever a migration task needs to know whether the source is Drupal 7 or Drupal 8/9/10 before running schema-specific analysis.'
---

# Detect Source Drupal Version

Determine whether the source migration database is Drupal 7 or Drupal 8+ so
later migration queries use the right tables and assumptions.

The goal is not just to guess a version label. The important outcome is a
trustworthy detection report with the evidence you used and the next query
strategy the user should follow.

---

## Project configuration

Before executing, check for a project-specific configuration file at:
`.github/prompts/migrate-instructions.prompt.md`

If it exists, read the **Database Connection** section and prefer:
- the configured database key
- the configured drush database option
- any notes about non-standard schemas or containers

If it does not exist, use these defaults:
- **Database key**: `migrate`
- **Drush option**: `--database=migrate`

---

## Prerequisites

- Source database connection already discovered or confirmed
  (`drupal-migrate-db-discover`)
- A working drush database option for the source database

If the source connection has not been verified yet, stop and run
`drupal-migrate-db-discover` first.

---

## Input

- **db_key**: Source database key, if already known
- **drush_option**: Drush option for the source database
- **schema_hint**: Optional schema name from project notes, if the project does
  not use the active database selected by `drush`

---

## Detection summary

Use this mapping when interpreting the database signatures:

| Evidence found | Reported version | Follow-up field strategy |
|---|---|---|
| `field_config_instance` or `field_config` | `drupal7` | `field_config_instance` |
| `config` | `drupal8+` | `config_table` |
| Neither signature | `unknown` | `manual_confirmation_required` |

If both Drupal 7 and Drupal 8+ signatures appear, treat the result as
`unknown` and explain the conflict instead of guessing.

---

## Steps

### Step 1 - Resolve connection details

Read `.github/prompts/migrate-instructions.prompt.md` if present and resolve the
database option you will use for all queries.

Prefer the explicit `drush_option` from the previous discovery step. If it is
missing but the database key is known, build it as `--database={db_key}`.

### Step 2 - Verify the source database is reachable

Run a quick connectivity check before inspecting tables:

```bash
docker compose run --rm drupal-tools ash -c "drush sql:query {drush_option} 'SELECT 1 AS connection_ok;'"
```

If this fails, report the database error and stop. Do not continue with version
detection against an unverified connection.

### Step 3 - Query version signatures

Run one query that reports the presence of the key tables:

```sql
SELECT
  MAX(CASE WHEN TABLE_NAME = 'field_config_instance' THEN 1 ELSE 0 END) AS has_field_config_instance,
  MAX(CASE WHEN TABLE_NAME = 'field_config' THEN 1 ELSE 0 END) AS has_field_config,
  MAX(CASE WHEN TABLE_NAME = 'config' THEN 1 ELSE 0 END) AS has_config
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = COALESCE(NULLIF('{schema_hint}', ''), DATABASE())
  AND TABLE_NAME IN ('field_config_instance', 'field_config', 'config');
```

Execute it via:

```bash
docker compose run --rm drupal-tools ash -c "drush sql:query {drush_option} \"SELECT MAX(CASE WHEN TABLE_NAME = 'field_config_instance' THEN 1 ELSE 0 END) AS has_field_config_instance, MAX(CASE WHEN TABLE_NAME = 'field_config' THEN 1 ELSE 0 END) AS has_field_config, MAX(CASE WHEN TABLE_NAME = 'config' THEN 1 ELSE 0 END) AS has_config FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = COALESCE(NULLIF('{schema_hint}', ''), DATABASE()) AND TABLE_NAME IN ('field_config_instance', 'field_config', 'config');\""
```

### Step 4 - Classify the result

Interpret the result in this order:

1. If `has_config = 1` and neither Drupal 7 table exists, report
   `source_version: drupal8+`
2. If either `has_field_config_instance = 1` or `has_field_config = 1`, and
   `has_config = 0`, report `source_version: drupal7`
3. If both Drupal 7 and Drupal 8+ signatures exist, report
   `source_version: unknown` with a note about conflicting signatures
4. If none of the signatures exist, report `source_version: unknown`

Set `field_query_strategy` to:
- `field_config_instance` for Drupal 7
- `config_table` for Drupal 8+
- `manual_confirmation_required` for `unknown`

### Step 5 - Refine Drupal 8+ when useful

If the result is `drupal8+`, you may try to identify the likely major version,
but only if the evidence is explicit.

Useful follow-up query:

```sql
SELECT name, data
FROM config
WHERE name IN ('core.extension', 'system.site')
ORDER BY name;
```

Inspect the returned serialized data for explicit version clues such as
`core_version_requirement` values like `^8`, `^9`, or `^10`.

If the data does not clearly identify the major version, keep the result as
`drupal8+`. Do not overstate it as Drupal 9 or Drupal 10 without direct
evidence.

### Step 6 - Report the result in a structured migration note

Always return a compact structured report like this:

```text
### Source Drupal version detection
- Source version: `drupal7`
- Follow-up field strategy: `field_config_instance`
- Confidence: high
- Evidence:
  - `field_config_instance` table found
  - `field_config` table found
  - `config` table not found
- Command used: `docker compose run --rm drupal-tools ash -c "drush sql:query --database=migrate ..."`
- Next step: run `drupal-migrate-query-fields` with `source_version=drupal7`
```

For `unknown`, use this structure:

```text
### Source Drupal version detection
- Source version: `unknown`
- Follow-up field strategy: `manual_confirmation_required`
- Confidence: low
- Evidence:
  - `field_config_instance` table not found
  - `field_config` table not found
  - `config` table not found
- Warning: could not match the database to a standard Drupal 7 or Drupal 8+ schema
- Next step: ask the user to confirm the source system and database selection before continuing
```

Then stop and ask the user for confirmation before continuing with any
schema-specific migration analysis.

---

## Output

This skill should produce:

- **source_version**: `drupal7`, `drupal8+`, or `unknown`
- **field_query_strategy**: `field_config_instance`, `config_table`, or
  `manual_confirmation_required`
- **confidence**: `high`, `medium`, or `low`
- **evidence**: Short list of detected or missing table signatures
- **next_step**: Recommended follow-up action

---

## Guardrails

- Always use `drush sql:query`; do not use `mysql` directly
- Prefer `DATABASE()` unless the project explicitly requires another schema
- Do not claim Drupal 8, 9, or 10 specifically unless the config data supports
  it
- If signatures conflict, treat the result as `unknown` and explain why
- This skill only detects the source version and the correct follow-up strategy;
  it does not inspect field definitions or data population
