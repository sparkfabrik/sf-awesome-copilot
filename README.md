# SF Awesome Copilot

Experimental catalog of skills, agents and prompts for GitHub Copilot.

Inspired by [github/awesome-copilot](https://github.com/github/awesome-copilot/tree/main/prompts).

> **Note:** This project is experimental and the content is largely AI-generated. Use with critical thinking.

## Structure

```
├── agents/          # Custom Copilot agents
├── skills/          # Skills organized by technology
```

## Skills

Skills are documents that provide context to Copilot on specific topics. Each skill contains:

- Description and use cases
- Practical examples
- Commands and code snippets

Browse the `skills/` directory for available categories.

## Agents

Agents are custom Copilot configurations with specific instructions.

Browse the `agents/` directory for available agents.

## Usage

### Prerequisites

> ⚠️ **Warning:** Agent Skills support in VS Code is currently in preview and only available in **VS Code Insiders**.

To enable Agent Skills:

1. Install [VS Code Insiders](https://code.visualstudio.com/insiders/)
2. Enable the setting in your workspace or user settings:

**Via Settings UI:**
- Open Settings (`Ctrl+,` or `Cmd+,`)
- Search for `chat.useAgentSkills`
- Enable the checkbox

**Via JSON configuration** (`.vscode/settings.json`):
```json
{
  "chat.useAgentSkills": true
}
```

### Installing Skills

1. Clone this repository
2. Copy the skills you need to your project's `.github/skills/` directory
3. Copilot will automatically load them when relevant

### Installing Agents

1. Copy the agent files (`.agent.md`) to your project's `.github/` directory
2. Reference them in Copilot chat using `@agent-name`

### Configuring MCP Servers (Optional)

MCP (Model Context Protocol) servers extend Copilot's capabilities by providing access to external tools and documentation.

#### Context7 MCP Server (Recommended)

Context7 provides up-to-date, version-specific documentation for libraries and frameworks. Get a free API key at [context7.com/dashboard](https://context7.com/dashboard).

**Create `.vscode/mcp.json` in your workspace:**

**Remote server (recommended):**
```json
{
  "mcpServers": {
    "context7": {
      "url": "https://mcp.context7.com/mcp",
      "headers": {
        "CONTEXT7_API_KEY": "YOUR_API_KEY"
      }
    }
  }
}
```

**Local server:**
```json
{
  "mcpServers": {
    "context7": {
      "command": "npx",
      "args": ["-y", "@upstash/context7-mcp", "--api-key", "YOUR_API_KEY"]
    }
  }
}
```

**Start the MCP server:** Open Command Palette (`Ctrl+Shift+P`) and run `MCP: List Servers`

**Add a rule** to auto-invoke Context7 (optional):
- Go to `Cursor Settings > Rules` or create `.github/copilot-instructions.md`
- Add: `Always use Context7 MCP when I need library/API documentation, code generation, or configuration steps.`

## Contributing

Contributions are welcome. Keep the style dry and practical.
