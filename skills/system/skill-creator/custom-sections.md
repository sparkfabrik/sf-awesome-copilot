---

## Tool-agnostic usage

This skill was originally written for Claude Code and other Anthropic tools, but the workflow applies to **any coding agent** that supports skills, including GitHub Copilot, OpenCode, and similar tools. When reading the sections above, apply the following mental substitutions:

| Upstream term | Read as |
|---|---|
| **Claude** / **Claude Code** | your current coding agent |
| **Claude.ai** | any web-based AI chat without filesystem or subagent access |
| **Cowork** | any headless or collaborative coding environment |
| `claude -p` | the CLI interface of your coding agent (see below) |
| "claude-with-access-to-the-skill" | the coding agent with the skill loaded |

### Subagents

The upstream skill mentions spawning subagents for parallel test execution. Not all tools support this. If your coding agent does not support subagents, follow the guidance in the **Claude.ai-specific instructions** section above: run test cases sequentially, present results inline, and skip blind comparison.

### Description optimization

The **Description Optimization** section and its scripts (`run_loop.py`, `run_eval.py`) call `claude -p` as a subprocess. If you are not using Claude Code:

- **Skip the automated optimization loop.** The scripts will not work out of the box with other coding agents.
- **Optimize manually instead.** Review the eval queries with the user, test the current description against them, and iterate on the wording directly. The principles in that section (pushy descriptions, edge-case coverage, near-miss negatives) are tool-agnostic and still apply.

### Triggering mechanics

The section on **How skill triggering works** describes Claude's specific skill-selection behavior. Other tools may trigger skills differently. The general advice still holds: write descriptions that are specific, slightly pushy, and cover the contexts where the skill should activate. Test with your own tool to verify triggering.
