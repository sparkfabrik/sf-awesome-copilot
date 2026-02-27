---
name: migrate-source-analysis
description: Analyse a source Drupal entity bundle (node, paragraph, taxonomy_term) for migration purposes. Use when the user asks to "analyse", "dig into", or "investigate" a specific bundle type — e.g., "Analyse the paragraph type 'profile_card_with_modal'", "Dig into the node of type luisspage", "What fields does person_simple_with_email have?". Produces a structured field analysis report with active instance counts, field population data, orphan detection, live screenshots of example pages, and — optionally — a complete GitLab issue description ready to paste.
---

> **⚠️ DEPRECATED**: This monolithic skill has been replaced by a set of atomic skills that the `migration-analyst` agent orchestrates:
> `migrate-db-discover`, `migrate-detect-version`, `migrate-count-instances`, `migrate-parent-context`, `migrate-verify-active`, `migrate-detect-container`, `migrate-query-fields`, `migrate-field-population`, `migrate-live-examples`, `migrate-scan-destination`.
> This skill still works as a standalone fallback but is no longer maintained. Use the `migration-analyst` agent instead.

You are a migration analysis expert for the Luiss University corporate website (Drupal 11). Your job is to **actively query the source database and local config files** to produce a precise, data-driven analysis of the given entity bundle.

Reference the migration issue prompt: [issue-migrate-requirements.prompt.md](../../../.github/prompts/issue-migrate-requirements.prompt.md)

---

## Input

The user's request should include an entity bundle name (e.g., `profile_card_with_modal`, `luisspage`) and optionally the entity type (`node`, `paragraph`, `taxonomy_term`). If the entity type is not specified, infer it:
- If the name matches a known Drupal node type pattern, assume `node`.
- If the name contains words like `group`, `modal`, `card`, `person`, assume `paragraph`.
- If still ambiguous, use the **AskUserQuestion tool** to ask:
  > "What entity type is `{bundleName}`? (node, paragraph, or taxonomy_term)"

---

## Steps

### Step 1 — Connect and detect source Drupal version

Connect using:
```bash
docker compose run --rm drupal-tools ash -c "drush sql:query --database=drupal_migrate 'YOUR_QUERY'"
```

Usually the `drupal_migrate` database is the name of the source Drupal database, but this may vary. Ensure that the 
database connection is pre-configured in `settings.php` with the correct credentials and SSL options. 
If connection fails, check the error message for clues (e.g., SSL handshake failure, authentication error) and adjust 
parameters as needed.

> **Never use `mysql` directly** — it fails due to SSL/auth configuration.

Detect whether the source is Drupal 7 or 8+:
```sql
SELECT IF(
  EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'drupal_migrate' AND TABLE_NAME = 'field_config_instance'),
  'drupal7',
  IF(EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'drupal_migrate' AND TABLE_NAME = 'config'), 'drupal8+', 'unknown')
) AS source_version;
```

If the database is unreachable, **stop and ask the user** for connection parameters.

---

### Step 2 — Count instances (revision-safe)

Always use `COUNT(DISTINCT id)` to avoid inflating counts due to revisions or language variants.

**For paragraphs:**
```sql
SELECT type, COUNT(DISTINCT id) AS instances
FROM paragraphs_item_field_data
WHERE type = '{sourceBundle}'
GROUP BY type;
```

**For nodes:**
```sql
SELECT type, COUNT(DISTINCT nid) AS instances
FROM node_field_data
WHERE type = '{sourceBundle}'
GROUP BY type;
```

> ⚠️ `COUNT(*)` inflates results significantly (5–70×). Always use `DISTINCT`.

Usually the table name is `{entityType}_field_data` (e.g., `node_field_data`, `taxonomy_term_field_data`). 
For paragraphs, the main table is `paragraphs_item_field_data` which includes all paragraphs from all revisions.
For users, the main table is `users_field_data`. Always verify the correct table name for the entity type. 
If the query fails, check for similarly named tables in the database and adjust accordingly, or ask the user to confirm
the correct table name.

---

### Step 3 — Identify parent context (paragraphs only)

For paragraphs, identify which entity types and fields reference this bundle:

```sql
SELECT parent_type, parent_field_name, COUNT(DISTINCT id) AS instances
FROM paragraphs_item_field_data
WHERE type = '{sourceBundle}'
GROUP BY parent_type, parent_field_name
ORDER BY instances DESC;
```

