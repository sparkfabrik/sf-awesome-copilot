---
name: drupal-migrate-db-discover
description: 'Always run at the start of any Drupal migration analysis, or whenever the source database connection needs to be verified. This is the foundational step — 8 downstream migration skills depend on the db_key and drush_option it produces. Discovers the non-default database key in settings.php, tests connectivity via drush, and produces the connection details used by all subsequent migration skills. Use when starting a migration, when the user asks to "check the source database", "verify the db connection", or "set up the migration database".'
---

# Discover Source Database Connection

Find and validate the source Drupal database connection used for content migration.
This is the **first skill to run** in any migration workflow. All other migration
skills that query the source database depend on the outputs this skill produces.

---

## Project configuration

Before executing, check for a project-specific configuration file at:
`.github/prompts/migrate-instructions.prompt.md`

If it exists, read the **Database Connection** section and prefer:
- the configured database key
- the configured drush database option
- any notes about non-standard container names, shells, or settings file paths

If it does not exist, use the defaults documented below.

---

## Defaults

- **Database key**: `migrate` (Drupal convention)
- **Drush option**: `--database=migrate`
- **Container name**: `drupal-tools`
- **Container shell**: `ash` (Alpine Linux)
- **Settings files to check** (in order):
  1. `src/drupal/web/sites/default/settings.local.php`
  2. `src/drupal/web/sites/default/settings.php`

---

## Prerequisites

- Docker Compose stack configured with a container that provides drush
- `settings.local.php` or `settings.php` containing at least one non-default `$databases` entry for the source

This skill has no upstream skill dependencies — it is the starting point for all migration analysis.

---

## Input

This skill reads its configuration from:
- `.github/prompts/migrate-instructions.prompt.md` — project-specific overrides (optional)
- `src/drupal/web/sites/default/settings.local.php` / `settings.php` — Drupal database configuration

---

## Steps

### Step 1 — Check project configuration

Read `.github/prompts/migrate-instructions.prompt.md` if it exists. Extract:
- Database key name (e.g., `drupal_migrate`)
- Drush database option (e.g., `--database=drupal_migrate`)
- Container name override (e.g., `drupal` instead of `drupal-tools`)
- Shell override (e.g., `bash` instead of `ash`)
- Any special connection notes

If the file does not exist, use all defaults from the **Defaults** section above.

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
- Any key that is NOT `default` (the `default` key is always the local Drupal site database)

**MANDATORY**: If multiple non-default database keys are found, list all of them and
**always ask the user to confirm** which one is the migration source. Never infer
the correct key from PHP comments, naming conventions, or your own judgment. Wait
for explicit user confirmation before proceeding to Step 3.

If no non-default key is found, report this to the user and stop.

### Step 3 — Test connectivity

Use the container name and shell resolved in Step 1 (defaults: `drupal-tools`, `ash`):

```bash
docker compose run --rm {container} {shell} -c "drush sql:query --database={db_key} 'SELECT 1'"
```

Replace `{container}`, `{shell}`, and `{db_key}` with the values from Step 1.

### Step 4 — Report results

**If connection succeeds**, output:

```
✅ Source database connection verified
- Database key:              {db_key}
- Drush option:              --database={db_key}
- Connection status:         connected
- Connection command:        docker compose run --rm {container} {shell} -c "drush sql:query --database={db_key} 'YOUR_QUERY'"
```

**If connection fails**, report the error clearly:
> ❌ The source database connection failed. Please check the database configuration in settings.php.
> Error: `{error_message}`

Then **STOP** — do not attempt any migration analysis until the database is reachable.
Ask the user to fix the connection and then re-run this skill.

---

## Output

This skill produces:
- **db_key**: The database key name (e.g., `migrate`)
- **drush_option**: The drush CLI option (e.g., `--database=migrate`)
- **connection_command_template**: Full template for running queries against the source DB
- **connection_status**: `connected` or `failed`

These outputs are consumed by all downstream migration skills.

---

## Guardrails

- **Never use `mysql` directly** — always use `drush sql:query` with the `--database` option
- **Always ask the user** to confirm the database key when multiple non-default keys exist — do not infer it from PHP comments or key names
- If settings files are not found at the default paths, ask the user for the correct location before proceeding
- Do not attempt to modify any settings file
- Do not proceed with any migration analysis if the connection test fails
