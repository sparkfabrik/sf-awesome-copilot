---
name: migrate-scan-destination
description: Scan destination Drupal configuration for field mapping proposals. Reads local config YAML files and project analysis documents to propose source-to-destination field mappings. Use after querying source fields.
---

# Scan Destination Fields and Propose Mappings

Scan the local Drupal configuration files to find destination entity fields and propose source-to-destination field mappings.

---

## Prerequisites

- Source fields queried (`migrate-query-fields`)
- Knowledge of destination entity type and bundle

---

## Input

- **dest_entity_type**: Destination entity type (e.g., `node`, `paragraph`)
- **dest_bundle**: Destination bundle machine name (e.g., `internal_page`, `text`)
- **source_fields**: List of source fields (from `migrate-query-fields`)

If no destination bundle is provided, try to determine it:
1. Check project analysis documents (`.github/prompts/migrate-instructions.prompt.md` → Analysis Documents section) for component mapping CSVs
2. List available destination bundles from config:
   ```bash
   ls src/drupal/config/sync/core.entity_form_display.{dest_entity_type}.*.yml 2>/dev/null | sed 's/.*\.\(.*\)\.default\.yml/\1/' | sort -u
   ```
3. Ask the user to select one, or confirm that mapping is TBD

---

## Steps

### Step 1 — Read destination field configs

Find field instance configs:
```bash
ls src/drupal/config/sync/field.field.{dest_entity_type}.{dest_bundle}.*.yml 2>/dev/null
```

For each YAML file, read and extract:
- `field_name` (from filename or YAML key)
- `field_type` / `type`
- `label`
- `required`
- `translatable`
- `settings` (target bundles for entity references, allowed values, etc.)

Also check field storage configs:
```bash
ls src/drupal/config/sync/field.storage.{dest_entity_type}.*.yml 2>/dev/null
```

Extract `cardinality` from storage configs.

### Step 2 — Check analysis documents

Read the project config for any analysis documents that provide pre-determined mappings:

- Component mapping CSV (e.g., `componenti-agnostici.csv`)
- Any other mapping reference files

Cross-reference the source bundle against these documents.

### Step 3 — Check existing migration configs

Look for existing migration YAML files that already map this source bundle:

```bash
grep -rl "{source_bundle}" src/drupal/web/modules/custom/*/migrations/*.yml 2>/dev/null
grep -rl "{source_bundle}" src/drupal/config/sync/migrate_plus.migration*.yml 2>/dev/null
```

If existing mappings are found, extract the field mapping from the `process` section.

### Step 4 — Propose field mappings

For each source field, propose a destination field using these rules (in priority order):

1. **Existing migration**: If an existing migration YAML already maps this field, use that mapping
2. **Exact machine name match**: `field.field.{dest_entity_type}.{dest_bundle}.{source_field_name}.yml` exists
3. **Semantic/label match**: A destination field whose label or purpose closely matches
4. **Type compatibility**: Source and destination field types are compatible
5. **Analysis document match**: The component mapping CSV specifies a mapping
6. **No match**: Mark as `❌ No destination field found`
7. **Uncertain**: Mark as `❓ To verify` and list all candidates

### Step 5 — Report results

```
#### Proposed mapping → `{dest_bundle}`

| Source field | Destination field | Notes |
|---|---|---|
| `field_p_title` | `title` | Exact match by label |
| `field_p_email` | `field_fm_email` | Type compatible, ~48% populated |
| `field_p_linkedin` | ❌ Not migrated | 0% populated |
| `field_p_image` | `field_media_image` | ❓ Verify: source is `image`, dest is `entity_reference` to media |
```

If no destination bundle provided or identifiable:
> "Destination mapping is TBD — no destination bundle was specified or could be determined from analysis documents."

---

## Output

- **dest_fields**: List of destination field objects
- **mapping_proposals**: List of (source_field, dest_field, confidence, notes)
- **unmapped_fields**: Source fields with no destination match

---

## Guardrails

- Do not create or modify any configuration files — this skill is read-only analysis
- If destination bundle cannot be determined, skip mapping and note it as TBD
- Always check existing migration configs first to avoid proposing conflicting mappings
- Population data (from `migrate-field-population`) should inform mapping decisions: 0% populated fields are exclusion candidates
- When type compatibility is uncertain, flag it rather than guessing
