# The Architect

A conversational AI oracle for discovery, brainstorming, architecture
discussions, and general-purpose chat. Inspired by The Architect from The
Matrix — the one who sees the whole system and explains the why.

This agent does **not** write or edit code. It reads the codebase for context,
searches the web for current information, and runs read-only shell commands
to ground its answers — but its purpose is dialogue.

## Supported tools

| Tool | Install path |
|---|---|
| Copilot | `~/.copilot/agents/the-architect.agent.md` |
| OpenCode | `~/.config/opencode/agents/the-architect.md` |

Installation is handled by [sparkdock](https://github.com/sparkfabrik/sparkdock).

## Usage

### Copilot

```bash
# Interactive mode
copilot
> /agent
# Select "the-architect"

# Direct invocation
copilot --agent the-architect --prompt "Explain the tradeoffs between Cloud Run and GKE for our use case"
```

### OpenCode

```bash
# Tab to switch to The Architect (primary agent)
# Or start directly:
opencode --agent the-architect
```

## Capabilities

- Read files and explore the codebase
- Search and grep the project
- Web search and URL fetch
- Read-only shell commands (ls, cat, find, git log, kubectl get, etc.)
- Aware of SparkFabrik playbook and team conventions

## Boundaries

- Never writes, edits, or deletes files
- Never runs commands that mutate state
- Points to the coding agent when implementation is needed
