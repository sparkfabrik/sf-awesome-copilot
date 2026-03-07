# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
This project has no semantic versioning — the latest commit is the current version.
Changes are grouped by date.

## [Unreleased]

## [2026-03-07]

### Added

- `the-architect` agent: conversational AI oracle for discovery, brainstorming, architecture, and general knowledge (Copilot and OpenCode profiles)

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
