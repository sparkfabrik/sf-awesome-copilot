---

## Non-Claude coding agents (OpenCode, GitHub Copilot CLI, etc.)

The core skill-creator workflow -- draft, test via subagents, review with the user, improve, repeat -- works with any coding agent that supports skills. Throughout this document, read "Claude Code" as your current agent and "subagent" as your parallel task mechanism (e.g., the Task tool in OpenCode).

When the instructions say "run claude-with-access-to-the-skill on test prompts", use your agent's subagent/task system -- do not shell out to `claude -p`.

### Bundled script compatibility

| Script | Portable | Notes |
|--------|----------|-------|
| `generate_review.py` | Yes | Use `--static <path>` for headless environments |
| `quick_validate.py` | Yes | Requires `pyyaml` |
| `package_skill.py` | Yes | No external dependencies |
| `run_eval.py`, `run_loop.py`, `improve_description.py` | No | Depend on Claude's `--output-format stream-json` event schema, not just the `-p` flag. A binary alias is not sufficient. |

For description optimization, skip the scripts and apply the principles manually: write pushy descriptions with specific trigger keywords, test with edge-case queries, and iterate based on observed triggering behavior.
