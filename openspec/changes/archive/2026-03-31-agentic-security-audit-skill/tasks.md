## 1. Skill Directory and SKILL.md

- [ ] 1.1 Create `skills/system/agentic-security-audit/` directory structure with `references/` subdirectory
- [ ] 1.2 Write `skills/system/agentic-security-audit/SKILL.md` with frontmatter (name, description) and full skill body: Phase 1 Discovery, Phase 2 Review (ASI01-ASI10 checklist), Phase 3 Report generation
- [ ] 1.3 Verify SKILL.md includes the discovery detection table from the agentic-discovery spec
- [ ] 1.4 Verify SKILL.md includes the applicability mapping table from the design (which ASI categories apply when)
- [ ] 1.5 Verify SKILL.md includes the report structure from the agentic-report spec

## 2. OWASP Agentic Top 10 Reference

- [ ] 2.1 Write `skills/system/agentic-security-audit/references/owasp-agentic-top10.md` covering all ten ASI categories (ASI01-ASI10)
- [ ] 2.2 Each category section must include: risk description, what to look for (concrete code/config patterns), vulnerable vs safe examples, detection guidance
- [ ] 2.3 Verify patterns match those listed in the agentic-review-checklist spec

## 3. Instruction File Audit Reference

- [ ] 3.1 Write `skills/system/agentic-security-audit/references/instruction-file-audit.md` covering risk patterns for instruction files
- [ ] 3.2 Include per-tool sections: GitHub Copilot, Cursor, OpenCode, Aider, MCP, generic (AGENTS.md, SKILL.md)
- [ ] 3.3 Each tool section must document: file location, format, security considerations, example vulnerable patterns, recommended hardening

## 4. Project Integration

- [ ] 4.1 Add the new skill entry to the skills table in `README.md`
- [ ] 4.2 Add entry to `CHANGELOG.md` under today's date
- [ ] 4.3 Create symlink at `~/.agents/skills/agentic-security-audit` pointing to the skill directory
