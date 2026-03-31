## Purpose

Structured markdown report format for agentic security findings, covering AI-specific concerns with severity-ordered findings and OWASP Agentic Top 10 traceability.

## Requirements

### Requirement: Write report to file

The skill SHALL write the audit report to `.agentic-security-audit/report.md`. The report MUST be self-contained and readable by someone who was not present during the audit.

The skill SHALL always write this file -- not just print findings in the chat.

#### Scenario: Report file created after audit

- **WHEN** the audit review phase completes
- **THEN** the skill SHALL write `.agentic-security-audit/report.md` and inform the user of the file path

### Requirement: Report structure

The report SHALL follow this structure:

1. **Metadata table**: project name, date, scope, stacks detected, audit type
2. **Executive summary**: 2-4 sentences on overall agentic security posture
3. **Methodology**: description of the two-phase approach (discovery + review)
4. **Discovery results**: AI files found, dependencies detected, applicable categories
5. **Findings summary**: table with finding count per severity
6. **Detailed findings**: one section per finding with severity, location, category (ASI01-ASI10), description, impact, evidence, recommendation
7. **Checklist coverage**: table showing each ASI category, its status (Reviewed / Not applicable), and notes
8. **Recommendations**: prioritized list of next steps (Immediate / Short-term / Ongoing)

#### Scenario: Report for project with instruction files only

- **WHEN** discovery found only instruction files (no LLM SDK dependencies)
- **THEN** the report SHALL cover ASI04 (Supply Chain) and instruction file findings, mark LLM-dependent categories as "Not applicable", and still include all report sections

### Requirement: Findings ordered by severity

Detailed findings in the report SHALL be ordered by severity: Critical first, then High, Medium, Low, Info.

#### Scenario: Multiple findings at different severities

- **WHEN** the audit produces 2 High and 3 Medium findings
- **THEN** the report SHALL list the 2 High findings before the 3 Medium findings

### Requirement: Each finding references OWASP category

Each finding in the report SHALL reference the applicable OWASP Agentic Top 10 category (ASI01-ASI10) to provide traceability to the standard.

#### Scenario: Prompt injection finding

- **WHEN** a prompt injection vulnerability is found
- **THEN** the finding SHALL reference ASI01 (Agent Behaviour Hijack)

### Requirement: Show chat preview after writing report

After writing the report file, the skill SHALL show the executive summary and findings summary table in the chat as a preview, then inform the user of the full report path.

#### Scenario: Report written successfully

- **WHEN** `.agentic-security-audit/report.md` is written
- **THEN** the skill SHALL display the executive summary and findings count in the chat and print the file path
