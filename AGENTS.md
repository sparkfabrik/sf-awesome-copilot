# SF Awesome Copilot

## Project Overview

Experimental catalog of skills, agents and prompts for GitHub Copilot. Inspired by [github/awesome-copilot](https://github.com/github/awesome-copilot).

This content is largely AI-generated and experimental.

## Repository Structure

```
.
├── agents/           # Custom GitHub Copilot agent definitions (.agent.md files)
├── skills/           # Agent Skills folders (each with SKILL.md and optional bundled assets)
```

## File Formats

### Agent Files (*.agent.md)

- Must have `description` field (wrapped in single quotes)
- File names should be lowercase with words separated by hyphens
- Recommended to include `tools` field
- Strongly recommended to specify `model` field

```markdown
---
name: 'agent-name'
description: 'Short description of what the agent does'
tools: ['tool1', 'tool2']
model: 'gpt-4o'
---

# Agent Title

Instructions and context for the agent...
```

### Agent Skills (skills/*/SKILL.md)

- Each skill is a folder containing a `SKILL.md` file
- SKILL.md must have `name` field (lowercase with hyphens, matching folder name)
- SKILL.md must have `description` field (wrapped in single quotes)
- Folder names should be lowercase with words separated by hyphens
- Skills can include bundled assets (scripts, templates, data files)

```markdown
---
name: skill-name
description: 'Short description for when to use this skill'
---

# Skill Title

Content with examples, commands, code snippets...
```

## Code Style

- Use proper front matter with required fields
- Keep descriptions concise and informative
- Wrap description field values in single quotes
- Use lowercase file names with hyphens as separators
- Write in English
- Keep documentation dry and practical
- Avoid excessive emojis or AI-slop language
- Include working examples

## Adding New Resources

### For Agents

1. Create the `.agent.md` file with proper front matter
2. Add the file to the appropriate directory under `agents/`
3. Test with GitHub Copilot

### For Skills

1. Create a new folder under `skills/<technology>/`
2. Add a `SKILL.md` file with proper front matter
3. Add any bundled assets (scripts, templates, data) to the skill folder
4. Test with GitHub Copilot

## References

- [AGENTS.md specification](https://agents.md/)
- [Agent Skills specification](https://agentskills.io/specification)
- [VS Code custom instructions](https://code.visualstudio.com/docs/copilot/customization/custom-instructions)
- [GitHub Awesome Copilot](https://github.com/github/awesome-copilot)
