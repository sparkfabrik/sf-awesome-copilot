#!/usr/bin/env bash
#
# Generic upstream skill sync script.
#
# Downloads skill directories from upstream GitHub repos (via tarball) and
# installs them into skills/system/<name>/. Reads the skill list and config
# from scripts/upstream-skills.json.
#
# For each skill the script:
#   1. Downloads the repo tarball (one per unique repo, cached in tmpdir)
#   2. Extracts the skill directory from the tarball
#   3. Patches SKILL.md frontmatter with any overrides from the manifest
#   4. Appends custom-sections.md (if present) to SKILL.md
#   5. Preserves local-only files (custom-sections.md, evals/)
#
# Usage:
#   ./scripts/sync-skill.sh <name>           # sync a single skill
#   ./scripts/sync-skill.sh <name> --check   # dry-run: exit 1 if stale
#   ./scripts/sync-skill.sh --all            # sync all skills
#   ./scripts/sync-skill.sh --all --check    # dry-run for all skills
#
# Requires: jq, curl, tar

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
MANIFEST="${REPO_ROOT}/config/upstream-skills.json"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

die() { echo "ERROR: $*" >&2; exit 1; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "$1 is required but not installed."
}

require_cmd jq
require_cmd curl

# ---------------------------------------------------------------------------
# Tarball cache — one download per unique repo+ref
# ---------------------------------------------------------------------------

declare -A TARBALL_CACHE  # key: "repo@ref" -> path to extracted dir

download_tarball() {
  local repo="$1" ref="$2"
  local cache_key="${repo}@${ref}"

  if [[ -n "${TARBALL_CACHE[$cache_key]:-}" ]]; then
    return
  fi

  local tarball="${TMPDIR_ROOT}/${repo//\//_}_${ref}.tar.gz"
  local extract_dir="${TMPDIR_ROOT}/${repo//\//_}_${ref}"
  local url="https://github.com/${repo}/archive/refs/heads/${ref}.tar.gz"

  echo "Downloading ${repo}@${ref}..."
  if ! curl -sSfL "$url" -o "$tarball"; then
    die "Failed to download tarball from ${url}"
  fi

  mkdir -p "$extract_dir"
  tar -xzf "$tarball" -C "$extract_dir" --strip-components=1

  TARBALL_CACHE[$cache_key]="$extract_dir"
}

get_tarball_dir() {
  local repo="$1" ref="$2"
  echo "${TARBALL_CACHE[${repo}@${ref}]}"
}

# ---------------------------------------------------------------------------
# Frontmatter patching
# ---------------------------------------------------------------------------

