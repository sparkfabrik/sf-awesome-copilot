---
name: drupal-migrate-tech-analysis
description: Perform a technical analysis of a migration GitLab issue and produce a detailed checkbox TO DO list of technical tasks. Use when the user provides a GitLab issue number related to a Drupal content migration (e.g., "Do a tech analysis of issue #210", "Analyse issue 175 technically", "What do we need to implement for issue #42?").
---

# Technical Analysis of a Migration Issue

Read a GitLab issue and produce a precise, technically complete checkbox TO DO list for its implementation, grounded in the actual project codebase and migration patterns.

---

## Project Configuration

Before executing, check for a project-specific configuration file at:
`.github/prompts/migrate-instructions.prompt.md`

If it exists, read the **Issue Tracker** section for the `glab` repository flag and other project-specific values.
If it does not exist, ask the user for the GitLab repository identifier.

---

## Input

The user provides a GitLab issue number (e.g., `#175`, `175`, `issue 175`). Extract the number and proceed.

If no issue number is provided, ask the user:
> "Which issue do you want to analyse? Please provide the issue number (e.g. 175 or #175)."

---

## Steps

### Step 1 — Fetch the issue from GitLab

Use the `gitlab-read-issue` skill to fetch the issue. If that skill is not available, use `glab` directly:

```bash
glab issue view <issue-number> --comments --per-page 50 {repo_flag} -F json
```

Where `{repo_flag}` comes from the project config (e.g., `-R "customers/luiss/projects/corporate-website"`).

- If `glab` is not found or returns an auth error, inform the user and suggest `glab auth status`. Then **STOP**.
- If the issue is not found, inform the user. Then **STOP**.

Parse the JSON output and extract: **Title**, **Description** body, all **labels** and **milestone**, all **comments**.

### Step 2 — Parse the issue template sections

The issue typically follows this structure:

```
## Descrizione
<context and motivation>

## Requisiti
<business/functional requirements as checkboxes>

## To do
<existing task list, if any>

## Definition of Done
<acceptance criteria checkboxes>
```

Extract and summarise each section. Pay special attention to:
- **Descrizione**: What entity/bundle/content is being migrated? From which source?
- **Requisiti**: What are the functional requirements?
- **To do**: Does a task list already exist?
- **Definition of Done**: What are the acceptance criteria?
- **Comments**: Read all comments. Extract decisions, clarifications, scope changes, field mapping notes. Comments take precedence over the description when they refine it.

### Step 3 — Explore the codebase

Use bash, glob, and grep tools in parallel to gather context:

#### 3a — Check for existing migration plugins
```bash
find src/drupal/web/modules/custom -type f -name "*.php" | xargs grep -l "MigrateSource\|MigrateDestination\|MigrateProcessPlugin" 2>/dev/null
find src/drupal/config/sync -name "migrate_plus.migration*.yml" 2>/dev/null
```

#### 3b — Check destination content types / paragraphs
```bash
ls src/drupal/config/sync/core.entity_form_display.{entity_type}.{bundle}.*.yml 2>/dev/null
ls src/drupal/config/sync/field.field.{entity_type}.{bundle}.*.yml 2>/dev/null
ls src/drupal/web/themes/custom/*/components/lc-{bundle-slug}/ 2>/dev/null
```

#### 3c — Check for existing tests
```bash
grep -r "{bundle_name}" src/drupal/web/modules/custom/*/tests/ --include="*.php" -l 2>/dev/null
```

#### 3d — Check reference documentation
```bash
ls doc/Reference/
```

#### 3e — Check for existing mock/base content
```bash
find src/drupal/web/modules/custom -name "*.yml" -path "*/content/*" | xargs grep -l "{bundle}" 2>/dev/null
```

#### 3f — Check project-specific references
Read the **Reference Documentation** section from `.github/prompts/migrate-instructions.prompt.md` for additional files to consult.

### Step 4 — Assess migration scope and complexity

Based on Steps 2 and 3, determine:
1. Source entity type and bundle
2. Destination entity type and bundle in Drupal 11
3. Field mapping status (existing vs new fields)
4. Media/file handling requirements
5. Paragraph nesting depth
6. Multilanguage (IT/EN variants)
7. Taxonomy references that need migrating first
8. User references
9. URL alias migration
10. Access control requirements

> **Note**: If a source analysis has already been performed (via `migrate-source-analysis` or its atomic skills), reference those results instead of re-investigating.

### Step 5 — Produce the technical TO DO list

Generate a complete Markdown checkbox list organized into logical groups. **Only include groups relevant to this specific issue.**

#### Standard task groups (adapt as needed)

**Source analysis**
- [ ] Run source analysis skills to produce the full field analysis report for `{sourceBundle}`
- [ ] Confirm total vs. active instance counts and document orphaned instances
- [ ] _(If group/container)_ Repeat source analysis for each child paragraph bundle

**Destination fields and config**
- [ ] Create / verify field `{field_machine_name}` on `{entity_type}.{bundle}` (type: `{field_type}`)
- [ ] Export updated field config to `src/drupal/config/sync/`
- [ ] Verify entity form display and view display for all new fields
- [ ] _(If new paragraph type)_ Create paragraph type with all required fields
- [ ] _(If new SDC needed)_ Create SDC component in the theme
- [ ] _(If new image style)_ Add image style and document in `doc/Reference/images.md`
- [ ] _(If new media type)_ Create media type and document in `doc/Reference/media-library.md`
- [ ] _(If new taxonomy)_ Create vocabulary and document in `doc/Reference/taxonomies.md`

**Migration plugins**
- [ ] Create source plugin in custom migrate module
- [ ] Implement process plugins for non-trivial field transformations
- [ ] Create migration YAML config
- [ ] Set correct `migration_dependencies`

**Media and file migration**
- [ ] Create migration for source files → managed files
- [ ] Create migration for source images → Media entities
- [ ] Verify file URI rewriting

**URL aliases**
- [ ] Create migration for URL aliases
- [ ] Verify alias conflicts with existing content

**Multilanguage**
- [ ] Handle `langcode` in source plugin
- [ ] Create separate migration for language variants

**GAC / Access control**
- [ ] Verify if nodes require group access configuration

**Fixtures and tests**
- [ ] Create or update mock content
- [ ] Add Panther test for the appropriate feature group
- [ ] Run tests and QA

**Documentation**
- [ ] Document the bundle in reference docs
- [ ] Update common fields / roles / permissions docs as needed

**Final validation**
- [ ] Run the migration locally
- [ ] Verify migrated content in admin UI
- [ ] Verify frontend rendering
- [ ] Confirm all Definition of Done items

---

## Output format

```
## Technical TO DO — Issue #<iid>: <title>

> **Summary**: <2–3 sentence summary>
>
> **Source**: <entity_type>.<bundle> (Drupal 7/8) → **Destination**: <entity_type>.<bundle> (Drupal 11)
> **Complexity**: Low / Medium / High — <justification>

### TO DO

(task groups here)
```

After presenting, add:
> ℹ️ This list was generated from the issue description and a codebase scan. Review it with the team before starting implementation.

---

## Guardrails

- Only include task groups genuinely relevant to this issue
- Be specific: use actual machine names, file paths, class names
- If destination bundle cannot be determined, ask the user
- If the issue already has a TO DO list, acknowledge it and produce a more detailed version
- Do not modify the GitLab issue — output only
- All output language follows the project config (check **Issue Output Language** section)
- Run codebase exploration queries in parallel
- Always use the repository flag from project config in `glab` commands
