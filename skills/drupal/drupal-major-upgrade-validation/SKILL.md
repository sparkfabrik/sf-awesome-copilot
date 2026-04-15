---
name: drupal-major-upgrade-validation
description: >
  Validate Drupal major version upgrades (e.g., D10 to D11) using browser
  automation. Establishes a baseline on the stable branch, applies the upgrade,
  then validates the upgraded site with identical tests and produces a comparison
  report. Use this skill when the user mentions "drupal upgrade validation",
  "major version upgrade", "D10 to D11", "D11 to D12", "upgrade baseline",
  "upgrade comparison", "validate upgrade", or wants to verify that a Drupal
  major upgrade does not break frontend or backend functionality. Also trigger
  when the user says "compare before and after upgrade", "test the upgrade",
  or "upgrade smoke test".
metadata:
  author: sparkfabrik
  version: "1.0"
---

# Drupal Major Upgrade Validation

Validate a Drupal major version upgrade by capturing a behavioral baseline on the
current stable version, applying the upgrade, and running the same tests again on
the new version. Produce a structured comparison report.

This skill is project-agnostic. It discovers how to run commands, which containers
to use, and what URLs to hit by reading the project's `AGENTS.md` and other skills
loaded in the current session.

## Before You Start

### Prerequisites

1. **Two branches must exist:** a stable branch (e.g., `develop`) running the current
   Drupal major version, and an upgrade branch with the new version already prepared
   (dependencies updated, patches ported, configuration adjusted).

2. **Docker environment must be operational.** The project must be buildable with
   `docker compose build && docker compose up -d` on both branches.

3. **Browser automation tool.** This skill uses `playwright-cli` for all browser
   interactions. Load the `playwright-cli` skill if not already loaded. Check
   availability:
   ```bash
   command -v playwright-cli 2>/dev/null || npx -y @playwright/cli --version
   ```

4. **Container context.** Load the `sparkfabrik-drupal-containers` skill
   (`skills/drupal/pkg-skills/`) if not already loaded. It documents how to run
   commands inside containers, access services, discover URLs, and use `make`
   targets. All container and tooling commands in this skill follow the patterns
   described there.

### First Interaction

Ask the user for:

1. **Stable branch name** (e.g., `develop`, `main`)
2. **Upgrade branch name** (e.g., `feat/drupal-11`, `497-D11-update`)
3. **Which pages to test** -- or offer the default test plan (see below)
4. **Admin credentials** for backend testing (username and password)
5. **Known local-only status report issues** to ignore (e.g., missing private files
   directory, disabled trusted host patterns)

## Default Test Plan

If the user does not provide a custom test plan, build one dynamically by
navigating the site's main menu and sampling subpages.

### Frontend: Menu-Driven Discovery

1. **Homepage:** Navigate to `/` and take a screenshot. Record title and console
   errors.

2. **Extract main navigation links:** Use `playwright-cli` to collect all first-level
   links from the site's primary navigation menu (typically `<nav>`, `.menu--main`,
   `#block-mainnavigation`, or the first `<ul>` inside the header). Record each
   link's text and href.

3. **Visit every first-level menu item:** Navigate to each link extracted in step 2.
   For each page:
   - Wait for full load
   - Record the page title
   - Record console errors
   - Take a screenshot

4. **Random subpage sampling:** For each first-level page that is a listing (contains
   links to detail pages, e.g., a blog index, product catalog, or news archive),
   randomly pick 1-2 items from the listing and navigate to them. Take a screenshot
   of each. This validates that detail pages and internal linking survive the upgrade.

5. **Search:** If a search form or `/search` path exists, execute a search with a
   simple term (e.g., the site name) and screenshot the results page.

### Backend: Fixed Admin Pages

After frontend testing, log in with the credentials provided by the user and test
these fixed admin paths:

| Test               | URL Path                                | Checks                                                    |
|--------------------|-----------------------------------------|-----------------------------------------------------------|
| Admin login        | `/user/login`                           | Login form works, redirects to dashboard                  |
| Content list       | `/admin/content`                        | Table renders with content items                          |
| Create content     | `/node/add/<first-type>`                | Form renders, all fields present                          |
| Site configuration | `/admin/config/system/site-information` | Settings page renders                                     |
| Status report      | `/admin/reports/status`                 | Check for errors and warnings (see below)                 |
| Modules list       | `/admin/modules`                        | Module list renders                                       |
| Media library      | `/admin/content/media`                  | Media grid/table renders (if enabled)                     |

