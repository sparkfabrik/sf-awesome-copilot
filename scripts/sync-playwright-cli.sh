#!/usr/bin/env bash
#
# Syncs the playwright-cli skill from microsoft/playwright-cli.
#
# Downloads SKILL.md and all reference files from the upstream repo
# and writes them to skills/system/playwright-cli/upstream/.
# Files are stored as-is with no modifications.
#
# Usage:
#   ./scripts/sync-playwright-cli.sh          # sync upstream files
#   ./scripts/sync-playwright-cli.sh --check  # dry-run: exit 1 if local is stale
#

set -euo pipefail

UPSTREAM_REPO="microsoft/playwright-cli"
UPSTREAM_REF="main"
UPSTREAM_BASE="https://raw.githubusercontent.com/${UPSTREAM_REPO}/${UPSTREAM_REF}/skills/playwright-cli"

REPO_ROOT="$(git rev-parse --show-toplevel)"
TARGET_DIR="${REPO_ROOT}/skills/system/playwright-cli/upstream"

# Hardcoded file list -- update manually when upstream adds/removes files.
FILES=(
  "SKILL.md"
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

# Download all files
for file in "${FILES[@]}"; do
  echo "  ${file}"
  if ! curl -sSfL "${UPSTREAM_BASE}/${file}" -o "${tmpdir}/${file}"; then
    echo "ERROR: Failed to download ${file}" >&2
    exit 1
  fi
done

echo ""

if $check_mode; then
  if [ ! -d "$TARGET_DIR" ]; then
    echo "Local upstream/ directory does not exist. Out of date."
    exit 1
  fi

  if diff -rq "$TARGET_DIR" "$tmpdir" > /dev/null 2>&1; then
    echo "Up to date."
    exit 0
  else
    echo "Out of date. Differences:"
    echo ""
    diff -ru "$TARGET_DIR" "$tmpdir" || true
    exit 1
  fi
fi

# Sync files
mkdir -p "${TARGET_DIR}/references"

for file in "${FILES[@]}"; do
  cp "${tmpdir}/${file}" "${TARGET_DIR}/${file}"
done

echo "Done. Synced ${#FILES[@]} files to ${TARGET_DIR}"
