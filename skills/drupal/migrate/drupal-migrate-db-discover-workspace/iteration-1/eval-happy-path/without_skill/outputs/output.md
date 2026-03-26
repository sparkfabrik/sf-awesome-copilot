# Drupal Migration — Source DB Connection Check

## 1. What's in `settings.local.php`

File: `src/drupal/web/sites/default/settings.local.php`

Three database connections are defined:

| Key | Host | Database | User | Password | Port |
|---|---|---|---|---|---|
| `default` | `db` | `drupal` | `drupal` | `drupal` | 3306 |
| `migrate` | `source-db` | `drupal7_source` | `migrate_user` | `migrate_pass` | 3306 |
| `legacy_drupal` | `legacy-db` | `old_drupal_staging` | `reader` | `reader123` | 3306 |

The **`migrate`** key is the one that matters for the migration — it points to the Drupal 7 source site.

---

## 2. Connection Verification

### Commands run

```bash
# Check available Docker containers
docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Inspect the migrate DB container's network config
docker inspect corporate-website-drupal-db-migrate-1 \
  --format '{{range $net,$cfg := .NetworkSettings.Networks}}Network: {{$net}}, Aliases: {{$cfg.Aliases}}, IP: {{$cfg.IPAddress}}{{end}}'

# Check container env vars for credentials
docker inspect corporate-website-drupal-db-migrate-1 \
  --format '{{range .Config.Env}}{{println .}}{{end}}' | grep -i "pass\|user\|db\|root"

# Attempt connection with settings.local.php credentials (via Docker network)
docker run --rm --network corporate-website_default mysql:8.0 \
  mysql -h source-db -P 3306 -u migrate_user -pmigrate_pass drupal7_source \
  -e "SELECT 1 AS connection_test;"

# Attempt connection with actual credentials found
docker run --rm --network corporate-website_default mysql:8.0 \
  mysql -h drupal-db-migrate -P 3306 -u luiss -pluiss drupal_migrate \
  -e "SELECT 1 AS connection_test;"
```

### Results

| Test | Result |
|---|---|
| `drush` available | ❌ Not in PATH |
| `mysql` client (local) | ❌ Not installed |
| Host `source-db` reachable | ❌ Unknown host — `ERROR 2005: Unknown MySQL server host 'source-db'` |
| `migrate_user` on `drupal-db-migrate` | ❌ Access denied — user doesn't exist |
| `luiss` on `drupal-db-migrate` (`drupal_migrate`) | ✅ Connected successfully |

---

## 3. Findings & Issues

### ❌ `settings.local.php` credentials are wrong

The `migrate` database key in `settings.local.php` does **not** match what is actually running in your Docker environment:

| Setting | `settings.local.php` says | Reality |
|---|---|---|
| Host | `source-db` | `drupal-db-migrate` |
| Database | `drupal7_source` | `drupal_migrate` |
| User | `migrate_user` | `luiss` |
| Password | `migrate_pass` | `luiss` |

The container `corporate-website-drupal-db-migrate-1` is up and healthy on the `corporate-website_default` Docker network, accessible under the DNS alias `drupal-db-migrate`.

### ✅ Database is reachable and contains data

A successful connection was made using the correct credentials:
- **Host:** `drupal-db-migrate`
- **Database:** `drupal_migrate`
- **User/Password:** `luiss` / `luiss`

The database contains a substantial set of tables (confirmed: `aggregator_feed`, `block_content`, `cache_*`, etc.), suggesting it is a real Drupal site database.

---

## 4. Recommended Fix

Update `settings.local.php` to match the actual running infrastructure:

```php
// Source migration database (Drupal source site).
$databases['migrate']['default'] = [
  'driver'    => 'mysql',
  'database'  => 'drupal_migrate',
  'username'  => 'luiss',
  'password'  => 'luiss',
  'host'      => 'drupal-db-migrate',
  'port'      => '3306',
  'prefix'    => '',
  'namespace' => 'Drupal\\Core\\Database\\Driver\\mysql',
];
```

After updating, verify with Drush (from inside the PHP container):

```bash
drush sqlq --database=migrate "SELECT 1 AS connected;"
```

Or list the source tables to confirm data is accessible:

```bash
drush sqlq --database=migrate "SHOW TABLES;" | head -20
```

---

## 5. Summary

- `settings.local.php` defines a `migrate` DB key — the right pattern for Drupal migrations.
- The host, database name, username, and password in that key are **incorrect** for this environment.
- The actual source DB container (`corporate-website-drupal-db-migrate-1`) is running and healthy.
- **You cannot connect** using the current credentials — you will get access-denied or unknown-host errors.
- Fix the four mismatched fields (`host`, `database`, `username`, `password`) in `settings.local.php` to unblock the migration analysis.
