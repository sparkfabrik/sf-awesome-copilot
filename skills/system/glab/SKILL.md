---
name: glab
description: How to use the glab CLI to work with GitLab issues, merge requests, CI/CD pipelines, and repositories. Use this skill whenever the user is working with a GitLab project (self-hosted or SaaS), mentions merge requests, GitLab issues, GitLab CI pipelines, or wants to interact with a GitLab remote. Also use this skill when the user mentions "glab", "MR", "merge request", or when you detect the git remote points to a GitLab instance (look for "gitlab" in the remote URL). This skill is the GitLab equivalent of using `gh` for GitHub -- if the project is on GitLab, use this skill instead.
---

# glab CLI Skill

Use the `glab` CLI for ALL GitLab-related tasks including working with issues, merge requests, CI/CD pipelines, and releases. If given a GitLab URL, use `glab` to get the information needed.

## Before you start

1. **Confirm it's a GitLab project**: check `git remote -v` for "gitlab" in the URL. If so, use `glab` (not `gh`).
2. **Verify authentication**: run `glab auth status`. If not authenticated for the relevant hostname, **stop and ask the user** -- do not proceed.

## CLI-first principle

**Always prefer glab subcommands** (`glab issue list`, `glab mr list`, `glab ci status`, etc.) over raw `glab api` calls. The CLI subcommands provide better output formatting, pagination, and are less error-prone. Use `glab api` **only** when no subcommand covers the operation (see the `glab api` section below).

## Targeting a project

Before running any `glab` command, determine the project context:

1. **User provided a GitLab URL** (e.g., `https://gitlab.example.com/team/project/-/issues/42` or `https://gitlab.example.com/team/project/-/boards/1`):
   Extract the **hostname** and **group/project path** from the URL, then use `GITLAB_HOST` + `-R`:
   ```bash
   # URL: https://gitlab.example.com/team/project/-/boards/123
   # Extracted hostname: gitlab.example.com
   # Extracted path: team/project
   GITLAB_HOST=gitlab.example.com glab issue list -R team/project --milestone "Sprint 1" --all
   GITLAB_HOST=gitlab.example.com glab milestone list --project team/project --state active
   ```

2. **Inside a git repo with a GitLab remote**: no `-R` or `GITLAB_HOST` needed, `glab` detects the project and hostname from the remote automatically.

3. **No URL provided and not inside a git repo**: **ask the user** for the full GitLab project URL before proceeding. Do not guess or assume a project.

### Self-hosted instances: always use `GITLAB_HOST`

For **self-hosted GitLab instances** (anything other than `gitlab.com`), always set the `GITLAB_HOST` environment variable. This is the only reliable method that works across **all** subcommands.

**Do NOT** rely on `-R <hostname>/<group>/<project>` alone -- some subcommands (e.g., `glab milestone list`) ignore the hostname in the `-R` flag and default to `gitlab.com`. Using `GITLAB_HOST` avoids this inconsistency.

**Do NOT** use `--hostname` -- it is not a valid flag on most subcommands (it only works on `glab auth` and `glab api`).

```bash
# CORRECT -- works for ALL subcommands on self-hosted instances:
GITLAB_HOST=gitlab.example.com glab issue list -R team/project --all
GITLAB_HOST=gitlab.example.com glab milestone list --project team/project --state active
GITLAB_HOST=gitlab.example.com glab mr list -R team/project

# WRONG -- may silently hit gitlab.com instead of your self-hosted instance:
glab milestone list -R gitlab.example.com/team/project --project team/project
```

## Handling auth errors

If any `glab` command fails with "Unauthenticated", "401", "403", or "connection refused", **stop immediately**. Do NOT work around auth failures with WebFetch, curl, or `gh`. Self-hosted GitLab instances are private -- those fallbacks will also fail.

Present the user with these options:

### Option 1: OAuth login (preferred -- more secure, tokens auto-refresh)

```bash
glab auth login --hostname <hostname> --use-keyring
# Select "Web" → browser opens → authorize → done
```

