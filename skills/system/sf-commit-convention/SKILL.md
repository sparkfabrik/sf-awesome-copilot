---
name: sf-commit-convention
description: 'Enforce SparkFabrik commit message conventions including conventional commits, legacy format detection, issue references, and the mandatory Assisted-by trailer. MUST be loaded before EVERY git commit, commit message preparation, MR/PR title creation, or any commit-related operation. Use whenever the agent is about to run git commit, write a commit message, or prepare a merge request or pull request title. Also use when the user mentions "commit", "git commit", "conventional commit", "commit message", "refs #", "assisted-by", or "commit convention". Never create a commit without consulting this skill first.'
---

# SparkFabrik Commit Convention

This skill enforces SparkFabrik commit message conventions. Follow these rules for every commit you create.

## Format Detection

SparkFabrik is transitioning from a legacy commit format to conventional commits. Detect which format the project uses:

1. Attempt the commit using **conventional commit** format (the preferred default).
2. If a `commit-msg` git hook rejects the commit, retry using **legacy format**.
3. Cache the detected format for the rest of the session — do not re-detect on subsequent commits.

Do not scan `git log` preemptively. Let the hook be the source of truth.

## Conventional Commits (preferred)

```
<type>(<scope>): <description>
```

- **Types**: `feat`, `fix`, `chore`, `test`, `docs`, `refactor`, `style`, `perf`, `ci`, `build`, `revert`
- **Scope**: optional but recommended — use the component or area being changed
- **Description**: lowercase, imperative mood, no trailing period

## Legacy Format (transitional)

```
refs #<issue-number>: <description>
```

- Strictly lowercase `refs`
- Always `#` before the issue number
- Colon + space before description
- Lowercase description, imperative mood
- This format is validated by git hooks in projects still using it
- Cross-project issue references are not supported in legacy format

## Issue References

**Always reference an issue.** If none is apparent from context (branch name, conversation, MR/PR description), ask the user:

> "Is there a related issue to reference? Provide the number (e.g. `#35`) or the full cross-project path (e.g. `owner/project#35`). Type 'none' if there is no related issue."

Skipping the reference is the exception, not the norm. Never silently omit it.

### Same-project vs cross-project

Run `git remote get-url origin` and parse the namespace/project path. Compare against the issue reference:

| Issue reference | Detection | Subject line | Footer |
|---|---|---|---|
| `#35` | Same repo | Append `#35` at end of subject | `Refs: #35` or `Closes: #35` |
| `owner/project#35` | Cross-repo (contains `/`) | Omit from subject (too long) | `Refs: owner/project#35` or `Closes: owner/project#35` |

Use `Closes:` when the commit fully resolves the issue. Use `Refs:` otherwise.

### Legacy format

The issue reference is part of the subject line (`refs #N: ...`). No separate footer is needed.

## Assisted-by Trailer

**Mandatory on every commit**, regardless of format (legacy or conventional).

- Format: `Assisted-by: <AgentName>/<full-model-id>`
- Applied via `--trailer` flag on `git commit`
- Substitute your own runtime identity (agent name and model ID)

Example for OpenCode with claude-opus-4.6:
```
Assisted-by: OpenCode/github-copilot/claude-opus-4.6
```

## MR/PR Titles

Follow the same conventional commit format as the subject line. Issue reference goes in the MR/PR description body (not the title) when cross-project.

## Git Command Examples

### Conventional, same-project issue

```bash
git commit -m "feat(rag): add document ingestion pipeline #35" \
  --trailer "Refs: #35" \
  --trailer "Assisted-by: OpenCode/github-copilot/claude-opus-4.6"
```

### Conventional, cross-project issue

```bash
git commit -m "feat(rag): add document ingestion pipeline" \
  --trailer "Refs: sparkfabrik-innovation-team/r-d/ai/poc-drupal-rag-intelligence#35" \
  --trailer "Assisted-by: OpenCode/github-copilot/claude-opus-4.6"
```

### Conventional, auto-closing same-project issue

```bash
git commit -m "fix(discovery): handle symlink loops in file scanning #42" \
  --trailer "Closes: #42" \
  --trailer "Assisted-by: OpenCode/github-copilot/claude-opus-4.6"
```

### Conventional, no issue (user confirmed none)

```bash
git commit -m "chore(deps): bump lockfile" \
  --trailer "Assisted-by: OpenCode/github-copilot/claude-opus-4.6"
```

### Legacy format

```bash
git commit -m "refs #35: add document ingestion pipeline" \
  --trailer "Assisted-by: OpenCode/github-copilot/claude-opus-4.6"
```
