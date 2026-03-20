#!/usr/bin/env bash
#
# Syncs the playwright-cli skill from microsoft/playwright-cli.
#
# Downloads SKILL.md and reference files from the upstream repo,
# then builds the final SKILL.md by combining:
#   1. Our custom frontmatter (defined in this script)
#   2. The upstream SKILL.md body (everything after the frontmatter)
#   3. The contents of custom-sections.md (our hand-edited additions)
#
# Reference files are copied as-is to references/.
#
# Usage:
#   ./scripts/sync-playwright-cli.sh          # sync and rebuild
#   ./scripts/sync-playwright-cli.sh --check  # dry-run: exit 1 if local is stale
#

set -euo pipefail

UPSTREAM_REPO="microsoft/playwright-cli"
UPSTREAM_REF="main"
UPSTREAM_BASE="https://raw.githubusercontent.com/${UPSTREAM_REPO}/${UPSTREAM_REF}/skills/playwright-cli"

REPO_ROOT="$(git rev-parse --show-toplevel)"
SKILL_DIR="${REPO_ROOT}/skills/system/playwright-cli"
CUSTOM_SECTIONS="${SKILL_DIR}/custom-sections.md"

# Our custom frontmatter -- description optimized for auto-triggering.
FRONTMATTER='---
name: playwright-cli
description: >-
  Browser automation with the playwright-cli CLI tool. Use when the user needs
  to automate browser interactions, navigate websites, test web applications,
  take screenshots, fill forms, extract data from web pages, or interact with
  headless browsers. Also use when the user mentions "playwright-cli",
  "playwright", "browser automation", "headless browser", "web scraping",
  "screenshot", "snapshot", "browser testing", or wants to open, click, fill,
  or type in a web page.
allowed-tools: Bash(playwright-cli:*)
---'

# Hardcoded file list -- update manually when upstream adds/removes files.
REFERENCE_FILES=(
  "references/request-mocking.md"
  "references/running-code.md"
  "references/session-management.md"
  "references/storage-state.md"
  "references/test-generation.md"
  "references/tracing.md"
  "references/video-recording.md"
)

check_mode=false
if [[ "${1:-}" == "--check" ]]; then
  check_mode=true
fi

# Create temp dir for downloads
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/references"

echo "Fetching playwright-cli skill from ${UPSTREAM_REPO}@${UPSTREAM_REF}..."

# Download SKILL.md
echo "  SKILL.md"
if ! curl -sSfL "${UPSTREAM_BASE}/SKILL.md" -o "${tmpdir}/SKILL.md"; then
  echo "ERROR: Failed to download SKILL.md" >&2
  exit 1
fi

# Download reference files
for file in "${REFERENCE_FILES[@]}"; do
  echo "  ${file}"
  if ! curl -sSfL "${UPSTREAM_BASE}/${file}" -o "${tmpdir}/${file}"; then
    echo "ERROR: Failed to download ${file}" >&2
    exit 1
  fi
done

echo ""

# Extract upstream body (strip YAML frontmatter: everything between first two --- lines)
upstream_body=$(awk 'BEGIN{n=0} /^---[[:space:]]*$/{n++; if(n==2){found=1; next}} found{print}' "$tmpdir/SKILL.md")

# Build the final SKILL.md in temp
{
  echo "$FRONTMATTER"
  echo ""
  echo "$upstream_body"
  # Append custom sections if the file exists and is non-empty
  if [[ -f "$CUSTOM_SECTIONS" ]] && [[ -s "$CUSTOM_SECTIONS" ]]; then
    echo ""
    cat "$CUSTOM_SECTIONS"
  fi
} > "$tmpdir/SKILL.built.md"

if $check_mode; then
  changed=false

  # Compare built SKILL.md against current
  if [[ ! -f "${SKILL_DIR}/SKILL.md" ]]; then
    echo "SKILL.md does not exist locally."
    changed=true
  elif ! diff -q "${SKILL_DIR}/SKILL.md" "$tmpdir/SKILL.built.md" > /dev/null 2>&1; then
    echo "SKILL.md differs from upstream."
    diff -u "${SKILL_DIR}/SKILL.md" "$tmpdir/SKILL.built.md" || true
    echo ""
    changed=true
  fi

  # Compare reference files
  for file in "${REFERENCE_FILES[@]}"; do
    local_file="${SKILL_DIR}/${file}"
    if [[ ! -f "$local_file" ]]; then
      echo "${file} does not exist locally."
      changed=true
    elif ! diff -q "$local_file" "${tmpdir}/${file}" > /dev/null 2>&1; then
      echo "${file} differs from upstream."
      diff -u "$local_file" "${tmpdir}/${file}" || true
      echo ""
      changed=true
    fi
  done

  if $changed; then
    echo "Out of date."
    exit 1
  else
    echo "Up to date."
    exit 0
  fi
fi

# Sync: write files to skill directory
mkdir -p "${SKILL_DIR}/references"

cp "$tmpdir/SKILL.built.md" "${SKILL_DIR}/SKILL.md"

for file in "${REFERENCE_FILES[@]}"; do
  cp "${tmpdir}/${file}" "${SKILL_DIR}/${file}"
done

# Create custom-sections.md if it doesn't exist
if [[ ! -f "$CUSTOM_SECTIONS" ]]; then
  touch "$CUSTOM_SECTIONS"
  echo "Created empty ${CUSTOM_SECTIONS}"
fi

echo "Done. Synced skill to ${SKILL_DIR}"
