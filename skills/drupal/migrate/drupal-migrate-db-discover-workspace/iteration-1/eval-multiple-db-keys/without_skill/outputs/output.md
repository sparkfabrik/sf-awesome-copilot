# Drupal Migration Source DB Investigation

## Task

The user has two database keys in `settings.local.php` — `migrate` and `legacy_drupal` — and wants to know which one is the actual migration source.

---

## Steps Taken

### 1. Read `settings.local.php`

**File:** `src/drupal/web/sites/default/settings.local.php`

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

### 2. Checked for migration YAML config files

No `.yml` or `.yaml` files were found in the mock project directory.

### 3. Attempted to verify DB connectivity

```
$ drush sql-connect --database=migrate
drush not available (infrastructure not running in this environment)

$ mysql -h source-db -u migrate_user -pmigrate_pass drupal7_source
mysql connection failed (expected in mock env — Docker not running)
```

---

## Findings

| Key            | Database              | Host       | Purpose                                  |
|----------------|-----------------------|------------|------------------------------------------|
| `default`      | `drupal`              | `db`       | Current Drupal site (destination)        |
| `migrate`      | `drupal7_source`      | `source-db`| **Migration source (Drupal 7 origin)**   |
| `legacy_drupal`| `old_drupal_staging`  | `legacy-db`| Old staging copy — NOT the migration source |

---

## Conclusion

**Use the `migrate` key.** It is the correct migration source database.

Evidence:
- The inline comment explicitly says: `// Source migration database (Drupal 7 source site).`
- The `legacy_drupal` key has the comment: `// Legacy staging database (kept for reference, NOT the migration source).`
- The database name `drupal7_source` confirms it is the Drupal 7 content being migrated.
- The `migrate` key is also the **Drupal convention** for the source DB used by the `migrate` module and `migrate_drupal` — it is the default key that Drupal's migration system looks for when no explicit `source.key` is set in a migration YAML.

### Verification command (once infrastructure is available)

```bash
# Check the migrate source DB is reachable and contains Drupal 7 tables:
drush sql-connect --database=migrate -- -e "SHOW TABLES;" | head -20

# Or verify the connection details drush resolves:
drush sql-connect --database=migrate --show-passwords
```

If the `migrate` database contains Drupal 7 core tables like `node`, `users`, `field_data_*`, you are connected to the right source.
