# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
This project has no semantic versioning — the latest commit is the current version.
Changes are grouped by date.

## [Unreleased]

## [2026-03-21]

### Fixed

- `gh`, `glab` skills: AI attribution header now uses blockquote format (`) instead of bare text with `---` separator -- fixes double-separator rendering issues and provides consistent visual distinction on both GitHub and GitLab

## [2026-03-20]

### Added

- `skill-creator` skill: create, iterate, and benchmark agent skills with eval-driven workflows. Synced from [anthropics/skills](https://github.com/anthropics/skills)
- `doc-coauthoring` skill: structured workflow for co-authoring documentation, proposals, and technical specs. Synced from [anthropics/skills](https://github.com/anthropics/skills)
- `gh` skill: GitHub CLI skill for issues, pull requests, Actions, releases, search, PR review comment replies, safety protocol, and API patterns reference with 12 eval scenarios
- `README.md`: skills table and `AGENTS.md` rule to keep it updated when adding/removing skills
- `playwright-cli` skill: browser automation skill synced from [microsoft/playwright-cli](https://github.com/microsoft/playwright-cli), with custom output file conventions (screenshots, PDFs, videos, traces directed to `.playwright-cli/` instead of project root)
- Generic upstream skill sync: `scripts/sync-skill.sh` replaces per-skill sync scripts; `config/upstream-skills.json` manifest with JSON schema declares all upstream skills; `.github/workflows/sync-skills.yml` runs weekly auto-sync

### Changed

- Moved sync manifest and schema from `scripts/` to `config/`

### Removed

- `scripts/sync-playwright-cli.sh` and `.github/workflows/sync-playwright-cli.yml` replaced by generic sync mechanism

### Fixed

- `glab` skill: AI attribution examples now use explicit two-step username capture pattern instead of hardcoded placeholder

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
