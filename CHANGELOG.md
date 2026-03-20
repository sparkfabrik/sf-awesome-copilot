# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
This project has no semantic versioning — the latest commit is the current version.
Changes are grouped by date.

## [Unreleased]

## [2026-03-20]

### Added

- `gh` skill: initial implementation of the GitHub CLI skill for issues, pull requests, Actions workflows, releases, search, and repository operations
- `gh` skill: PR comments and reviews section covering top-level comments, formal reviews, inline code comments, and threaded reply workflows via `gh api`
- `gh` skill: three-tier safety protocol (Forbidden, Explicit Request Only, Safe With Confirmation) covering `gh`-specific risks including `--admin` merge bypass, secrets/variables management, and workflow control
- `gh` skill: AI attribution header policy for all agent-created content
- `gh` skill: API patterns reference with `--jq` filtering, GraphQL, pagination, and review comment thread management
- `gh` skill: 12 eval scenarios covering issue/PR creation, CI monitoring, review comment replies, releases, search, and URL handling
- `SYSTEM.md`: added `gh` to available skills list

### Fixed

- `glab` skill: AI attribution examples now use explicit two-step username capture pattern instead of hardcoded `@alice`
- `gh` skill: AI attribution examples use `$GH_USERNAME` variable pattern to prevent hardcoded or missing usernames

## [2026-03-18]

### Added

- `glab` skill: file upload workflow documentation (curl-based workaround for glab api multipart limitation, OAuth vs PAT auth header guidance)
- `glab` skill: two new eval cases for file upload scenarios (image to MR, PDF to issue)
- `AGENTS.md`: git workflow rules requiring feature branches and pull requests

### Changed

- `glab` skill: clarified `-F key=@file` in api-patterns.md to warn it reads as string, not multipart

## [2026-03-07]

### Added

- `the-architect` agent: conversational AI oracle for discovery, brainstorming, architecture, and general knowledge (Copilot and OpenCode profiles)
- `SYSTEM.md`: catalog of system agents and skills with directory conventions, install paths, and available resources

## [2026-03-06]

### Changed

- `glab` skill: prioritize GitLab URL detection in skill description to ensure automatic triggering when users paste GitLab links

### Added

- `glab` skill: explicit instruction to never use WebFetch/curl on GitLab URLs (added to "Before you start" section)
- `glab` skill: eval for GitLab URL-based MR explanation scenario
- `glab` skill: automatic issue template selection when creating issues (fetches templates from the project and asks the user to choose)
- `glab` skill: eval for issue template selection workflow

## [2026-03-05]

### Added

- `glab` skill: instruct agent to always declare comment/note authorship on behalf of the user

### Fixed

- `glab` skill: document `id` vs `iid` milestone pitfall to prevent 404 API errors

### Changed

- `glab` skill: moved from `skills/gitlab/` to `skills/system/` category
- `glab` skill: streamlined milestone `id`/`iid` section for clarity

## [2026-03-04]

### Added

- `glab` skill: initial implementation of the `glab` CLI skill for GitLab operations

### Changed

- `glab` skill: moved from `skills/` root to `skills/gitlab/` category

## [2026-01-08]

### Added

- Initial project commit with repository structure
- LICENSE file
- GitHub Actions workflow for Claude
- README improvements