#### Status Report Check

The `/admin/reports/status` page is a critical validation point. After taking a
screenshot, inspect the page for error and warning rows. Classify each item:

- **Errors/warnings that also appear on the baseline (D10):** these are pre-existing
  and not caused by the upgrade. Note them but do not mark as FAIL.
- **New errors/warnings that only appear after the upgrade:** these may indicate a
  real regression. Record them and mark the status report check as WARN or FAIL.
- **Known local-only issues** that are expected in local development and do not
  appear in production (e.g., missing `private` files directory, disabled
  `trusted_host_patterns`). Ask the user during the first interaction if there
  are known local-only status report items to ignore.

### Numbering Convention

Number screenshots sequentially as they are taken: `01-homepage.png`,
`02-<menu-item-slug>.png`, etc. The exact number of screenshots depends on how
many menu items and subpages the site has. Record the full test manifest (number,
name, URL, type) so Phase 4 can replay the exact same sequence.

## Workflow

### Phase 1: Discover Project Tooling

Before touching any branch, gather project context from the
`sparkfabrik-drupal-containers` skill and the project's `AGENTS.md`:

1. **Container commands:** The `sparkfabrik-drupal-containers` skill defines how
   to run `drush`, `composer`, and other commands inside the tools container.
   Use those patterns throughout this workflow.

2. **Site URL:** Use the method from the skill to discover the local site URL
   (e.g., `fs-cli pkg:get-urls` from the host, or the container service hostname
   from inside a container).

3. **Build command:** Read the project's `AGENTS.md` to identify the site build
   command (e.g., `make`, `bin/robo build-app`, or custom scripts) and any
   hook system for pre/post install.

4. **Command safety policy:** Read the project's `AGENTS.md` for the command
   safety policy. Commands like `composer install`, `drush deploy`, and
   `drush updb` typically require user confirmation.

### Phase 2: Baseline (Stable Branch)

**Goal:** Capture the current site's behavior as the reference baseline.

1. **Switch to stable branch:**
   ```bash
   git stash  # if needed
   git checkout <stable-branch>
   ```

2. **Build the environment:**
   ```bash
   docker compose build
   docker compose up -d
   ```

3. **Install dependencies and build the site** using the container commands from
   the `sparkfabrik-drupal-containers` skill. This typically involves:
   - Running `composer install` inside the tools container
   - Running the site build/install command (from `AGENTS.md`)
   - Waiting for the site to be fully operational

4. **Verify Drupal version:**
   Run `drush status --field=drupal-version` inside the tools container.
   Record the exact version (e.g., `10.4.3`).

