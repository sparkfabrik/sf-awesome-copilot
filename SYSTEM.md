# System Resources

Cross-cutting agents and skills not tied to a specific technology. Installed
externally via [sparkdock](https://github.com/sparkfabrik/sparkdock).

## Directory layout

```
agents/system/<agent-name>/
├── copilot/     # GitHub Copilot profile (.agent.md)
└── opencode/    # OpenCode profile (.md)

skills/system/<skill-name>/
└── SKILL.md     # Skill definition (plus optional bundled assets)
```

### Agents

System agents support multiple tools (Copilot, OpenCode). Each tool gets its
own file in a subfolder, but the prompt body is kept identical across tools --
only the YAML frontmatter differs to match each tool's configuration format.
There is no shared standard yet.

| Tool | Install path |
|---|---|
| Copilot | `~/.copilot/agents/<agent-name>.agent.md` |
| OpenCode | `~/.config/opencode/agents/<agent-name>.md` |

### Skills

System skills follow the standard skill format (folder with `SKILL.md`). They
may include bundled assets such as scripts, reference data, or eval definitions.

## Available agents

- **the-architect** -- Conversational AI oracle for discovery, brainstorming, architecture, and general knowledge. Not a code agent.

## Available skills

- **glab** -- GitLab CLI skill for working with issues, merge requests, CI/CD pipelines, and repositories via the `glab` CLI.
