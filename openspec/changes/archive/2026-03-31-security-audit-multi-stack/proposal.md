## Why

The security-audit skill currently only supports Go and Node.js stacks (with dedicated reference files and tool configurations). PHP/Drupal projects — a primary stack for the team — have no coverage. The skill also assumes all scanning tools are installed locally, which is unreliable across developer environments. This change restructures the skill around stack discovery, project-native tooling, and dynamically generated Docker containers so it works for any project regardless of what's installed on the developer's machine.

## What Changes

- Add a **Phase 0 (Discovery)** step to the audit workflow that reads project configuration files (composer.json, phpstan.neon, .phpcs.xml, go.mod, package.json, CI configs, Makefile, DDEV/Lando config) to determine which stacks are present and which tools are already available.
- Restructure Phase 1 into **Phase 1a (project-native tools)** that runs tools already configured in the project, and **Phase 1b (Docker-augmented scanning)** that fills coverage gaps using generated containers.
- The skill **generates per-stack Dockerfiles and scan scripts** at audit time rather than relying on a single fat image or locally installed tools. Each detected stack gets its own container with only the relevant tools. A separate "universal" container handles cross-cutting scanners (semgrep, trivy, gitleaks).
- Add a **PHP/Drupal reference file** (`references/php-security.md`) documenting Drupal-specific vulnerability patterns, taint analysis guidance, and scanner configuration — equivalent in depth to the existing Go and Node.js references.
- Update the **tool matrix** in SKILL.md to include PHP/Drupal tools: `composer audit`, `phpcs` with Drupal coding standards, `psalm` (taint analysis), `phpstan`, `drupal-check`, and `local-php-security-checker`.
- Restructure the "Handling missing tools" section: instead of asking the user to install tools, the skill generates and builds Docker containers to provide them.
- Generated scan output uses a **structured output directory** (`.security-audit/output/<stack>/`) with a manifest file tracking what ran, what was skipped, and why.

## Capabilities

### New Capabilities

- `stack-discovery`: Phase 0 logic for detecting project stacks, existing tool configurations, and CI-defined scanning from project config files.
- `dockerfile-generation`: Generation of per-stack Dockerfiles and scan.sh entrypoints tailored to the detected project stacks, including a universal container for cross-cutting tools.
- `php-security-patterns`: PHP/Drupal-specific vulnerability patterns reference file covering Drupal render arrays, Form API CSRF, raw SQL in custom modules, taint analysis with Psalm, and phpcs security sniffs.

### Modified Capabilities

_(none — no existing specs)_

## Impact

- **SKILL.md**: Major restructure — new Phase 0 and Phase 0.5 (Dockerfile generation), split Phase 1 into 1a/1b, updated tool matrix, new language-specific guide entry for PHP.
- **New file**: `references/php-security.md`
- **New file**: `references/dockerfile-templates.md` (or similar) documenting the Dockerfile generation patterns per stack.
- **Existing references**: `references/go-security.md` and `references/nodejs-security.md` unchanged.
- **Dependency**: Docker must be available on the developer's machine (replaces the previous requirement of having individual scanning tools installed).
