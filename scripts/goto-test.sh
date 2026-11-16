#!/usr/bin/env bash
# Jump from the function under the cursor to test_<function_name>.
set -euo pipefail

file="${ZED_FILE:?}"
row="${ZED_ROW:-1}"
root="${ZED_WORKTREE_ROOT:-$(dirname "$file")}"

# 1) Prefer Zed's breadcrumb symbol (e.g. "fn parse_args" / "def parse_args(...)")
name=""
if [[ -n "${ZED_SYMBOL:-}" ]]; then
  name=$(sed -E 's/\(.*//' <<<"$ZED_SYMBOL" | awk '{print $NF}')
fi

# 2) Fallback: nearest function definition above the cursor
if [[ -z "$name" ]]; then
  name=$(head -n "$row" "$file" \
    | grep -oE '(def|fn|func|function)\s+[A-Za-z_][A-Za-z0-9_]*' \
    | tail -1 | awk '{print $2}')
fi

[[ -z "$name" ]] && { echo "No enclosing function found"; exit 1; }
name="${name#test_}"   # already in a test? search the same name anyway

# 3) Find the test definition
match=$(rg -n --no-heading -m1 \
  -e "(def|fn|func|function)\s+test_${name}\b" "$root" | head -1 || true)

[[ -z "$match" ]] && { echo "No test_${name} found in $root"; exit 1; }

# 4) Open it in Zed at path:line
zed "$(cut -d: -f1,2 <<<"$match")"