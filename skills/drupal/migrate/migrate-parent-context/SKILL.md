---
name: migrate-parent-context
description: Identify the parent context for a paragraph bundle in the source database. Shows which entity types, fields, and node bundles reference a given paragraph type. Use after counting instances to understand where a paragraph is used.
---

# Identify Paragraph Parent Context

For a paragraph bundle, identify which entity types and fields reference it, and which node bundles contain it.

---

## Project Configuration

Before executing, check for a project-specific configuration file at:
`.github/prompts/migrate-instructions.prompt.md`

If it exists, read the **Database Connection** section for the drush database option and any custom table names.

---

## Prerequisites

- Source database connection verified (`migrate-db-discover`)
- Applies to **paragraph** entity types only

---

## Input

- **bundle**: The paragraph bundle machine name (e.g., `profile_card_with_modal`)

---

## Steps

### Step 1 — Identify parent types and fields

```sql
SELECT parent_type, parent_field_name, COUNT(DISTINCT id) AS instances
FROM paragraphs_item_field_data
WHERE type = '{bundle}'
GROUP BY parent_type, parent_field_name
ORDER BY instances DESC;
```

This shows:
- Which entity types reference this paragraph (e.g., `node`, `paragraph` for nested cases)
- Which field names hold the reference (e.g., `field_page_right_column`)
- How many instances per parent field

### Step 2 — Identify node bundles (when parent is node)

If any `parent_type` is `node`, identify which node bundles:

```sql
SELECT n.type AS node_bundle, COUNT(DISTINCT n.nid) AS node_count
FROM node_field_data n
JOIN paragraphs_item_field_data p ON p.parent_id = n.nid AND p.parent_type = 'node'
WHERE p.type = '{bundle}'
GROUP BY n.type
ORDER BY node_count DESC;
```

### Step 3 — Handle nested paragraphs (when parent is paragraph)

If any `parent_type` is `paragraph`, this is a nested/child paragraph. Trace one level up:

```sql
SELECT parent.type AS parent_paragraph_bundle, parent.parent_type AS grandparent_type,
  COUNT(DISTINCT child.id) AS instances
FROM paragraphs_item_field_data child
JOIN paragraphs_item_field_data parent ON parent.id = child.parent_id AND child.parent_type = 'paragraph'
WHERE child.type = '{bundle}'
GROUP BY parent.type, parent.parent_type
ORDER BY instances DESC;
```

If the grandparent is a node, also identify the node bundles:

```sql
SELECT n.type AS node_bundle, COUNT(DISTINCT n.nid) AS node_count
FROM paragraphs_item_field_data child
JOIN paragraphs_item_field_data parent ON parent.id = child.parent_id AND child.parent_type = 'paragraph'
JOIN node_field_data n ON n.nid = parent.parent_id AND parent.parent_type = 'node'
WHERE child.type = '{bundle}'
GROUP BY n.type
ORDER BY node_count DESC;
```

### Step 4 — Report results

Output the parent context table:

```
#### Parent context — `{bundle}`

| Parent type | Parent field | Instances | Node bundles |
|---|---|---|---|
| `node` | `field_page_right_column` | N | `luisspage` (N), `news` (N) |
| `paragraph` | `field_items` | N | (nested in `card_group`) |
```

---

## Output

- **parent_contexts**: List of (parent_type, parent_field_name, instance_count)
- **node_bundles**: For node parents, which node bundles and how many
- **nesting_info**: For paragraph parents, the parent paragraph bundle and grandparent chain

---

## Guardrails

- This skill is only for paragraph entity types — skip for nodes, taxonomy terms, users
- Always use `COUNT(DISTINCT id)` for paragraph counts
- If `paragraphs_item_field_data` doesn't exist, try `paragraphs_item` (Drupal 7) and adjust queries
- Report all parent contexts, even if some have very low instance counts — this helps identify edge cases