If the parent type is `node`, further identify the node bundles:

```sql
SELECT n.type AS node_bundle, COUNT(DISTINCT n.nid) AS node_count
FROM node_field_data n
JOIN paragraphs_item_field_data p ON p.parent_id = n.nid AND p.parent_type = 'node'
WHERE p.type = '{sourceBundle}'
GROUP BY n.type
ORDER BY node_count DESC;
```

---

### Step 4 — Verify active instances against published content (paragraphs only)

> ⚠️ **Critical**: `paragraphs_item_field_data` includes paragraphs from ALL node revisions (including old and deleted ones). Only paragraphs referenced by the **current published revision** of a node should be counted for migration scope.

For each parent field identified in Step 3, run:

```sql
SELECT n.type AS node_bundle,
  COUNT(DISTINCT p.id)  AS active_instances,
  COUNT(DISTINCT n.nid) AS parent_nodes
FROM node_field_data n
JOIN node__{parentFieldName} ref
  ON ref.entity_id = n.nid AND ref.revision_id = n.vid
JOIN paragraphs_item_field_data p
  ON p.id = ref.{parentFieldName}_target_id
WHERE p.type = '{sourceBundle}' AND n.status = 1
GROUP BY n.type;
```

Compare with total from Step 2. Compute: **orphaned = total − active**.

Flag any bundle where orphaned > 0 with: `⚠️ N orphaned instances (from old revisions) — excluded from migration scope`.

---

### Step 5 — Detect group / container pattern

Check if the bundle acts as a container for child paragraph entities:

```sql
SELECT name FROM config
WHERE name LIKE CONCAT('field.field.paragraph.', '{sourceBundle}', '.%')
  AND data LIKE '%entity_reference_revisions%';
```

If child-reference fields are found:
1. Extract the target child bundle(s) from the `data` column (`target_bundles` key).
2. **Repeat Steps 2–7 for each child bundle**.
3. Count the active children from published content:

```sql
SELECT COUNT(DISTINCT c.{childRefField}_target_id) AS active_children
FROM node_field_data n
JOIN node__{parentFieldName} ref ON ref.entity_id = n.nid AND ref.revision_id = n.vid
JOIN paragraph__{childRefField} c ON c.entity_id = ref.{parentFieldName}_target_id
WHERE n.status = 1;
```

---

### Step 6 — Query source fields

**Drupal 8+** — Fetch field instance configs:
```sql
SELECT name, data FROM config
WHERE name LIKE CONCAT('field.field.', '{sourceEntityType}', '.', '{sourceBundle}', '.%')
ORDER BY name;
```

Parse the PHP-serialized `data` to extract:
- `label` (`s:5:"label";s:N:"..."`)
- `required` (`s:8:"required";b:1`)
- `translatable` (`s:12:"translatable";b:1`)
- `field_type` (from storage config `s:4:"type";s:N:"..."`)
- `cardinality` (`s:11:"cardinality";i:1` or `i:-1` for unlimited)

If parsing is ambiguous, cross-check by inspecting the actual field table columns:
```sql
SELECT
  REPLACE(TABLE_NAME, CONCAT('{sourceEntityType}', '__'), '') AS field_name,
  GROUP_CONCAT(COLUMN_NAME ORDER BY ORDINAL_POSITION SEPARATOR ', ') AS value_columns
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'drupal_migrate'
  AND TABLE_NAME LIKE CONCAT('{sourceEntityType}', '__field_%')
  AND COLUMN_NAME NOT IN ('bundle','deleted','entity_id','revision_id','langcode','delta')
GROUP BY TABLE_NAME;
```

Use column suffix patterns to infer types:
| Suffix(es) | Field type |
|---|---|
| `_value` only | `string` / `text_long` |
| `_value` + `_format` | `text_formatted_long` |
| `_target_id` + `_target_revision_id` | `entity_reference_revisions` |
| `_target_id` only | `entity_reference` |
| `_uri` + `_title` + `_options` | `link` |
| `_target_id` + `_alt` + `_width` + `_height` | `image` |
| `_value` (boolean storage) | `boolean` |

---

### Step 7 — Measure field population (paragraphs only)

For each field, measure what percentage of active instances actually contain data:

```sql
SELECT
  COUNT(DISTINCT p.id) AS active_instances,
  SUM(f.{fieldName}_value IS NOT NULL) AS populated
FROM paragraphs_item_field_data p
LEFT JOIN paragraph__{fieldName} f ON f.entity_id = p.id
WHERE p.type = '{sourceBundle}';
```

