---
name: drupal-migrate-verify-active
description: Verify active vs orphaned paragraph instances by checking against currently published node revisions. Use after identifying parent context to determine how many paragraph instances are actually in use. Critical for accurate migration scope.
---

# Verify Active vs Orphaned Instances

Compare total paragraph instances against those referenced by the **current published revision** of parent nodes. Paragraphs removed from nodes still exist in the DB — this skill identifies them.

---

## Project Configuration

Before executing, check for a project-specific configuration file at:
`.github/prompts/migrate-instructions.prompt.md`

If it exists, read the **Database Connection** section for the drush database option and any custom table names.

---

## Prerequisites

- Source database connection verified (`migrate-db-discover`)
- Parent context identified (`migrate-parent-context`)
- Applies to **paragraph** entity types only

---

## Input

- **bundle**: The paragraph bundle machine name
- **parent_field_name**: The field on the parent entity that references this paragraph (from `migrate-parent-context`)
- **total_instances**: Total count from `migrate-count-instances`

---

## Steps

### Step 1 — Query active instances against published content

For each parent field identified by `migrate-parent-context`, run:

```sql
SELECT n.type AS node_bundle,
  COUNT(DISTINCT p.id)  AS active_instances,
  COUNT(DISTINCT n.nid) AS parent_nodes
FROM node_field_data n
JOIN node__{parent_field_name} ref
  ON ref.entity_id = n.nid AND ref.revision_id = n.vid
JOIN paragraphs_item_field_data p
  ON p.id = ref.{parent_field_name}_target_id
WHERE p.type = '{bundle}' AND n.status = 1
GROUP BY n.type;
```

> **Key**: The `ref.revision_id = n.vid` JOIN ensures we only count paragraphs from the **current** node revision, not historical ones.

### Step 2 — Handle nested paragraphs

If the paragraph's parent is another paragraph (not a node directly), trace through the parent paragraph to the root node:

```sql
SELECT n.type AS node_bundle,
  COUNT(DISTINCT child.id)  AS active_instances,
  COUNT(DISTINCT n.nid) AS parent_nodes
FROM paragraphs_item_field_data child
JOIN paragraphs_item_field_data parent
  ON parent.id = child.parent_id AND child.parent_type = 'paragraph'
JOIN node__{root_parent_field} ref
  ON ref.{root_parent_field}_target_id = parent.id
JOIN node_field_data n
  ON n.nid = ref.entity_id AND n.vid = ref.revision_id
WHERE child.type = '{bundle}' AND n.status = 1
GROUP BY n.type;
```

### Step 3 — Compute orphaned count

```
orphaned = total_instances - SUM(active_instances across all parent fields)
```

### Step 4 — Report results

```
#### Active vs orphaned — `{bundle}`

| | Total in DB | Active (published) | Orphaned |
|---|---|---|---|
| `{bundle}` | {total} | **{active}** | {orphaned} |
```

If orphaned > 0:
> "⚠️ {orphaned} orphaned instances from old node revisions — excluded from migration scope."

---

## Output

- **active_instances**: Count of paragraph instances in currently published node revisions
- **orphaned_instances**: Count of paragraph instances NOT in current published revisions
- **breakdown_by_node_type**: Active instances per parent node bundle

---

## Guardrails

- Always join on BOTH `entity_id` AND `revision_id` to match the **current** revision
- Filter `n.status = 1` to count only published nodes
- The active count is the **authoritative migration scope** — use this number, not the raw DB total
- If the reference table `node__{parent_field_name}` doesn't exist, check for similarly named tables
- This skill only applies to paragraphs — nodes and taxonomy terms don't have the orphan problem
