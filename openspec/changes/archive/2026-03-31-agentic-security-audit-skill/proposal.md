## Why

Codebases increasingly include AI agent instructions (`.github/copilot-instructions.md`, `AGENTS.md`, `.cursorrules`, MCP configs, custom skills) and LLM integration code (prompt construction, tool definitions, RAG pipelines). These create a new attack surface that traditional security auditing doesn't cover. The OWASP Top 10 for Agentic Applications (2026) formalizes the risk categories — prompt injection, tool misuse, memory poisoning, instruction supply chain attacks — but no structured audit workflow exists to check for them in real codebases. A separate skill from `security-audit` is needed because the targets are different (AI integration layer vs application logic), the tooling is different (mostly LLM-driven review, few automated scanners), and the checklist is entirely distinct (OWASP Agentic Top 10 vs OWASP Web Top 10).

## What Changes

- Create a new skill at `skills/system/agentic-security-audit/SKILL.md` with a structured audit workflow for agentic/AI security concerns.
- The skill audits four areas: **instruction files** (prompt supply chain), **tool configuration** (what agents can do), **LLM integration code** (how AI is wired in), and **trust boundaries** (who trusts whom).
- Phase 1 discovers AI-related files and dependencies in the project (instruction files, MCP configs, LLM SDK dependencies, vector DB dependencies, prompt templates).
- Phase 2 performs an LLM-driven manual review using a checklist mapped to the OWASP Agentic Top 10 (ASI01-ASI10).
- Phase 3 produces a structured report at `.agentic-security-audit/report.md`.
- Create a reference file `references/owasp-agentic-top10.md` documenting each risk category with concrete code-level patterns to look for, vulnerable/safe examples, and detection guidance.
- Create a reference file `references/instruction-file-audit.md` covering the specific patterns and risks in AI instruction files across tools (Copilot, Cursor, OpenCode, Aider, MCP).

## Capabilities

### New Capabilities

- `agentic-discovery`: Detection of AI/agentic integration in a codebase — instruction files, MCP configs, LLM SDK dependencies, vector DB dependencies, prompt templates in code.
- `agentic-review-checklist`: Manual review checklist mapped to the OWASP Agentic Top 10 (ASI01-ASI10), with concrete code-level patterns for each risk category.
- `instruction-file-audit`: Specific audit methodology for AI instruction files — permission scope, credential exposure, conflicting instructions, injection amplification, implicit trust, stale configs.
- `agentic-report`: Structured markdown report format for agentic security findings, analogous to the `security-audit` skill's report but covering AI-specific concerns.

### Modified Capabilities

_(none — this is a new skill, no existing specs)_

## Impact

- **New directory**: `skills/system/agentic-security-audit/` with SKILL.md and references.
- **No changes to existing `security-audit` skill** — the two skills are complementary and independent. The existing skill audits application code; this one audits the AI integration layer.
- **README.md**: New skill entry in the skills table.
- **CHANGELOG.md**: New entry for the skill addition.
