# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
This project has no semantic versioning — the latest commit is the current version.
Changes are grouped by date.

## [Unreleased]

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