# Reads upstream SKILL.md, applies frontmatter_overrides, returns the patched
# frontmatter (including --- delimiters) followed by the body.
patch_skill_md() {
  local upstream_skill_md="$1"
  local overrides_json="$2"  # JSON object or "null"

  # Split upstream into frontmatter lines and body
  local in_frontmatter=false
  local frontmatter_done=false
  local delimiter_count=0
  local frontmatter_lines=()
  local body=""

  while IFS= read -r line || [[ -n "$line" ]]; do
    if ! $frontmatter_done; then
      if [[ "$line" =~ ^---[[:space:]]*$ ]]; then
        delimiter_count=$((delimiter_count + 1))
        if [[ $delimiter_count -eq 1 ]]; then
          in_frontmatter=true
          continue
        elif [[ $delimiter_count -eq 2 ]]; then
          frontmatter_done=true
          in_frontmatter=false
          continue
        fi
      fi
      if $in_frontmatter; then
        frontmatter_lines+=("$line")
      fi
    else
      body+="${line}"$'\n'
    fi
  done < "$upstream_skill_md"

  # If no overrides, emit the original frontmatter as-is
  if [[ "$overrides_json" == "null" ]] || [[ -z "$overrides_json" ]]; then
    echo "---"
    for fm_line in "${frontmatter_lines[@]}"; do
      echo "$fm_line"
    done
    echo "---"
    echo ""
    printf '%s' "$body"
    return
  fi

  # Build a map of override keys
  local override_keys
  override_keys=$(echo "$overrides_json" | jq -r 'keys[]')

  # Parse existing frontmatter into an ordered list of key-value pairs.
  # We handle simple "key: value" and multi-line block scalars (>-, |, etc.)
  local patched_fm=()
  local current_key=""
  local skip_continuation=false

  for fm_line in "${frontmatter_lines[@]}"; do
    # Check if this is a new key (not indented, contains colon)
    if [[ "$fm_line" =~ ^([a-zA-Z_-]+):[[:space:]]*(.*) ]]; then
      current_key="${BASH_REMATCH[1]}"
      local value="${BASH_REMATCH[2]}"

      # Check if this key has an override
      local override_value
      override_value=$(echo "$overrides_json" | jq -r --arg k "$current_key" '.[$k] // empty')

      if [[ -n "$override_value" ]]; then
        # Check if the value needs multi-line YAML (contains quotes or is long)
        if [[ ${#override_value} -gt 80 ]] || [[ "$override_value" == *'"'* ]]; then
          patched_fm+=("${current_key}: >-")
          # Word-wrap the value at ~78 chars with 2-space indent
          # Use process substitution to avoid subshell (pipe would lose array writes)
          while IFS= read -r wrap_line; do
            patched_fm+=("  ${wrap_line}")
          done < <(echo "$override_value" | fold -s -w 76)
        else
          patched_fm+=("${current_key}: ${override_value}")
        fi
        skip_continuation=true
      else
        patched_fm+=("$fm_line")
        skip_continuation=false
      fi
    elif [[ "$fm_line" =~ ^[[:space:]] ]]; then
      # Continuation line (indented) — belongs to current_key
      if ! $skip_continuation; then
        patched_fm+=("$fm_line")
      fi
    else
      patched_fm+=("$fm_line")
      skip_continuation=false
    fi
  done

  # Add any override keys that weren't in the original frontmatter
  for key in $override_keys; do
    local found=false
    for fm_line in "${frontmatter_lines[@]}"; do
      if [[ "$fm_line" =~ ^${key}: ]]; then
        found=true
        break
      fi
    done
    if ! $found; then
      local override_value
      override_value=$(echo "$overrides_json" | jq -r --arg k "$key" '.[$k]')
      if [[ ${#override_value} -gt 80 ]] || [[ "$override_value" == *'"'* ]]; then
        patched_fm+=("${key}: >-")
        while IFS= read -r wrap_line; do
          patched_fm+=("  ${wrap_line}")
        done < <(echo "$override_value" | fold -s -w 76)
      else
        patched_fm+=("${key}: ${override_value}")
      fi
    fi
  done

  # Emit patched SKILL.md
  echo "---"
  for fm_line in "${patched_fm[@]}"; do
    echo "$fm_line"
  done
  echo "---"
  echo ""
  printf '%s' "$body"
}

# ---------------------------------------------------------------------------
# Sync a single skill
# ---------------------------------------------------------------------------

sync_skill() {
  local skill_name="$1"
  local check_mode="${2:-false}"

  # Read skill config from manifest
  local skill_json
  skill_json=$(jq -r --arg name "$skill_name" '.skills[] | select(.name == $name)' "$MANIFEST")

  if [[ -z "$skill_json" ]]; then
    die "Skill '${skill_name}' not found in manifest."
  fi

  local repo ref path overrides_json
  repo=$(echo "$skill_json" | jq -r '.repo')
  ref=$(echo "$skill_json" | jq -r '.ref // "main"')
  path=$(echo "$skill_json" | jq -r '.path')
  overrides_json=$(echo "$skill_json" | jq '.frontmatter_overrides // null')

  local target_dir="${REPO_ROOT}/skills/system/${skill_name}"
  local custom_sections="${target_dir}/custom-sections.md"
  local build_dir="${TMPDIR_ROOT}/build_${skill_name}"

  # Download tarball if not cached
  download_tarball "$repo" "$ref"
  local tarball_dir
  tarball_dir=$(get_tarball_dir "$repo" "$ref")

  local upstream_dir="${tarball_dir}/${path}"
  if [[ ! -d "$upstream_dir" ]]; then
    die "Path '${path}' not found in ${repo}@${ref} tarball."
  fi

  echo "Syncing ${skill_name} from ${repo}@${ref}:${path}..."

  # Build into temp directory
  mkdir -p "$build_dir"

  # Copy all upstream files
  cp -a "$upstream_dir"/. "$build_dir"/

  # Patch SKILL.md frontmatter + append custom sections
  if [[ -f "$build_dir/SKILL.md" ]]; then
    local patched
    patched=$(patch_skill_md "$build_dir/SKILL.md" "$overrides_json")

    # Append custom sections if they exist locally
    if [[ -f "$custom_sections" ]] && [[ -s "$custom_sections" ]]; then
      patched+=$'\n'
      patched+=$(cat "$custom_sections")
      patched+=$'\n'
    fi

    echo "$patched" > "$build_dir/SKILL.md"
  fi

  # --check mode: compare build vs local
  if [[ "$check_mode" == "true" ]]; then
    local changed=false

    if [[ ! -d "$target_dir" ]]; then
      echo "  ${skill_name}: target directory does not exist."
      changed=true
    else
      # Compare all files from build against target
      while IFS= read -r -d '' file; do
        local rel="${file#$build_dir/}"
        local local_file="${target_dir}/${rel}"

        if [[ ! -f "$local_file" ]]; then
          echo "  ${skill_name}: ${rel} does not exist locally."
          changed=true
        elif ! diff -q "$file" "$local_file" > /dev/null 2>&1; then
          echo "  ${skill_name}: ${rel} differs."
          changed=true
        fi
      done < <(find "$build_dir" -type f -print0)
    fi

    if $changed; then
      echo "  ${skill_name}: OUT OF DATE"
      return 1
    else
      echo "  ${skill_name}: up to date"
      return 0
    fi
  fi

  # Sync mode: preserve local-only files, then copy build over
  mkdir -p "$target_dir"

  # Save local-only files to temp
  local preserve_dir="${TMPDIR_ROOT}/preserve_${skill_name}"
  mkdir -p "$preserve_dir"

  for preserve in custom-sections.md evals; do
    if [[ -e "${target_dir}/${preserve}" ]]; then
      cp -a "${target_dir}/${preserve}" "${preserve_dir}/${preserve}"
    fi
  done

  # Remove upstream-managed files (everything except preserved items)
  # We do this by removing all files that exist in build_dir from target_dir
  while IFS= read -r -d '' file; do
    local rel="${file#$build_dir/}"
    local local_file="${target_dir}/${rel}"
    if [[ -f "$local_file" ]]; then
      rm -f "$local_file"
    fi
  done < <(find "$build_dir" -type f -print0)

  # Copy built files
  cp -a "$build_dir"/. "$target_dir"/

  # Restore preserved files
  for preserve in custom-sections.md evals; do
    if [[ -e "${preserve_dir}/${preserve}" ]]; then
      cp -a "${preserve_dir}/${preserve}" "${target_dir}/${preserve}"
    fi
  done

  echo "  ${skill_name}: synced to ${target_dir}"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

TMPDIR_ROOT=$(mktemp -d)
trap 'rm -rf "$TMPDIR_ROOT"' EXIT

check_mode=false
sync_all=false
skill_name=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check) check_mode=true; shift ;;
    --all)   sync_all=true; shift ;;
    -*)      die "Unknown option: $1" ;;
    *)       skill_name="$1"; shift ;;
  esac
done

if $sync_all && [[ -n "$skill_name" ]]; then
  die "Cannot specify both --all and a skill name."
fi

if ! $sync_all && [[ -z "$skill_name" ]]; then
  die "Usage: $0 <name> [--check] | --all [--check]"
fi

any_stale=false

if $sync_all; then
  skill_names=$(jq -r '.skills[].name' "$MANIFEST")
  for name in $skill_names; do
    if ! sync_skill "$name" "$check_mode"; then
      any_stale=true
    fi
  done
else
  if ! sync_skill "$skill_name" "$check_mode"; then
    any_stale=true
  fi
fi

if $check_mode && $any_stale; then
  echo ""
  echo "One or more skills are out of date."
  exit 1
elif $check_mode; then
  echo ""
  echo "All skills up to date."
fi

echo ""
echo "Done."
