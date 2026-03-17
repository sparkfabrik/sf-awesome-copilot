# Migration Issue Requirements

Use this template whenever an agent or skill needs to generate a migration issue description.

This is a **generic template** — it is not tied to any specific project. Project-specific overrides
(section names, output language, Definition of Done) should be placed in `.github/prompts/migrate-instructions.prompt.md`.

---

## Phase 1 — Ask the User

Before generating the issue body, collect answers to the following questions. Do not skip any question.

### Source details
> "What is the source entity type and bundle? (e.g., `paragraph / profile_card_with_modal`, `node / news`)"

### Scope
> "How many active (published) instances are in scope? (Use the count from the analysis report, or provide the number.)"

### Content structure
> "Which source fields need to be migrated? Do you already have a destination field mapping? If yes, paste the mapping table. If no, I will use the proposed mapping from the source analysis."

### Data volumes
> "Are there any data volume concerns? (e.g., large file attachments, high record counts, performance constraints)"

### Dependencies and modules
> "Are there prerequisite migrations, Drupal modules, or hard blockers to list in the issue?"

### Multilingual / variants
> "Does this entity have translations or language variants that must be covered by the migration?"

### Example records
> "Do you have example source records, screenshots, or reference URLs to include? If yes, provide file paths or URLs. Do NOT share production credentials or personally identifiable information."

### Definition of Done
> "Does your project use a custom Definition of Done checklist? If yes, paste it here. If no, a standard checklist will be used."

### Issue language
> "In which language should the issue body be written? (default: English)"

---

## Phase 2 — Generate Issue Description

Use the collected answers to fill in the following template. Write the issue body in the language specified by the user.

```markdown
## Objective

<!-- High-level description of what is being migrated and why.
     Include: entity type, bundle, number of active instances, business context.
     Do NOT include production URLs, credentials, or raw user data. -->

## Context and Analysis

<!-- Summary of the source analysis:
     - Entity type and bundle
     - Active instance count (orphaned instances excluded)
     - Parent context (paragraphs only: which node bundles host this paragraph)
     - Notable field population findings (e.g., fields at 0% → non-migration candidates)
     - Example records or screenshots provided by the user (attach as links or images) -->

## Requirements

<!-- Field-by-field migration checklist. One checkbox per source field. -->

- [ ] `source_field` → `destination_field` (notes)
- [ ] `source_field` → TBD *(destination not yet identified)*

## Dependencies

<!-- List prerequisite migrations, required Drupal modules, or blockers.
     Use checklist format if ordering matters. -->

## Notes

<!-- Implementation caveats, edge cases, open questions, or deduplication rules.
     Do NOT include production data. -->

## To do

<!-- Leave empty — this section is reserved for the developer. -->

## Definition of Done

<!-- Insert the exact Definition of Done checklist provided by the user.
     If the user did not provide one, use this standard checklist:

- [ ] Implementation
- [ ] Multilingual handling
- [ ] Rollback and re-import test
- [ ] End-to-end test
- [ ] Documentation
- [ ] Code review
-->
```

---

## Guardrails

- **Exclude production data**: never include database credentials, raw content from production, or personally identifiable information in the issue body.
- **Leave "To do" empty**: this section is reserved for the developer. Do not pre-populate it.
- **Objective is high-level only**: do not add YAML examples, plugin names, or developer task lists in "Objective" or "Context".
- **DoD from user or standard**: use the checklist provided by the user. If none given, use the standard items above. Do not invent project-specific checklist items.
- **Language**: respect the user's choice from Phase 1. Default is English.
