## Purpose

PHP and Drupal-specific vulnerability patterns for the security audit manual review phase, including scanner tool configuration guidance.

## Requirements

### Requirement: PHP/Drupal reference file exists

The skill SHALL include a reference file at `references/php-security.md` that documents PHP and Drupal-specific vulnerability patterns, following the same structure as the existing `references/go-security.md` and `references/nodejs-security.md`.

The reference file SHALL be used by the LLM during Phase 2 manual review to identify PHP/Drupal-specific vulnerabilities that automated tools may miss.

#### Scenario: Reference file listed in SKILL.md

- **WHEN** the skill's language-specific guides section is rendered
- **THEN** it SHALL include an entry for PHP/Drupal pointing to `references/php-security.md`

### Requirement: Cover Drupal render array injection

The reference file SHALL document the vulnerability pattern where user input is placed into Drupal render arrays using `#markup` without sanitization, and the safe alternative using `#plain_text` or `\Drupal\Component\Utility\Xss::filter()`.

#### Scenario: Vulnerable render array identified

- **WHEN** the LLM encounters a render array with `'#markup' => $user_input` during Phase 2
- **THEN** the reference file SHALL provide guidance to flag this as a potential XSS vulnerability
- **THEN** the reference file SHALL recommend using `'#plain_text' => $user_input` or escaping with `Xss::filter()`

### Requirement: Cover SQL injection in Drupal database API

The reference file SHALL document the vulnerability pattern where raw SQL queries are constructed via string concatenation using `Database::getConnection()->query()`, and the safe alternative using placeholders.

#### Scenario: Raw SQL with concatenation

- **WHEN** the LLM encounters `\Drupal::database()->query("SELECT ... " . $user_input)` during Phase 2
- **THEN** the reference file SHALL provide guidance to flag this as SQL injection
- **THEN** the reference file SHALL recommend using parameterized queries with `:placeholder` syntax

### Requirement: Cover Drupal Form API CSRF patterns

The reference file SHALL document how Drupal's Form API provides built-in CSRF protection and the vulnerability patterns where this protection is bypassed (custom form handlers that don't use the Form API, AJAX callbacks without proper token validation).

#### Scenario: Custom route handler modifying state without CSRF

- **WHEN** the LLM encounters a custom route controller that performs state-changing operations without Form API or CSRF token validation
- **THEN** the reference file SHALL provide guidance to flag this as a CSRF vulnerability

### Requirement: Cover Twig autoescape bypass

The reference file SHALL document the vulnerability pattern where Drupal's Twig autoescape is bypassed using the `|raw` filter with user-controlled data, and the safe alternatives.

#### Scenario: Raw filter with user data in Twig

- **WHEN** the LLM encounters `{{ user_input|raw }}` in a Twig template during Phase 2
- **THEN** the reference file SHALL provide guidance to flag this as XSS
- **THEN** the reference file SHALL recommend removing `|raw` or using `{{ user_input|escape }}` explicitly

### Requirement: Cover Drupal access bypass patterns

The reference file SHALL document common access bypass patterns in Drupal: hook implementations that skip access checking, entity queries without `accessCheck(TRUE)`, route definitions missing `_permission` or `_access` requirements.

#### Scenario: Entity query without access check

- **WHEN** the LLM encounters `\Drupal::entityTypeManager()->getStorage('node')->loadMultiple()` without prior access checking
- **THEN** the reference file SHALL provide guidance to flag this as a potential access bypass
- **THEN** the reference file SHALL recommend using entity query with `->accessCheck(TRUE)` or checking access explicitly

### Requirement: Cover insecure file handling in Drupal

The reference file SHALL document the vulnerability pattern where sensitive file uploads use the `public://` stream wrapper (publicly accessible) instead of `private://`, and the security implications of file permission settings.

#### Scenario: Sensitive upload to public filesystem

- **WHEN** the LLM encounters a file field or upload handler storing sensitive documents in `public://`
- **THEN** the reference file SHALL provide guidance to flag this as sensitive data exposure
- **THEN** the reference file SHALL recommend using `private://` for non-public files

### Requirement: Cover PHP-general security patterns

Beyond Drupal-specific patterns, the reference file SHALL document general PHP vulnerability patterns applicable to any PHP project:

- `eval()` and `preg_replace()` with the `e` modifier for code injection
- `unserialize()` with user input for object injection
- `extract()` with user input for variable injection
- `include`/`require` with user-controlled paths for local file inclusion
- Missing `htmlspecialchars()` flags (`ENT_QUOTES`, encoding parameter)
- `exec()`, `system()`, `passthru()`, `shell_exec()`, backtick operator with user input

#### Scenario: Unserialize with user input

- **WHEN** the LLM encounters `unserialize($_GET['data'])` during Phase 2
- **THEN** the reference file SHALL provide guidance to flag this as an object injection vulnerability
- **THEN** the reference file SHALL recommend using `json_decode()` or `unserialize()` with `allowed_classes` parameter

### Requirement: Document PHP scanner tool configuration

The reference file SHALL include a section documenting how each PHP/Drupal scanning tool is invoked, its key rules/checks, and how to interpret its output. This covers: composer audit, phpcs with drupal/coder, psalm taint analysis, phpstan, drupal-check, and local-php-security-checker.

#### Scenario: Psalm taint analysis explanation

- **WHEN** a user or the LLM needs to understand psalm's taint analysis output
- **THEN** the reference file SHALL explain taint sources (user input entry points), taint sinks (dangerous function calls), and how psalm traces data flow between them
