---
name: auto-format-doc
description: >
  Auto-format files after creating or modifying them using external formatters
  managed by Just recipes (sjust/ajust). Use this skill whenever you write,
  create, or edit a Markdown file (.md). Also use when the user mentions
  "format markdown", "prettier", "format-md", "format-md-check",
  "auto-format", "auto-format-doc", or asks you to fix or check Markdown
  formatting. This skill applies even if you are not explicitly asked to
  format -- any time a .md file is written or modified, run the formatter on it.
---

# Auto Format

Coding agents should not format files by hand. Instead, after creating or
modifying a file, run the appropriate external formatter. This keeps formatting
consistent across the project and avoids drift between human-written and
agent-written files.

Currently supported: **Markdown (.md)** via Prettier.

## When to run

After **every** Write or Edit operation that produces or modifies a `.md` file,
run the format command on that file. This includes:

- Creating a new Markdown file
- Editing an existing Markdown file
- Renaming or moving a Markdown file (format the new path)

Do **not** attempt to format Markdown content yourself (e.g., adjusting line
length, reflowing paragraphs, fixing list indentation). The formatter handles
all of that. Focus on content; let the tool handle style.

## Platform detection

The command runner depends on the operating system. Detect the platform once
at the start of your session and reuse the result:

```bash
if [[ "$(uname)" == "Linux" ]]; then
    JUST_CMD="ajust"
else
    JUST_CMD="sjust"
fi
```

When in doubt, default to `sjust`.

## Formatting commands

### Markdown (.md)

```bash
$JUST_CMD format-md <path> [<path> ...]
```

- Pass the **specific file path(s)** you just wrote or edited.
- You can pass multiple paths in a single call if you modified several files.
- Do **not** run the command without a path argument -- that would format every
  Markdown file in the project, which is slow and noisy.
- Do **not** run `npx prettier` directly. Always go through the Just recipe so
  the project's Prettier version and config are respected.

**Example -- single file:**

```bash
$JUST_CMD format-md docs/setup.md
```

**Example -- multiple files in one task:**

```bash
$JUST_CMD format-md README.md docs/setup.md CHANGELOG.md
```

### Checking without writing

To verify whether files are correctly formatted without modifying them, use the
check variant:

```bash
$JUST_CMD format-md-check <path> [<path> ...]
```

This exits with a non-zero status if any file is not formatted. It is useful
when the user asks you to verify formatting, in CI pipelines, or before
committing to confirm everything is clean. It never writes to disk.

## Error handling

If the format command fails (e.g., `npx` is not installed, network issues
downloading Prettier, or the Just recipe is missing), **warn the user and
continue**. Formatting is cosmetic -- a failure should not block the task.

Example warning:

> Markdown formatting with `$JUST_CMD format-md` failed. The file content is
> correct but may not match the project's formatting conventions. You can run
> the formatter manually later.

## Rules summary

1. After writing or editing any `.md` file, run `$JUST_CMD format-md <path>`.
2. Always pass explicit file paths -- never run without arguments.
3. Never format Markdown by hand -- delegate to the command.
4. Never call `npx prettier` directly -- use the Just recipe.
5. On failure, warn the user and move on.
