---
name: sf-commit-convention
description: 'Enforce SparkFabrik commit message and branch naming conventions including conventional commits, legacy format detection, issue references, branch prefixes, and the mandatory Assisted-by trailer. MUST be loaded before EVERY git commit, commit message preparation, MR/PR title creation, branch creation, or any commit-related operation. Use whenever the agent is about to run git commit, git checkout -b, git branch, write a commit message, create a branch, or prepare a merge request or pull request title. Also use when the user mentions "commit", "git commit", "conventional commit", "commit message", "refs #", "assisted-by", "commit convention", "branch name", "new branch", or "feature branch". Never create a commit or branch without consulting this skill first.'
---

# SparkFabrik Commit Convention

This skill enforces SparkFabrik commit message and branch naming conventions. Follow these rules for every commit and branch you create.

## Branch Naming

Create branches following this pattern:

```
<prefix>/<issue-number>-<description>
```

- **All lowercase**, hyphens as word separators
- **Issue number required** (except `release/` branches)
- **Description**: 2-4 words, concise

### Prefixes

| Prefix      | When to use                                               |
| ----------- | --------------------------------------------------------- |
| `feat/`     | New features                                              |
| `fix/`      | Bug fixes                                                 |
| `docs/`     | Documentation only                                        |
| `chore/`    | Maintenance, dependencies, config                         |
| `refactor/` | Code restructuring, no behavior change                    |
| `ci/`       | CI/CD pipeline changes                                    |
| `test/`     | Test additions or fixes                                   |
| `release/`  | Release branches — use `release/vX.Y.Z` (no issue number) |

### Examples

```
feat/42-add-pdf-ingestion
fix/18-oauth-token-refresh
docs/33-update-api-reference
chore/71-bump-dependencies
release/v1.2.0
```

### When to create a branch

When work should happen on a separate branch (new feature, bug fix, or any issue-tracked work), create a branch following this convention before committing. If the user asks to start work on an issue and no branch exists, propose a branch name and confirm with the user before creating it.

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

### Resolving the full project path

**Always use the fully qualified project path in footers.** Run `git remote get-url origin` and parse the namespace/project path (e.g., `sparkfabrik/sf-awesome-copilot` on GitHub, `sparkfabrik-innovation-team/r-d/ai/project` on GitLab).

When the user provides a bare `#N`, resolve it to `<project-path>#N`:

| User provides      | Footer                                                                  |
| ------------------ | ----------------------------------------------------------------------- |
| `#35`              | `Refs: owner/repo#35` or `Closes: owner/repo#35` (resolved from remote) |
| `owner/project#35` | `Refs: owner/project#35` or `Closes: owner/project#35` (used as-is)     |

Use `Closes:` when the commit fully resolves the issue. Use `Refs:` otherwise.

### Legacy format

The issue reference is part of the subject line (`refs #N: ...`). No separate footer is needed.

## Assisted-by Trailer

**Mandatory on every commit**, regardless of format (legacy or conventional).

- Format: `Assisted-by: <agentname>/<full-model-id>` (agent name MUST be all lowercase)
- Applied via `--trailer` flag on `git commit`
- Substitute your own runtime identity (agent name and model ID)

Example for opencode with claude-opus-4.6:

```
Assisted-by: opencode/github-copilot/claude-opus-4.6
```

## MR/PR Titles

Follow the same conventional commit format as the subject line. Issue reference goes in the MR/PR description body, never in the title.

## Git Command Examples

### Conventional, same-project issue

```bash
git commit -m "feat(rag): add document ingestion pipeline" \
  --trailer "Refs: owner/repo#35" \
  --trailer "Assisted-by: opencode/github-copilot/claude-opus-4.6"
```

### Conventional, cross-project issue

```bash
git commit -m "feat(rag): add document ingestion pipeline" \
  --trailer "Refs: sparkfabrik-innovation-team/r-d/ai/poc-drupal-rag-intelligence#35" \
  --trailer "Assisted-by: opencode/github-copilot/claude-opus-4.6"
```

### Conventional, auto-closing same-project issue

```bash
git commit -m "fix(discovery): handle symlink loops in file scanning" \
  --trailer "Closes: owner/repo#42" \
  --trailer "Assisted-by: opencode/github-copilot/claude-opus-4.6"
```

### Conventional, no issue (user confirmed none)

```bash
git commit -m "chore(deps): bump lockfile" \
  --trailer "Assisted-by: opencode/github-copilot/claude-opus-4.6"
```

### Legacy format

```bash
git commit -m "refs #35: add document ingestion pipeline" \
  --trailer "Assisted-by: opencode/github-copilot/claude-opus-4.6"
```
