#!/usr/bin/env bash
# goto-test.sh
# Jump from the current file/function to its test.
#   1) If .test-meta/map.json maps this file to a test file, open that.
#   2) Otherwise, find test_<enclosing_function_name> in the project.
set -euo pipefail

file="${ZED_FILE:?}"
row="${ZED_ROW:-1}"
root="${ZED_WORKTREE_ROOT:-$(dirname "$file")}"

# Path of $1 relative to the project root (portable; no GNU realpath needed)
relpath() {
  local abs root_abs
  abs="$(cd "$(dirname "$1")" && pwd -P)/$(basename "$1")"
  root_abs="$(cd "$root" && pwd -P)"
  echo "${abs#"$root_abs"/}"
}

# 1) Explicit mapping from set-testfile.sh
map="$root/.test-meta/map.json"
if [[ -f "$map" ]] && command -v jq >/dev/null; then
  rel="$(relpath "$file")"
  mapped=$(jq -r --arg c "$rel" '.[] | select(.code == $c) | .test' "$map" | head -1)
  if [[ -n "$mapped" ]]; then
    exec zed "$root/$mapped"
  fi
fi

# 2) Find the enclosing function name
name=""
# Prefer Zed's breadcrumb symbol (e.g. "fn parse_args" / "def parse_args(...)")
if [[ -n "${ZED_SYMBOL:-}" ]]; then
  name=$(sed -E 's/\(.*//' <<<"$ZED_SYMBOL" | awk '{print $NF}')
fi
# Fallback: nearest function definition above the cursor
if [[ -z "$name" ]]; then
  name=$(head -n "$row" "$file" \
    | grep -oE '(def|fn|func|function)[[:space:]]+[A-Za-z_][A-Za-z0-9_]*' \
    | tail -1 | awk '{print $2}' || true)
fi

[[ -z "$name" ]] && { echo "No enclosing function found"; exit 1; }
name="${name#test_}"

# 3) Search the project for the test definition
command -v rg >/dev/null || { echo "ripgrep (rg) is required"; exit 1; }
match=$(rg -n --no-heading -m1 \
  -e "(def|fn|func|function)\s+test_${name}\b" "$root" | head -1 || true)

[[ -z "$match" ]] && { echo "No test_${name} found in $root"; exit 1; }

# 4) Open it in Zed at path:line
zed "$(cut -d: -f1,2 <<<"$match")"
