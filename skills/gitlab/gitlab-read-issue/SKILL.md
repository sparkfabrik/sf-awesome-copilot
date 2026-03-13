---
name: gitlab-read-issue
description: Read a GitLab issue by number or search by topic. Use when the user wants to view issue details or find an issue related to a specific topic.
---

Retrieve and display a GitLab issue from the project repository, either by issue number or by searching for a topic.

**Input**: The user's request should include either an issue number (e.g., `#175`, `175`) OR a text description of the topic they're looking for (e.g., "authentication bug", "homepage redesign").

**Steps**

0. **Resolve the GitLab project path from git config**

   Run the following command from the project root to extract the project path from the git remote URL:
   ```bash
   git remote get-url origin | sed -E 's|git@[^:]+:(.+)\.git$|\1|; s|https?://[^/]+/(.+)\.git$|\1|'
   ```
   Store the result as `GITLAB_PROJECT` and use it in all subsequent `glab` calls with the `-R` flag.
   If the command fails or returns an empty string, inform the user that the GitLab project path could not be determined and ask them to verify the git remote is configured correctly (`git remote -v`). Then STOP.

1. **Determine whether the user provided an issue number or a search query**

   - If the input is a number (with or without `#`), go to **Step 3** (direct fetch).
   - If the input is a text description, go to **Step 2** (search).
   - If no input was provided, use the **AskUserQuestion tool** (open-ended, no preset options) to ask:
     > "Which issue do you want to read? You can provide an issue number (e.g. 175) or describe the topic you're looking for."

2. **Search for issues by text**

   Run the search command using `glab`:
   ```bash
   glab issue list --search "<user-text>" --in "title,description" --per-page 10 -R "$GITLAB_PROJECT" -O json
   ```

   - **If no `glab` command is found or returns an error**: Inform the user about the issue and suggest checking their `glab` CLI installation and authentication status with `glab auth status`. Then STOP.
     This is the URL of [GitLab Cli documentation](https://docs.gitlab.com/cli/).
   - **If no results are found**: Inform the user that no matching issues were found and suggest refining the search terms. Then STOP.
   - **If exactly one result is found**: Proceed to **Step 3** using that issue's number.
   - **If multiple results are found**: Present the list to the user using the **AskUserQuestion tool** with the matching issues as options. Each option should show: `#<iid> - <title> (<state>)`. Let the user select one, then proceed to **Step 3** with the selected issue number.

3. **Fetch the full issue details**

   ```bash
   glab issue view <issue-number> --comments --per-page 50 -R "$GITLAB_PROJECT" -F json
   ```

   Parse the JSON output to extract the issue details.

4. **Display the issue information**

   Present the issue in the following format:

   ```
   ## Issue #<iid>: <title>

   | Field       | Value                          |
   |-------------|--------------------------------|
   | State       | <state>                        |
   | Author      | <author>                       |
   | Assignees   | <assignees or "None">          |
   | Labels      | <labels or "None">             |
   | Milestone   | <milestone or "None">          |
   | Due date    | <due_date or "None">           |
   | Created     | <created_at>                   |
   | Updated     | <updated_at>                   |
   | Web URL     | <web_url>                      |

   ### Description

   <description body>

   ### Comments (<count>)

   **<author>** (<created_at>):
   > <comment body>

   ---
   (repeat for each comment)
   ```

5. **STOP and wait for user direction**

**Output**

After displaying the issue, offer:
> "What would you like to do with this issue? I can help you start working on it, explore related code, or search for another issue."

**Guardrails**
- Do NOT modify any issues - this skill is read-only
- Do NOT guess issue numbers - always ask the user if the input is ambiguous
- When searching, use the `--in "title,description"` flag to search both fields
- If `glab` returns an authentication or permission error, inform the user and suggest checking their `glab` CLI configuration with `glab auth status`
- Always use `-R "$GITLAB_PROJECT"` (resolved from git remote in Step 0) to target the correct repository
- Parse dates into a human-readable format when displaying (e.g., "Jan 15, 2026" instead of raw ISO)
- If the issue description is very long (>200 lines), summarize it and mention the full description is available at the web URL
- If there are more than 10 comments, show the 10 most recent and mention how many older comments exist