5. **Run the test plan** using `playwright-cli`:

   Create a directory for baseline screenshots:
   ```bash
   mkdir -p .playwright-cli/baseline
   ```

   Execute the Default Test Plan (or the user's custom plan):
   - Start with the homepage
   - Extract and visit all first-level main navigation links
   - Randomly sample 1-2 subpages from each listing page
   - Test search if available
   - Log in to the backend and test fixed admin pages

   For every page visited:
   - Wait for the page to fully load
   - Record the page title
   - Record any console errors
   - Take a screenshot: `.playwright-cli/baseline/NN-test-name.png`
   - For form pages, verify that fields are present and interactive

   **Save the test manifest** -- the ordered list of (number, name, URL, type)
   for every page tested. This manifest is replayed identically in Phase 4.

6. **Record baseline results** in memory:
   - Drupal version
   - Per-page: title, console error count, screenshot path, pass/fail, notes
   - Total: pages tested, pages passed, total console errors

### Phase 3: Upgrade

**Goal:** Switch to the upgrade branch and get the new version running.

1. **Switch to upgrade branch:**
   ```bash
   git checkout <upgrade-branch>
   ```

2. **Rebuild the environment:**
   ```bash
   docker compose build
   docker compose up -d
   ```

3. **Install dependencies:**
   Run `composer install` inside the tools container.

4. **Apply database updates and import configuration:**
   Run `drush deploy -y` inside the tools container. This executes
   `drush updatedb` (database updates) followed by `drush config:import`
   (configuration sync). Monitor the output carefully:
   - Record the number of update hooks executed
   - Note any warnings or errors
   - If `drush deploy` is not available, run the two commands separately:
     `drush updatedb -y` then `drush config:import -y`

5. **Rebuild caches:**
   Run `drush cr` inside the tools container.

6. **Verify new Drupal version:**
   Run `drush status --field=drupal-version` inside the tools container.
   Record the exact version (e.g., `11.1.6`).

### Phase 4: Validation (Upgraded Version)

**Goal:** Run the identical test plan against the upgraded site.

1. **Create validation screenshot directory:**
   ```bash
   mkdir -p .playwright-cli/validation
   ```

2. **Replay the test manifest** saved in Phase 2. Visit the exact same URLs in
   the same order, using the same screenshot names. Do not re-discover the menu
   or re-sample subpages -- use the recorded manifest so the comparison is
   apples-to-apples. Save screenshots to the `validation/` directory.

3. **Record validation results** with the same structure as the baseline.

### Phase 5: Comparison Report

**Goal:** Produce a structured comparison report as a markdown file.

Generate a file named `UPGRADE-VALIDATION-REPORT.md` in the **project root** with
the following structure:

```markdown
# Drupal Upgrade Validation Report

**Date:** YYYY-MM-DD
**Project:** <project-name>
**Baseline branch:** <stable-branch>
**Upgrade branch:** <upgrade-branch>
**Baseline version:** Drupal <X.Y.Z>
**Upgraded version:** Drupal <X.Y.Z>

## Summary

| Metric                 | Baseline | Upgraded | Status         |
|------------------------|----------|----------|----------------|
| Drupal version         | X.Y.Z    | X.Y.Z    | --             |
| Pages tested           | N        | N        | --             |
| Pages passed           | N        | N        | PASS/FAIL      |
| Console errors (total) | N        | N        | PASS/WARN/FAIL |
| Update hooks executed  | --       | N        | --             |

**Overall result:** PASS / FAIL

## Upgrade Details

- **Update hooks:** N hooks executed successfully
- **Configuration import:** clean / N conflicts
- **Notable changes:** (list any significant changes observed, e.g., theme
  changes, jQuery version bump, new admin UI)

## Page-by-Page Comparison

| #  | Page     | Baseline Title | Upgraded Title | Baseline Errors | Upgraded Errors | Visual            | Status |
|----|----------|----------------|----------------|-----------------|-----------------|-------------------|--------|
| 1  | Homepage | ...            | ...            | N               | N               | identical/changed | PASS   |
| 2  | ...      | ...            | ...            | ...             | ...             | ...               | ...    |

## Console Errors

### Baseline (Drupal X)
<list any console errors per page, or "None">

### Upgraded (Drupal X)
<list any console errors per page, or "None">

## Screenshots

Baseline screenshots: `.playwright-cli/baseline/`
Validation screenshots: `.playwright-cli/validation/`

## Recommendations

<list any issues found, recommended fixes, or follow-up actions>
```

### Status Classification

- **PASS:** Page works identically or better in the upgraded version
- **WARN:** Minor differences detected (e.g., visual changes from theme updates,
  different console warning counts) but functionality is preserved
- **FAIL:** Page is broken, missing content, or has new critical errors

### Overall Result Rules

- **PASS:** All pages pass, no new critical console errors
- **FAIL:** Any page fails, or critical functionality is broken

## Tips

- **S3FS vs local files:** Some projects switch file storage backends between
  versions. Image URLs may change (e.g., `/sites/default/files/` to `/s3/files/`).
  This is expected and not a failure -- note it in the report but mark as PASS.

- **Admin theme changes:** Major Drupal upgrades often include admin theme updates
  (e.g., Gin 3.x to 4.x). Visual differences in the admin UI are expected. Focus
  on functional correctness (forms work, content saves) rather than pixel-perfect
  comparison.

- **jQuery version:** Drupal 11 ships jQuery 4.x (up from 3.x in D10). This can
  cause console errors in contrib modules that use deprecated jQuery APIs. Note
  these but they are usually non-blocking.

- **Deprecated theme engines:** If the project uses `classy` or `stable` as a base
  theme, these are removed from Drupal core in D11 and available as contrib. Check
  that the contrib versions are in `composer.json` on the upgrade branch.

- **Large test plans:** For projects with many pages, prioritize: homepage, main
  content types, search, admin login, and content creation. Skip repetitive
  variations of the same page type.

- **Resuming interrupted validations:** If the process is interrupted, check which
  screenshots already exist in `.playwright-cli/baseline/` and
  `.playwright-cli/validation/` to determine where to resume.

- **Database seed vs config install:** If the project uses a database seed for local
  builds, ensure the seed is from the stable branch before starting. The upgrade
  branch should use `drush deploy` on top of the seeded database, not a fresh
  config install.
