---
name: drupal-migrate-db-discover
description: Discover and validate the source Drupal database connection for migration. Use when starting any migration analysis, or when you need to verify the source database is reachable. Checks settings.php for database configuration and tests connectivity.
---

# Discover Source Database Connection

Find and validate the source Drupal database connection used for content migration.

---

## Project Configuration

Before executing, check for a project-specific configuration file at:
`.github/prompts/migrate-instructions.prompt.md`

If it exists, read the **Database Connection** section and use the provided values.
If it does not exist, use the defaults documented below.

---

## Defaults

- **Database key**: `migrate` (Drupal convention)
- **Drush option**: `--database=migrate`
- **Settings files to check** (in order):
  1. `src/drupal/web/sites/default/settings.local.php`
  2. `src/drupal/web/sites/default/settings.php`

---

## Steps

### Step 1 — Check project configuration

Read `.github/prompts/migrate-instructions.prompt.md` if it exists. Extract:
- Database key name (e.g., `drupal_migrate`)
- Drush database option (e.g., `--database=drupal_migrate`)
- Any special connection notes

### Step 2 — Scan settings files

Search for the `$databases` array entries that define the source database:

```bash
grep -n "databases\[" src/drupal/web/sites/default/settings.local.php 2>/dev/null
grep -n "databases\[" src/drupal/web/sites/default/settings.php 2>/dev/null
```

Look for patterns like:
- `$databases['migrate']`
- `$databases['drupal_migrate']`
- `$databases['source']`
- Any key that is NOT `default` (the default key is the local Drupal database)

If multiple non-default database keys are found, list them and ask the user which one is the source migration database.

### Step 3 — Test connectivity

Test the connection using drush:

```bash
docker compose run --rm drupal-tools ash -c "drush sql:query --database={db_key} 'SELECT 1'"
```

Replace `{db_key}` with the discovered or configured database key.

### Step 4 — Report results

**If connection succeeds**, output:

```
✅ Source database connection verified
- Database key: {db_key}
- Drush option: --database={db_key}
- Connection command: docker compose run --rm drupal-tools ash -c "drush sql:query --database={db_key} 'YOUR_QUERY'"
```

**If connection fails**, report the error and ask the user:
> "The source database connection failed. Please check the database configuration in settings.php. Error: {error_message}"

Then **STOP** — do not proceed with analysis until the database is reachable.

---

## Output

This skill produces:
- **db_key**: The database key name (e.g., `drupal_migrate`)
- **drush_option**: The drush CLI option (e.g., `--database=drupal_migrate`)
- **connection_command_template**: Template for running queries against the source DB
- **connection_status**: `connected` or `failed`

---

## Guardrails

- **Never use `mysql` directly** — always use `drush sql:query` with the database option
- If settings files are not found, ask the user for the database connection details
- If multiple non-default database keys exist, ask the user to confirm which one to use
- Do not attempt to modify settings.php
