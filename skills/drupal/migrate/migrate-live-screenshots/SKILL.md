---
name: migrate-live-screenshots
description: Take browser screenshots of live example pages resolved by migrate-resolve-examples. Optional step — only run after explicit user confirmation. Uses the chrome-devtools MCP server for screenshots.
---

# migrate-live-screenshots

Takes browser screenshots of the live example URLs produced by `migrate-resolve-examples`. This is an **optional step** — always ask the user before running it.

---

## Prerequisites

- `migrate-resolve-examples` must have already run and produced at least one URL.
- The **chrome-devtools MCP server** must be configured in the Copilot/agent environment.
  - Project: https://github.com/ChromeDevTools/chrome-devtools-mcp

### Checking MCP availability

Before attempting any screenshot, verify the chrome-devtools MCP server is available by reading the Copilot MCP config file at:

```
~/.copilot/mcp-config.json
```

Check that a server named `chrome-devtools` is present in the `mcpServers` object. If the file does not exist or the `chrome-devtools` key is absent, stop immediately and inform the user:

> "⚠️ The `chrome-devtools-mcp` server is not set up in your Copilot configuration (`~/.copilot/mcp-config.json`). To enable screenshots, please install and configure it — see https://github.com/ChromeDevTools/chrome-devtools-mcp — then restart your Copilot session and retry."

Do not attempt to use any other browser mechanism as a fallback.

---

## Inputs

- The **Live examples table** produced by `migrate-resolve-examples` (node type, node ID, URL).
- Source bundle name (used for screenshot filename generation).

---

## Steps

### 1. Confirm with the user (mandatory gate)

Before doing anything, ask:

> "Should I take live screenshots of the example pages? This uses the chrome-devtools MCP server and may take some time. You can skip this step if you only need the field analysis."

Only proceed if the user answers **yes**.

### 2. Check chrome-devtools MCP availability

Verify the MCP server is reachable. If not, show the installation message above and stop.

### 3. Take screenshots

For each URL in the Live examples table:

1. Navigate to the URL using the chrome-devtools MCP server.
2. Wait for the page to fully load (network idle or reasonable timeout).
3. Take a full-page screenshot via the MCP screenshot tool.
4. Save the screenshot to the session files folder:
   `/Users/{username}/.copilot/session-state/{currentSessionId}/files/`
5. Use the filename pattern: `screenshot-{bundle}-{node_bundle}-{nid}.png`
   - Example: `screenshot-button_action-luisspage-42.png`

### 4. Update the Live examples table

Add the `Screenshot` column to the existing table:

| Node type | Node ID | URL | Screenshot |
|---|---|---|---|
| `luisspage` | 42 | `https://www.example.com/path` | `screenshot-button_action-luisspage-42.png` |

For pages that failed to load, note the reason in the Screenshot column instead of a filename (e.g., `404 Not Found`, `Timeout`).

---

## Error Handling

- **chrome-devtools-mcp not configured**: Inform the user with installation instructions (see Prerequisites). Do not fall back to other tools.
- **Page returns 4xx/5xx**: Note the HTTP status in the Screenshot column. Do not retry.
- **Page times out**: Note `Timeout` in the Screenshot column. Continue with remaining URLs.
- **URL is `URL not found`**: Skip — no screenshot possible.
