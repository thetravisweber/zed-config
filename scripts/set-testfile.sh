#!/usr/bin/env bash
# set-testfile.sh
# Sets the test file by path for the currently edited file
# Store in {project_path}/.test-meta/map.json
# Store just a simple association {"code": {{path}}, "test": {{path}}}
set -euo pipefail

file="${ZED_FILE:?}"
root="${ZED_WORKTREE_ROOT:-$(dirname "$file")}"
map_dir="$root/.test-meta"
map="$map_dir/map.json"

command -v jq >/dev/null || { echo "jq is required"; exit 1; }

cd "$root"
code="$(realpath --relative-to="$root" "$file")"

# Test path: from arg, or prompt (tab-completes relative to project root)
test_path="${1:-}"
if [[ -z "$test_path" ]]; then
  read -e -r -p "Test file for $code: " test_path
fi
[[ -z "$test_path" ]] && { echo "No test file given"; exit 1; }
[[ -f "$test_path" ]] || { echo "Not a file: $test_path"; exit 1; }
test_rel="$(realpath --relative-to="$root" "$test_path")"

mkdir -p "$map_dir"
[[ -s "$map" ]] || echo '[]' > "$map"

# Upsert: drop any existing entry for this code file, then append the new one
tmp="$(mktemp)"
jq --arg c "$code" --arg t "$test_rel" \
  '[.[] | select(.code != $c)] + [{code: $c, test: $t}]' \
  "$map" > "$tmp" && mv "$tmp" "$map"

echo "Mapped $code -> $test_rel"