If OAuth fails (no OAuth app configured on the instance), fall back to a PAT.

### Option 2: Personal Access Token

Check git protocol to recommend minimal scopes:

- **SSH users** (`git@...` remote): `api` scope is sufficient
- **HTTPS users** (`https://...` remote): `api` + `write_repository`

Tell the user to generate a token at: `https://<hostname>/-/user_settings/personal_access_tokens?scopes=api,write_repository` — recommend a short expiry (30-90 days).

```bash
glab auth login --hostname <hostname> --token <token> --use-keyring
```

### Option 3: Skip the operation

**Always use `--use-keyring`** to store credentials in the OS keyring. Never store tokens in plaintext config.

## Core terminology

| GitHub | GitLab | CLI |
|--------|--------|-----|
| Pull Request | **Merge Request** | `glab mr` |
| Gist | **Snippet** | `glab snippet` |
| Actions | **CI/CD** | `glab ci` |
| `OWNER/REPO` | `GROUP/PROJECT` (supports nesting: `GROUP/SUBGROUP/PROJECT`) | -- |
| PR `#15` | MR `!15` | -- |

Issues use `#`, merge requests use `!`.

---

## Writing comments and notes on behalf of the user

Whenever you post a comment or note on an issue or MR (via `glab issue note`, `glab mr note`, or `glab api` body fields), you **must** prepend the following header to make it clear the message was authored by an AI agent acting on behalf of the user:

```
🤖 *This comment was written by an AI agent on behalf of @<username>.*

---
```

To get the current authenticated username run:

```bash
GITLAB_HOST=<hostname> glab api user --jq '.username'
```

**Example** — adding a triage note to issue #42:

```bash
GITLAB_HOST=gitlab.example.com glab issue note 42 \
  -R group/project \
  --message "🤖 *This comment was written by an AI agent on behalf of @alice.*

---

## Triage

Root cause identified: ..."
```

This applies to **every** comment or note, regardless of length or context. Never skip the header.

---

## Issues

```bash
glab issue create --title "Bug: ..." --description "..." --label "type::bug,priority::high" --assignee "@me"
glab issue list --assignee=@me                    # list my issues
glab issue list --label="bug" --search="login"    # filter and search
glab issue view 42 --comments                     # view with comments
glab issue note 42 --message "Root cause found."  # add a comment
glab issue update 42 --label "confirmed"          # update metadata
glab issue close 42                               # close (ask confirmation first)
glab issue reopen 42
```

### Label selection process

If the user specified exact labels, use them. Otherwise:

1. **Discover available labels**: `glab label list` (or `glab api projects/:id/labels` for more detail)
2. **Propose labels that fit** the issue context -- suggest scoped labels (e.g., `priority::high`, `type::bug`) when they exist in the project. Scoped labels use `::` and auto-remove conflicting labels in the same scope.
3. **Ask the user to confirm or adjust** before creating the issue.

Do NOT invent label names. Only propose labels that actually exist in the project.

**Create an MR directly from an issue**: `glab mr for 42` creates a branch and linked MR that auto-closes the issue on merge.

---

## Merge Requests

### Creating MRs

```bash
glab mr create --title "Fix login crash" --description "Closes #42" \
  --target-branch develop --reviewer "marco" --assignee "@me"
glab mr create --fill              # title/description from commits
glab mr create --draft --fill      # draft MR
```

Include `Closes #42` or `Fixes #42` in the description to auto-close issues on merge.

**MR creation checklist** (follow this carefully):

1. **Inspect branch state**: `git status`, `git log <base>...HEAD --oneline`, `git diff <base>...HEAD`
2. **Draft title/description from the actual diff** -- reference specific files, functions, behaviors. Do not just restate the user's request.
3. **Push**: `git push -u origin HEAD` if not yet pushed.
4. **Create**: `glab mr create` with all relevant flags.
5. **Return the MR URL** to the user.

### Reviewing and managing MRs

