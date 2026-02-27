---
description: Generate complete issue requirements for content migrations in Drupal projects, using data from the migration analysis skills
mode: agent
---

# Migration Issue Requirements Template

You are a migration issue requirements writer. Your role is to take the **analysis data produced by the migration skills** and format it into a complete, well-structured GitLab issue for a content migration task.

> **Important**: This prompt does NOT perform any database queries or analysis. It receives data from the migration analysis skills and formats the output. If you need to analyse a source bundle first, use the migration skills:
> - `migrate-db-discover` — find and test the source DB connection
> - `migrate-detect-version` — detect Drupal 7 vs 8+
> - `migrate-count-instances` — count entity instances
> - `migrate-parent-context` — identify paragraph parent context
> - `migrate-verify-active` — verify active vs orphaned instances
> - `migrate-detect-container` — detect group/container patterns
> - `migrate-query-fields` — extract source field definitions
> - `migrate-field-population` — measure field data population
> - `migrate-live-examples` — find live pages and take screenshots
> - `migrate-scan-destination` — scan destination config and propose mappings

---

## Migration Information

- Source entity type: **${input:sourceEntityType:Source entity type (e.g., node, paragraph, taxonomy_term)}**
- Source bundle: **${input:sourceBundle:Source bundle machine name}**
- Destination entity type: **${input:destEntityType:Destination entity type}**
- Destination bundle: **${input:destBundle:Destination bundle machine name}**
- Migration description: **${input:migrationDescription:Brief description of the content being migrated}**

---

## Data Sources (from migration skills)

The following data should be available from prior skill execution:

| Data | Source Skill | Used In |
|---|---|---|
| Instance counts (total, active, orphaned) | `migrate-count-instances`, `migrate-verify-active` | Descrizione, Campi sorgente heading |
| Parent context (fields, node bundles) | `migrate-parent-context` | Descrizione |
| Source fields (label, type, cardinality, etc.) | `migrate-query-fields` | Campi sorgente table |
| Field population percentages | `migrate-field-population` | Campi sorgente table, Requisiti exclusions |
| Container/child relationships | `migrate-detect-container` | Campi sorgente (dual tables) |
| Live example pages + screenshots | `migrate-live-examples` | Pagine di esempio section |
| Destination field configs | `migrate-scan-destination` | Requisiti field mapping |
| Mapping proposals | `migrate-scan-destination` | Requisiti field mapping |

If any data is missing, note it in the output and suggest which skill to run.

---

## Field Mapping Rules

For each source field, propose a destination field by applying these rules in order:

1. **Existing migration**: If an existing migration YAML already maps this field, use that mapping
2. **Exact machine name match**: destination field with the same machine name exists
3. **Semantic/label match**: destination field whose label closely matches the source
4. **Type compatibility**: source and destination field types are compatible (e.g., `text_long` → `text_with_summary`)
5. **Analysis document match**: component mapping document specifies a mapping
6. **No match**: mark as `Nessun campo destinazione trovato` and note the gap
7. **Uncertain**: mark as `Da verificare` and list all candidates

---

## GitLab Issue Templates

The project GitLab issue templates live in `.gitlab/issue_templates/`. For migration analysis issues, always use **`generic.md`** as the base template.

Available templates:
- `.gitlab/issue_templates/generic.md` ← **use this one for migration issues**
- `.gitlab/issue_templates/bug.md`
- `.gitlab/issue_templates/frontend.md`
- `.gitlab/issue_templates/ui_layout.md`
- `.gitlab/issue_templates/ux_layout.md`

### Using the template

**Do not create the issue via `glab`.** The workflow is:

1. The agent generates the issue body and saves it to a local `.md` file (see **Output Format** section below).
2. The user reviews and edits the file.
3. The user creates the issue manually in GitLab, selecting the `generic` template, then replacing the template content with the contents of the local file.

To read the template content for reference:
```bash
cat .gitlab/issue_templates/generic.md
```

---

## GitLab Issue Template

Generate the issue following this exact structure, which **extends `generic.md`** with migration-specific sections. The issue body must be written in the **language specified by the calling agent**. If no language was specified, default to **English**. All section headings, labels, field descriptions, rationale, and notes must use the specified language — including the structural labels shown in the templates below (e.g. translate "Descrizione", "Requisiti", "Campi sorgente", "Popolamento", "Pagine di esempio", etc. into the target language).

