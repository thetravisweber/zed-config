#!/usr/bin/env bash
# define-test.sh
# Add a test_<function_name> stub for the function under the cursor
# to this file's test file, then jump to it.
#   Test file lookup: .test-meta/map.json -> test_<stem>.<ext> next to the file
#                     -> test_<stem>.<ext> anywhere in the project
set -euo pipefail

file="${ZED_FILE:?}"
row="${ZED_ROW:-1}"
root="${ZED_WORKTREE_ROOT:-$(dirname "$file")}"

relpath() {
  local abs root_abs
  abs="$(cd "$(dirname "$1")" && pwd -P)/$(basename "$1")"
  root_abs="$(cd "$root" && pwd -P)"
  echo "${abs#"$root_abs"/}"
}

dir=$(dirname "$file")
base=$(basename "$file")
ext="${base##*.}"
stem="${base%.*}"

# --- 1) Enclosing function name ----------------------------------------------
name=""
if [[ -n "${ZED_SYMBOL:-}" ]]; then
  name=$(sed -E 's/\(.*//' <<<"$ZED_SYMBOL" | awk '{print $NF}')
fi
if [[ -z "$name" ]]; then
  name=$(head -n "$row" "$file" \
    | grep -oE '(def|fn|func|function)[[:space:]]+[A-Za-z_][A-Za-z0-9_]*' \
    | tail -1 | awk '{print $2}' || true)
fi
[[ -z "$name" ]] && { echo "No enclosing function found"; exit 1; }
[[ "$name" == test_* ]] && { echo "$name is already a test"; exit 1; }

# --- 2) Find the test file ----------------------------------------------------
test_file=""
map="$root/.test-meta/map.json"
if [[ -f "$map" ]] && command -v jq >/dev/null; then
  mapped=$(jq -r --arg c "$(relpath "$file")" \
    '.[] | select(.code == $c) | .test' "$map" | head -1)
  [[ -n "$mapped" ]] && test_file="$root/$mapped"
fi

case "$ext" in
  go) test_name="${stem}_test.go" ;;
  *)  test_name="test_${stem}.${ext}" ;;
esac

if [[ -z "$test_file" && -f "$dir/$test_name" ]]; then
  test_file="$dir/$test_name"
fi
if [[ -z "$test_file" ]]; then
  test_file=$(find "$root" -name "$test_name" -not -path '*/node_modules/*' \
    -not -path '*/.git/*' 2>/dev/null | head -1)
fi
[[ -z "$test_file" ]] && { echo "No test file found (try ,mtf or ,stf first)"; exit 1; }

# --- 3) Don't duplicate -------------------------------------------------------
if existing=$(grep -nE "test_${name}([^A-Za-z0-9_]|$)" "$test_file" | head -1 | cut -d: -f1) \
   && [[ -n "$existing" ]]; then
  echo "test_${name} already exists"
  exec zed "$test_file:$existing"
fi

# --- 4) Language-appropriate stub ---------------------------------------------
case "$ext" in
  py)
    stub=$(printf '\n\ndef test_%s():\n    pass\n' "$name") ;;
  rs)
    stub=$(printf '\n#[test]\nfn test_%s() {\n    todo!()\n}\n' "$name") ;;
  go)
    stub=$(printf '\nfunc Test_%s(t *testing.T) {\n\tt.Skip("TODO")\n}\n' "$name") ;;
  js|mjs|cjs|ts|tsx)
    stub=$(printf '\ntest("test_%s", () => {\n  // TODO\n});\n' "$name") ;;
  lua)
    stub=$(printf '\nfunction test_%s()\n  -- TODO\nend\n' "$name") ;;
  sh|bash)
    stub=$(printf '\ntest_%s() {\n  : # TODO\n}\n' "$name") ;;
  *)
    echo "No stub format for .$ext"; exit 1 ;;
esac

# Ensure the file ends with a newline, then append
[[ -s "$test_file" && -n "$(tail -c1 "$test_file")" ]] && echo >> "$test_file"
printf '%s\n' "$stub" >> "$test_file"

# --- 5) Jump to the new test ----------------------------------------------------
line=$(grep -nE "test_${name}([^A-Za-z0-9_]|$)" "$test_file" | tail -1 | cut -d: -f1)
zed "$test_file:${line:-1}"