> Use `entity_id` only in the JOIN (not `revision_id`) to avoid false negatives from revision mismatches.

Compute: `ROUND(populated / active_instances * 100)%`. Fields at **0%** are explicit non-migration candidates.

---

### Step 8 — Capture live examples (one screenshot per parent node type)

For each distinct node type identified in Step 4, find the most recently updated published node that uses the entity 
being analysed, resolve its public URL using the production node list, and take a partial screenshot. 
This provides visual evidence of the component in context for the migration issue.

#### 8a — Find the most recently updated published node per type

For **paragraphs with a direct node parent** (parent_type = 'node'), use the parent field identified in Step 4:

```sql
SELECT
  n.type AS node_type,
  n.nid
FROM node_field_data n
JOIN node__{parentFieldName} ref
  ON ref.entity_id = n.nid AND ref.revision_id = n.vid
JOIN paragraphs_item_field_data p
  ON p.id = ref.{parentFieldName}_target_id
WHERE p.type = '{sourceBundle}' AND n.status = 1
  AND n.type = '{nodeType}'
ORDER BY n.changed DESC
LIMIT 1;
```

Run once per distinct node type (adjust `WHERE n.type = '{nodeType}'`). Pick the first row returned (most recently changed).

For **nested paragraphs** (where parent_type = 'paragraph', i.e. the paragraph is a child of another paragraph), trace one additional level up to find the root node:

```sql
SELECT
  n.type AS node_type,
  n.nid
FROM paragraphs_item_field_data child
JOIN paragraphs_item_field_data parent
  ON parent.id = child.parent_id AND child.parent_type = 'paragraph'
JOIN node__{parentFieldName} ref
  ON ref.{parentFieldName}_target_id = parent.id
JOIN node_field_data n
  ON n.nid = ref.entity_id AND n.vid = ref.revision_id
WHERE child.type = '{sourceBundle}' AND n.status = 1
ORDER BY n.changed DESC
LIMIT 1;
```

#### 8b — Resolve the node UUID from the source database

The production node list is keyed by **node UUID**, not by node ID. For each `nid` obtained in Step 8a, fetch its UUID from the source database:

```sql
SELECT uuid FROM node WHERE nid = {nid};
```

#### 8c — Resolve the public URL from the production node list

Before fetching the node registry, ask the user:

> "Do you have a local copy of the production node list (`https://www.luiss.it/prod/uuid/it`) saved on the filesystem? If yes, please provide the file path — this is faster than fetching it from the network. Otherwise I'll fetch it from the URL."

- If the user provides a **file path**: read the JSON from disk using the `view` or `bash` tool (`cat {path}`).
- If the user says **no** (or provides no path): fetch the registry using the web_fetch tool from:

```
https://www.luiss.it/prod/uuid/it
```

The response is a JSON object where **keys are relative paths** and **values are `entity_type/uuid`** strings, e.g.:

```json
{
  "/ateneo/elezioni-dei-rappresentanti": "page/000a4134-6e1d-48ce-92d7-54d3b69a4f3a",
  "/media/press-office": "page/550e8400-e29b-41d4-a716-446655440000"
}
```

For each `uuid` obtained in Step 8b:
1. Search the JSON values for an entry ending with `/{uuid}` (i.e., `value.endsWith('/' + uuid)`).
2. **If found**: the matching key is the relative path. Build the absolute URL as `https://www.luiss.it` + key (e.g., `https://www.luiss.it/media/press-office`).
3. **If not found**: do **not** attempt to construct a URL. Instead, report in the output:
   > ⚠️ Node `{nid}` (UUID: `{uuid}`, type: `{nodeType}`) was not found in the production node list — no screenshot available. The page may be unpublished, access-restricted, or not indexed.

#### 8d — Navigate and screenshot

For each example node whose URL was successfully resolved in Step 8b:

1. Use the browser tools to navigate to the absolute URL (e.g., `https://www.luiss.it/media/press-office`)
2. Take a **partial screenshot** of the exact portion of the page where the paragraph instances are placed. You can 
   identify the correct portion by looking for the unique combination of node type and bundle in the page's HTML structure 
   (e.g., a `div` with classes `node--type-{nodeType}` and `paragraphs--type-{sourceBundle}`). If the frontend is 
   decoupled you may need to look for other unique markers simlar to the node type and bundle or paragraph ID in the 
   HTML or use visual cues to identify the correct section of the page. If you cannot confidently identify the correct 
   portion, ask the user if you have to take a full-page screenshot instead and annotate in the output that the relevant
   content is present but the screenshot is not focused on it.
