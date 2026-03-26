# Drupal Migration DB Connection Failure — Diagnosis Walkthrough

## Commands Run & Findings

### 1. Explored the mock project

```
find mock-project -type f
```

**Found:** `src/drupal/web/sites/default/settings.local.php`

### 2. Read settings.local.php

```php
// Default (local) database.
$databases['default']['default'] = [
  'driver' => 'mysql',
  'database' => 'drupal',
  'username' => 'drupal',
  'password' => 'drupal',
  'host' => 'db',
  'port' => '3306',
  ...
];

// Source migration database (Drupal 7 source site).
$databases['migrate']['default'] = [
  'driver' => 'mysql',
  'database' => 'drupal7_source',
  'username' => 'migrate_user',
  'password' => 'migrate_pass',
  'host' => 'source-db',
  'port' => '3306',
  ...
];

// Legacy staging database (kept for reference, NOT the migration source).
$databases['legacy_drupal']['default'] = [
  'driver' => 'mysql',
  'database' => 'old_drupal_staging',
  'username' => 'reader',
  'password' => 'reader123',
  'host' => 'legacy-db',
  'port' => '3306',
  ...
];
```

### 3. Tried running drush

```
drush sql:query --database=migrate "SELECT 1"
```

**Result:** `bash: drush: command not found` — drush/Docker infrastructure not available in this environment. Noted and continued.

---

## Response to User

Here's how to systematically diagnose a `drush sql:query` connection error against your source migration database.

---

### Step 1: Confirm which database key you're targeting

When running `drush sql:query` against a non-default database, you must pass the `--database` option:

```bash
drush sql:query --database=migrate "SELECT 1"
```

Without `--database=migrate`, drush hits the `default` database — not your migration source. This is the most common mistake.

---

### Step 2: Read your settings.local.php

Open `web/sites/default/settings.local.php` (or `settings.php` if there's no local override). Look for the `$databases['migrate']['default']` block:

```php
$databases['migrate']['default'] = [
  'driver'   => 'mysql',
  'database' => 'drupal7_source',
  'username' => 'migrate_user',
  'password' => 'migrate_pass',
  'host'     => 'source-db',   // <-- this hostname must be reachable from your app container
  'port'     => '3306',
  ...
];
```

In this project the host is `source-db` — a Docker service name. If that container isn't running or the name is wrong, every connection attempt will fail.

---

### Step 3: Verify the source container is up and reachable

From your host machine or inside the app container:

```bash
# Check running containers
docker ps | grep source-db

# Ping the host from inside the Drupal app container
docker exec <app-container> ping -c 2 source-db

# Or test the TCP port directly
docker exec <app-container> nc -zv source-db 3306
```

If `source-db` doesn't appear in `docker ps`, the container isn't running. Start it (or check your `docker-compose.yml` for the correct service name).

---

### Step 4: Test the credentials directly

Once you confirm the host is reachable, test the credentials:

```bash
# From inside the app container
docker exec <app-container> mysql \
  -h source-db \
  -P 3306 \
  -u migrate_user \
  -pmigrate_pass \
  drupal7_source \
  -e "SELECT 1;"
```

Common failures here:
- **Access denied** → wrong username/password, or the user lacks grants on `drupal7_source`
- **Unknown database** → the database name in `settings.local.php` doesn't match what's actually in the source container
- **Can't connect to MySQL server** → host/port wrong, or the container is stopped

---

### Step 5: Verify the database exists and the user has access

Connect to the source MySQL as root and check:

```sql
SHOW DATABASES;                          -- is drupal7_source listed?
SHOW GRANTS FOR 'migrate_user'@'%';     -- does the user have SELECT on drupal7_source?
```

If the user is missing grants:

```sql
GRANT SELECT ON drupal7_source.* TO 'migrate_user'@'%' IDENTIFIED BY 'migrate_pass';
FLUSH PRIVILEGES;
```

---

### Step 6: Check for namespace issues (Drupal 9/10)

In Drupal 9+ the `namespace` key for MySQL changed. If you copied config from an old D7/D8 project, the namespace may be wrong:

```php
// Old (D7/D8) — will throw a class-not-found error in D9+
'namespace' => 'Drupal\\Core\\Database\\Driver\\mysql',

// Correct for D9/D10
'namespace' => 'Drupal\\mysql\\Driver\\Database\\mysql',
```

Update the namespace in `settings.local.php` if your Drupal version requires it.

---

### Step 7: Confirm settings.local.php is actually loaded

Check that `settings.php` includes the local override file:

```php
// At the bottom of settings.php:
if (file_exists($app_root . '/' . $site_path . '/settings.local.php')) {
  include $app_root . '/' . $site_path . '/settings.local.php';
}
```

If this block is missing or commented out, your `$databases['migrate']` key never gets registered.

---

### Summary of likely culprits (in order of probability)

| # | Cause | Quick check |
|---|-------|-------------|
| 1 | Missing `--database=migrate` flag | Re-run drush with the flag |
| 2 | `source-db` container not running | `docker ps \| grep source-db` |
| 3 | Wrong hostname in settings | Verify service name in docker-compose |
| 4 | Wrong credentials / missing grants | `SHOW GRANTS` in MySQL |
| 5 | Wrong `namespace` for Drupal 9+ | Check PHP class path |
| 6 | `settings.local.php` not included | Check `settings.php` include block |