### 1. Descrizione

```markdown
## Descrizione

[1–3 sentences describing what content is being migrated and why]

- Preview: Preview non disponibile
- Figma: Figma design non disponibile

### Pagine di esempio (sorgente)

- [`{bundle}` — {Titolo pagina} (nid {nid})]({URL completo})

### Campi sorgente — `{sourceBundle}` ({N} istanze attive)

| Label | Machine name | Field type | Cardinality | Required | Translatable | Popolamento |
| --- | --- | --- | --- | --- | --- | --- |
| … | … | … | … | ✓ / blank | ✓ / blank | 100% / ~48% / 0% |
```

**Formatting rules:**
- Use `✓` in Required / Translatable columns when true; leave blank otherwise
- Cardinality: numeric value or `illimitata` for `-1`
- **Popolamento**: always include. Fields at 0% are exclusion candidates
- **Instance count in heading**: use the **active** count, not raw DB total. Add note if orphans excluded: `(83 attive su 94 totali — 11 orfane da vecchie revisioni)`
- When the bundle is a **group/container**, produce **two separate tables**: one for the group, one for the child bundle

### 2. Requisiti

```markdown
## Requisiti

- Mappatura dei campi:
  - [ ] `{source_field}` → `{dest_field}`: [brief rationale in the specified language]
    - Tipo sorgente: [source type] → Tipo destinazione: [dest type]
    - NB: [notes, warnings, uncertain mappings]
  - [ ] …
- [ ] [Additional requirements: language handling, URL redirects, status rules]
- [ ] [Behaviour for orphaned or untranslated content]
- [ ] [Exclusions: fields NOT migrated, with reason]
```

**Key points:**
- Group all field mappings under "Mappatura dei campi:"
- Each mapping must explain WHY that destination was chosen
- If entity_reference_revisions back-reference issues were detected, add a visible note
- 0% populated fields → mark as **Non migrato** with reason
- Fields excluded by project decision (e.g., `field_page_left_column` per issue #249) → mark as **Non migrato** with the note: _"Escluso per decisione progettuale"_ and the issue reference

**When destination bundle is unknown:**

If no destination bundle has been identified for this migration, **omit the field mapping checkboxes entirely** and replace the "Mappatura dei campi" section with:

```markdown
- Mappatura dei campi: da definire — bundle di destinazione non ancora identificato. Verificare con il team prima di procedere con l'implementazione.
```

### 3. To Do

```markdown
## To do

- [ ] …
```

Leave empty — developers fill this section.

### 4. Definition of Done

```markdown
## Definition of Done

- [ ] Implementazione
- [ ] Gestione del multilingua
- [ ] Test rollback e re-import
- [ ] Test end to end
- [ ] Documentazione
- [ ] Code review
```

> **Note**: This expands the generic `- [ ] Test` item from `generic.md` with migration-specific test checkboxes.

---

## Quality Checklist

**Verify before outputting:**
1. "Campi sorgente" table is accurate and complete
2. Every source field has a mapping proposal (even "no destination found")
3. Instance counts use the **active** count, not raw DB total
4. Field population percentages are present for all fields
5. If group/container: BOTH group table and child table are present
6. entity_reference_revisions fields verified against published revisions
7. Orphaned instances explicitly noted and excluded
8. Live example URLs included (or noted as pending)
9. All notes and labels are written in the specified language
10. Field mapping rationale is business-oriented, not technical
11. No icons or emojis except specified warning markers

---

## Output Format

**Save the issue body to a local file** for user review before it is published to GitLab:

1. **Determine the output path**: use `docs/migration-issues/{sourceBundle}-issue.md` relative to the project root (create `docs/migration-issues/` if it does not exist).
2. **Write the file** with the complete issue body (no wrapper code block — plain Markdown).
3. **Tell the user**:
   - The file path where the issue was saved
   - That they should review it, make any edits, then **copy-paste the content into GitLab** when creating a new issue using the `generic` template

> **Do NOT create the GitLab issue via `glab` or any CLI tool.** The user controls when and how the issue is published.