3. Save it to the session files folder:
   - Path: `{SESSION_FILES_DIR}/screenshot-{sourceBundle}-{nodeType}-{nid}.png`
   - Example: `~/.copilot/session-state/{currentSessionId}/files/screenshot-circle_group-luisspage-42.png`
3. Include the screenshot filename and the absolute node URL in the analysis output (see Output section below)

> **Note**: The session files folder path is available from the session context (`Session folder:` in the session header). Save screenshots to the `files/` subdirectory within it.

> The production site is public — no authentication is required.

---

### Step 9 — Scan destination fields (optional)

If a destination bundle is known (from context or user input), scan local config:

```
src/drupal/config/sync/field.field.{destEntityType}.{destBundle}.*.yml
```

List available destination fields with type and cardinality to propose mappings.

---

## Output

Present results in this structured format:

---

### 📦 `{sourceBundle}` — Migration Analysis

**Entity type:** `{sourceEntityType}` | **Source:** Drupal 8+

#### Instance counts

| | Total in DB | Active (published) | Orphaned |
|---|---|---|---|
| `{sourceBundle}` | N | **N** | N |

> _(If orphaned > 0)_ ⚠️ N orphaned instances from old node revisions — excluded from migration scope.

#### Parent context _(paragraphs only)_

| Node bundle | Field | Active groups | Active parent nodes |
|---|---|---|---|
| `luisspage` | `field_page_right_column` | N | N |

#### Source fields — `{sourceBundle}` (N active instances)

| Label | Machine name | Field type | Cardinality | Required | Translatable | Population |
|---|---|---|---|---|---|---|
| … | `field_…` | string | 1 | ✓ | ✓ | 100% |

_(If group/container: add a second table for the child bundle with its own active instance count and population data)_

#### Live examples

| Node type | Node ID | URL | Screenshot |
|---|---|---|---|
| `luisspage` | 42 | `https://www.luiss.it/media/press-office` | `screenshot-{sourceBundle}-luisspage-42.png` |

_(One row per distinct parent node type. URL resolved from `https://www.luiss.it/prod/uuid/it`. If a node ID is not found in that list, report it as missing instead of showing a screenshot. Screenshot saved to session `files/` folder for manual attachment to the GitLab issue.)_

#### Proposed mapping → `{destBundle}`

If a destination bundle is known, list proposed field mappings based on label similarity, field type compatibility, and population data. 
Highlight any source fields that have no clear destination match or are not populated (0% population) as non-migration candidates.

If no destination bundle is provided, you should gather the existing destination entity types and bundles from the local 
config and ask the user to select one for mapping, or ask them to add further context or analysis files to help identify
the correct destination bundle. If the user does not select any or does not give you more context , skip this section and note that mapping is TBD.

The following table is an example and should be generated based on actual analysis:
| Source field | Destination field | Notes |
|---|---|---|
| `field_p_title` | `title` | Full name, cannot auto-split into name/surname |
| `field_p_email` | `field_fm_email` | Dedup key; only ~48% populated |
| `field_linkedin` | ❌ Not migrated | 0% populated |

---

After presenting the analysis, ask:

> "Would you like me to generate the GitLab issue description based on this analysis, following the project's migration issue instruction?"

If the user confirms, generate the full issue description following the structure defined in [issue-migrate-requirements.prompt.md](../../../.github/prompts/issue-migrate-requirements.prompt.md) (Phases 3–4). The issue description body must be written in **Italian**.

---

## Guardrails

- **Never use `COUNT(*)`** for instance counts — always `COUNT(DISTINCT id)` or `COUNT(DISTINCT nid)`
- **Never use `mysql` directly** — always use `drush sql:query --database=drupal_migrate`
- **Always verify active vs total** for paragraphs — never report raw DB totals as migration scope
- If the bundle does not exist in the source DB, inform the user and stop
- If no destination bundle is provided, or you are not able to find and propose a destination, skip Step 9 and the mapping table; note that mapping is TBD
- Run independent queries in parallel where possible to minimise elapsed time
- All skill output and user interactions are in **English**; the generated GitLab issue body (if requested) is in **Italian**
