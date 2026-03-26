# Skill Evaluation: drupal-migrate-db-discover
## Scenario: Multiple non-default database keys (migrate + legacy_drupal)

---

## Skill Used

`skills/drupal/migrate/drupal-migrate-db-discover/SKILL.md`

---

## Step 1 — Check project configuration

**Command:**
```
cat .github/prompts/migrate-instructions.prompt.md
```

**Output:**
```
[NOT FOUND] .github/prompts/migrate-instructions.prompt.md does not exist
```

**Result:** No project-specific configuration found. Proceeding with skill defaults.

---

## Step 2 — Scan settings files

**Command:**
```bash
grep -n "databases\[" src/drupal/web/sites/default/settings.local.php 2>/dev/null
grep -n "databases\[" src/drupal/web/sites/default/settings.php 2>/dev/null
```

**Output:**
```
=== grep settings.local.php ===
9:$databases['default']['default'] = [
21:$databases['migrate']['default'] = [
33:$databases['legacy_drupal']['default'] = [

=== grep settings.php ===
[NOT FOUND]
```

**Analysis:**

Three database keys found in `settings.local.php`:
- `default` — the local Drupal database (excluded per skill rules)
- `migrate` — source migration database (Drupal 7 source site, host: `source-db`, db: `drupal7_source`)
- `legacy_drupal` — legacy staging database (host: `legacy-db`, db: `old_drupal_staging`)

Both `migrate` and `legacy_drupal` are non-default keys. Per skill instructions, when multiple non-default keys are found, the user must be asked to confirm which one is the source migration database.

**User prompt (simulated):**
> "Two non-default database keys were found: `migrate` and `legacy_drupal`. Which one is the source migration database?"

**User response (simulated):**
> "The `migrate` key is the one."

**Selected key:** `migrate`

---

## Step 3 — Test connectivity

**Command:**
```bash
docker compose run --rm drupal-tools ash -c "drush sql:query --database=migrate 'SELECT 1'"
```

**Output:**
```
no configuration file provided: not found
```

**Result:** ❌ Connection test failed — Docker Compose is not available in this environment (no `docker-compose.yml` in the mock project). Infrastructure is not running.

Per skill instructions, when the connection fails:

> "The source database connection failed. Please check the database configuration in settings.php. Error: no configuration file provided: not found"

The skill instructs to **STOP** and not proceed with analysis until the database is reachable.

---

## Step 4 — Report

**Connection status:** `failed` (Docker/infrastructure not available in mock environment)

### Configuration discovered (from static analysis):

| Field | Value |
|-------|-------|
| **Database key** | `migrate` |
| **Drush option** | `--database=migrate` |
| **Driver** | mysql |
| **Host** | `source-db` |
| **Port** | `3306` |
| **Database name** | `drupal7_source` |
| **Username** | `migrate_user` |
| **Connection status** | `failed` (infrastructure unavailable) |

### Connection command template (for when infrastructure is available):
```bash
docker compose run --rm drupal-tools ash -c "drush sql:query --database=migrate 'YOUR_QUERY'"
```

---

## Summary

The skill correctly identified two non-default database keys (`migrate` and `legacy_drupal`) and prompted the user to disambiguate. The user confirmed `migrate` as the migration source. Static inspection of `settings.local.php` confirms `migrate` points to `drupal7_source` on host `source-db` — consistent with a Drupal 7 → Drupal migration source. The connectivity test could not be completed because Docker Compose infrastructure is not available in the mock environment. Per skill guardrails, execution stops here until the database is reachable.
