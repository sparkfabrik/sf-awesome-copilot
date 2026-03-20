---
name: playwright-cli
description: 'Browser automation with the playwright-cli CLI tool. Use when the user needs to automate browser interactions, navigate websites, test web applications, take screenshots, fill forms, extract data from web pages, or interact with headless browsers. Also use when the user mentions "playwright-cli", "playwright", "browser automation", "headless browser", "web scraping", "screenshot", "snapshot", "browser testing", or wants to open, click, fill, or type in a web page.'
allowed-tools: Bash(playwright-cli:*)
---

# Browser Automation with playwright-cli

CLI interface for Playwright. Token-efficient alternative to Playwright MCP -- designed for coding agents that work within limited context windows.

For the full command reference and examples, see [upstream/SKILL.md](upstream/SKILL.md).

## Task-specific guides

- **Request mocking** -- [upstream/references/request-mocking.md](upstream/references/request-mocking.md)
- **Running Playwright code** -- [upstream/references/running-code.md](upstream/references/running-code.md)
- **Browser session management** -- [upstream/references/session-management.md](upstream/references/session-management.md)
- **Storage state (cookies, localStorage)** -- [upstream/references/storage-state.md](upstream/references/storage-state.md)
- **Test generation** -- [upstream/references/test-generation.md](upstream/references/test-generation.md)
- **Tracing** -- [upstream/references/tracing.md](upstream/references/tracing.md)
- **Video recording** -- [upstream/references/video-recording.md](upstream/references/video-recording.md)

---

## Output file conventions

By default, playwright-cli writes screenshots, PDFs, and other output files to the current working directory, which is usually the project root. This clutters the repo with temporary files that shouldn't be committed.

**Always use `--filename=` with a path under `.playwright-cli/`** to keep output files in a dedicated directory.

### Per-type examples

| Type | Command |
|------|---------|
| Screenshot | `playwright-cli screenshot --filename=.playwright-cli/screenshot-login.png` |
| Element screenshot | `playwright-cli screenshot e5 --filename=.playwright-cli/button-detail.png` |
| PDF | `playwright-cli pdf --filename=.playwright-cli/page.pdf` |
| Video | `playwright-cli video-stop .playwright-cli/session-recording.webm` |
| Snapshot | Already defaults to `.playwright-cli/` -- no change needed |
| Trace | `playwright-cli tracing-stop` writes to `traces/` by default -- keep this default |

### Naming

Use descriptive filenames that reflect what the output captures:

```bash
# GOOD -- clear purpose
playwright-cli screenshot --filename=.playwright-cli/screenshot-after-login.png
playwright-cli screenshot --filename=.playwright-cli/screenshot-error-state.png

# AVOID -- auto-generated timestamps are hard to reference
playwright-cli screenshot
```

### .gitignore

Add these entries to the project's `.gitignore` to prevent output files from being committed:

```
.playwright-cli/
traces/
```

### Cleanup

`playwright-cli close` does not remove output files. When output files are no longer needed, remove them or inform the user where they were saved so they can decide.
