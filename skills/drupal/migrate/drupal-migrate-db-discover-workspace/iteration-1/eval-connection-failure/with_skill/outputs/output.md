# Drupal Migration DB Discover — Evaluation Output

**Task**: Diagnose a `drush sql:query` connection error to the source migration database.  
**Skill used**: `drupal-migrate-db-discover`  
**Working directory**: `skills/drupal/migrate/drupal-migrate-db-discover-workspace/mock-project`

---

## Step 1 — Check project configuration

Checked for `.github/prompts/migrate-instructions.prompt.md`:

```
NOT FOUND
```

No project-specific configuration file found. Proceeding with skill defaults:
- **Database key**: `migrate`
- **Drush option**: `--database=migrate`
- **Settings files to check** (in order):
  1. `src/drupal/web/sites/default/settings.local.php`
  2. `src/drupal/web/sites/default/settings.php`

---

## Step 2 — Scan settings files

### Command run:

```bash
grep -n "databases\[" src/drupal/web/sites/default/settings.local.php 2>/dev/null
grep -n "databases\[" src/drupal/web/sites/default/settings.php 2>/dev/null
```

### Output:

```
=== settings.local.php ===
9:$databases['default']['default'] = [
21:$databases['migrate']['default'] = [
33:$databases['legacy_drupal']['default'] = [

=== settings.php ===
(file not found or no match)
```

### Full contents of `settings.local.php`:

```php
<?php

// Default (local) database.
$databases['default']['default'] = [
  'driver' => 'mysql',
  'database' => 'drupal',
  'username' => 'drupal',
  'password' => 'drupal',
  'host' => 'db',
  'port' => '3306',
  'prefix' => '',
  'namespace' => 'Drupal\\Core\\Database\\Driver\\mysql',
];

// Source migration database (Drupal 7 source site).
$databases['migrate']['default'] = [
  'driver' => 'mysql',
  'database' => 'drupal7_source',
  'username' => 'migrate_user',
  'password' => 'migrate_pass',
  'host' => 'source-db',
  'port' => '3306',
  'prefix' => '',
  'namespace' => 'Drupal\\Core\\Database\\Driver\\mysql',
];

// Legacy staging database (kept for reference, NOT the migration source).
$databases['legacy_drupal']['default'] = [
  'driver' => 'mysql',
  'database' => 'old_drupal_staging',
  'username' => 'reader',
  'password' => 'reader123',
  'host' => 'legacy-db',
  'port' => '3306',
  'prefix' => '',
  'namespace' => 'Drupal\\Core\\Database\\Driver\\mysql',
];
```

### Analysis:

Two non-default database keys found:

| Key             | Host        | Database            | Username       | Note                                      |
|-----------------|-------------|---------------------|----------------|-------------------------------------------|
| `migrate`       | `source-db` | `drupal7_source`    | `migrate_user` | Labelled "Source migration database" ✅   |
| `legacy_drupal` | `legacy-db` | `old_drupal_staging`| `reader`       | Labelled "NOT the migration source" ❌    |

The comment in settings.local.php clearly identifies `migrate` as the intended source. This also matches the skill's default key convention. Proceeding with `--database=migrate`.

---

## Step 3 — Test connectivity

### Command run:

```bash
docker compose run --rm drupal-tools ash -c "drush sql:query --database=migrate 'SELECT 1'"
```

### Output:

```
no configuration file provided: not found
```

**Connection failed.** No `docker-compose.yml` / `compose.yaml` is present in the project root — the Docker Compose stack cannot be started.

---

## Step 4 — Report results (connection failure path)

> ❌ **The source database connection failed. Please check the database configuration in settings.php.**
>
> **Error**: `no configuration file provided: not found`

---

## Summary of findings

The `drush sql:query` command is failing because **Docker Compose cannot find a `docker-compose.yml` (or `compose.yaml`) configuration file** in the project root. This means the `drupal-tools` service — which provides the Drush binary — cannot be started at all, so the command never reaches the database.

The database configuration itself (in `settings.local.php`) looks structurally correct for the `migrate` key:

- **Host**: `source-db` — this is a Docker service name; it will only be resolvable inside the Compose network
- **Database**: `drupal7_source`
- **Username / Password**: `migrate_user` / `migrate_pass`
- **Port**: `3306`

### What to check next (for the user to resolve)

1. **Missing `docker-compose.yml`** — Ensure a Compose file exists and defines both `drupal-tools` and `source-db` services. Without it nothing can run.
2. **`source-db` service reachability** — Once the Compose file is in place, confirm the `source-db` service is running and the `migrate_user` credentials are valid.
3. **Network membership** — `drupal-tools` and `source-db` must be on the same Compose network for the hostname `source-db` to resolve.

---

> ⛔ **STOP** — per skill guardrails, no further migration analysis will proceed until the database connection is confirmed reachable.
>
> **Next step for the user**: Provide or restore the `docker-compose.yml` file for this project, bring up the stack (`docker compose up -d`), and then re-run the connectivity test:
>
> ```bash
> docker compose run --rm drupal-tools ash -c "drush sql:query --database=migrate 'SELECT 1'"
> ```
