# System Agents

Cross-cutting agents not tied to a specific technology. Installed externally
via [sparkdock](https://github.com/sparkfabrik/sparkdock).

## Directory layout

Each agent has its own folder with one subfolder per supported tool:

```
agents/system/<agent-name>/
├── copilot/     # GitHub Copilot profile (.agent.md)
└── opencode/    # OpenCode profile (.md)
```

The prompt body is identical across tools — only the YAML frontmatter differs
to match each tool's configuration format. There is no shared standard yet, so
each tool has its own file.

## Install paths

| Tool | Path |
|---|---|
| Copilot | `~/.copilot/agents/<agent-name>.agent.md` |
| OpenCode | `~/.config/opencode/agents/<agent-name>.md` |

## Available agents

- **the-architect** — Conversational AI oracle for discovery, brainstorming, architecture, and general knowledge. Not a code agent. Use it when you need to think, explore, learn, or discuss instead of writing code.
