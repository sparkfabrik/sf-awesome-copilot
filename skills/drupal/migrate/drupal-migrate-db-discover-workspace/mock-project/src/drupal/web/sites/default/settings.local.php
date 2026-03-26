<?php

/**
 * Mock settings.local.php for skill eval purposes.
 * Simulates a Drupal project with a source migration database configured.
 */

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
