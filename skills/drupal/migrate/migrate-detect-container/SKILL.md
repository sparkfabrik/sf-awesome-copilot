---
name: migrate-detect-container
description: Detect if a paragraph bundle is a group/container that holds child paragraph entities via entity_reference_revisions fields. Use to discover nested paragraph hierarchies before analyzing fields.
---

# Detect Group / Container Pattern

Check whether a paragraph bundle acts as a container for child paragraph entities through `entity_reference_revisions` fields.

---

## Prerequisites

- Source database connection verified (`migrate-db-discover`)
- Source Drupal version detected (`migrate-detect-version`)

---

## Input

- **bundle**: The paragraph bundle machine name
- **source_version**: `drupal7` or `drupal8+`

---

## Steps

### Step 1 — Check for child-reference fields (Drupal 8+)

```sql
SELECT name FROM config
WHERE name LIKE CONCAT('field.field.paragraph.', '{bundle}', '.%')
  AND data LIKE '%entity_reference_revisions%';
```

If any rows are found, this bundle is a container.

### Step 2 — Extract target child bundles (Drupal 8+)

For each matching config row, read the `data` column and look for `target_bundles` in the serialized PHP data:

```sql
SELECT name, data FROM config
WHERE name LIKE CONCAT('field.field.paragraph.', '{bundle}', '.%')
  AND data LIKE '%entity_reference_revisions%';
```

Parse the serialized `data` to extract the `target_bundles` array. These are the child paragraph bundles.

### Step 3 — Check for child-reference fields (Drupal 7)

```sql
SELECT fci.field_name, fcs.type
FROM field_config_instance fci
JOIN field_config fcs ON fci.field_name = fcs.field_name
WHERE fci.entity_type = 'paragraphs_item'
  AND fci.bundle = '{bundle}'
  AND fcs.type = 'paragraphs'
  AND fci.deleted = 0;
```

### Step 4 — Count active children from published content

For each child-reference field found:

```sql
SELECT COUNT(DISTINCT c.{child_ref_field}_target_id) AS active_children
FROM node_field_data n
JOIN node__{parent_field} ref ON ref.entity_id = n.nid AND ref.revision_id = n.vid
JOIN paragraph__{child_ref_field} c ON c.entity_id = ref.{parent_field}_target_id
WHERE n.status = 1;
```

### Step 5 — Report results

**If container:**
```
✅ `{bundle}` is a GROUP/CONTAINER paragraph

Child reference fields:
- `{field_name}` → targets: `{child_bundle_1}`, `{child_bundle_2}`

Active children in published content: {count}

⚠️ Repeat full analysis (count, fields, population) for each child bundle:
- `{child_bundle_1}`
- `{child_bundle_2}`
```

**If not a container:**
```
`{bundle}` is a LEAF paragraph (no child paragraph references)
```

---

## Output

- **is_container**: `true` or `false`
- **child_ref_fields**: List of field names that reference child paragraphs
- **child_bundles**: List of target child paragraph bundle names
- **active_child_count**: Number of active child instances in published content

---

## Guardrails

- Only checks for `entity_reference_revisions` fields (paragraphs references), not regular entity references
- If the bundle is a container, the calling agent should repeat the full analysis pipeline for each child bundle
- This skill detects the container relationship — it does NOT analyse the child bundles themselves