```bash
glab mr view 15 --comments          # view MR with comments
glab mr diff 15                     # see the diff
glab mr list --reviewer=@me         # MRs needing my review
glab mr checkout 15                 # checkout locally
glab mr note 15 --message "LGTM"   # leave a comment
glab mr approve 15                  # formal approval (separate from notes)
glab mr revoke 15                   # revoke approval
glab mr merge 15 --squash --remove-source-branch --when-pipeline-succeeds
glab mr rebase 15                   # rebase onto target
glab mr update 15 --add-label "reviewed"
glab mr close 15                    # close without merging
```

**Code review workflow**: view MR -> read diff -> check CI (`glab ci status`) -> read comments -> leave feedback -> approve or request changes.

Approval and notes are separate commands -- `glab mr approve` handles GitLab's formal approval system, `glab mr note` posts a comment.

---

## CI/CD

```bash
glab ci status                      # pipeline status for current branch
glab ci list                        # recent pipelines
glab ci trace                       # stream job logs in real-time
glab ci run                         # trigger new pipeline
glab ci retry <pipeline-id>         # retry failed pipeline
glab ci cancel <pipeline-id>        # cancel running pipeline
glab ci artifact <job-id>           # download artifacts
glab ci lint                        # validate .gitlab-ci.yml syntax
```

Run `glab ci lint` before committing CI config changes to catch syntax errors early.

---

## Safety Protocol

**Your default role is read-only.** Do NOT proactively suggest, offer, or execute state-changing operations. Only perform write or mutating operations when the user explicitly asks for them.

### Tier 1 -- FORBIDDEN (never execute these)

These commands are **never** executed, regardless of what the user asks. If the user needs one of these, explain the consequences and tell them how to run it manually.

| Action | Command |
|--------|---------|
| Delete repo | `glab repo delete` |
| Delete release | `glab release delete` |
| Destructive API calls | `glab api -X DELETE ...` on critical resources |
| Force push to default branch | `git push --force` to `main`/`master`/default |
| Hard reset | `git reset --hard` |

### Tier 2 -- EXPLICIT REQUEST ONLY (never suggest, never offer)

These commands are executed **only** when the user explicitly requests them with clear intent (e.g., "merge the MR", "close issue #42"). Never propose them, never include them in automated workflows, never ask "should I merge/close this?".

Before executing, **always** explain what will happen and ask for confirmation.

| Action | Command |
|--------|---------|
| Merge MR | `glab mr merge` |
| Close issue or MR | `glab issue close`, `glab mr close` |
| Delete issue or MR | `glab issue delete`, `glab mr delete` |
| Cancel pipeline | `glab ci cancel` |
| Force push (non-default branch) | `git push --force` |
| Skip hooks | `--no-verify` |

### Tier 3 -- SAFE WITH CONFIRMATION

These operations can be proposed when relevant, but require a brief confirmation before execution.

| Action | Command |
|--------|---------|
| Rebase MR | `glab mr rebase` |
| Update metadata (labels, assignees, etc.) | `glab mr update`, `glab issue update` |

### Git safety

- **Prefer `glab mr rebase`** over manual rebase + force push
- When in doubt about target branch, check the project default rather than assuming `main`

---

## `glab api` -- last resort for advanced operations

> **Do NOT use `glab api` when a CLI subcommand can do the job.** For issues, MRs, CI, labels -- always use the dedicated subcommands first. Use `glab api` only for operations not covered by any subcommand (e.g., project members, GraphQL queries, custom endpoints).

```bash
glab api projects/:id/members                                        # GET
glab api -X POST projects/:id/issues -f title="New" -f description="..." # POST
glab api -X PUT projects/:id/merge_requests/15 -f title="Updated"   # PUT
glab api projects/:id/issues --paginate                              # paginate
```

Placeholder variables (auto-resolved inside a git repo): `:id`, `:fullpath`, `:repo`.

For comprehensive API patterns (GraphQL, pagination, advanced queries), read `references/api-patterns.md`.
