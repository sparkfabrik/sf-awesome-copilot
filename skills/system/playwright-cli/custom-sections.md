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
