---

## Tool-agnostic usage

This skill was written for Claude Code but the workflow applies to any coding agent that supports skills — GitHub Copilot, OpenCode, and others. Read "Claude" / "Claude Code" as your current coding agent throughout.

The bundled scripts (`run_eval.py`, `run_loop.py`, `improve_description.py`) shell out to `claude -p`. GitHub Copilot CLI supports the same `-p` flag, so the scripts work if you alias or swap the binary name. For agents without a `-p` equivalent, run the optimization loop manually — the principles (pushy descriptions, edge-case coverage, near-miss negatives) are tool-agnostic.
