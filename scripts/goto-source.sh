#!/usr/bin/env bash
# goto-source.sh
# From a test, jump to the code it tests (Python only for now).
#   Source file: map.json (reverse lookup) -> test_foo.py => foo.py nearby -> anywhere in project
#   Function:    test_<name> => def/class <name>, trying shorter prefixes
#                (test_parse_args_empty -> parse_args_empty -> parse_args -> parse)
#   Fallback:    just open the source file
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/test-lib.sh"

[[ "$ext" == py ]] || die "goto-source only supports Python for now"
is_test_file    || die "Not in a test file"

# --- 1) Name under test --------------------------------------------------------
test_fn="$(enclosing_name)"
name=""
[[ "$test_fn" == test_* ]] && name="${test_fn#test_}"

# --- 2) Source file ------------------------------------------------------------
src=""
map="$root/.test-meta/map.json"
if [[ -f "$map" ]] && command -v jq >/dev/null; then
  mapped=$(jq -r --arg t "$(relpath "$file")" \
    '.[] | select(.test == $t) | .code' "$map" | head -1)
  [[ -n "$mapped" ]] && src="$root/$mapped"
fi

src_base="${stem#test_}.py"
[[ "$stem" == *_test ]] && src_base="${stem%_test}.py"

if [[ -z "$src" ]]; then
  for cand in "$dir/$src_base" "$(dirname "$dir")/$src_base"; do
    [[ -f "$cand" ]] && { src="$cand"; break; }
  done
fi
if [[ -z "$src" ]]; then
  src=$(find "$root" -name "$src_base" -not -name 'test_*' \
    -not -path '*/.venv/*' -not -path '*/.git/*' -not -path '*/node_modules/*' \
    2>/dev/null | head -1)
fi

# --- 3) Best matching def/class in the source file ------------------------------
[[ -n "$src" ]] || die "Couldn't find source for $base"

if [[ -n "$name" ]]; then
  n="$name"
  while :; do
    line=$(grep -nE "^[[:space:]]*(async[[:space:]]+)?(def|class)[[:space:]]+${n}[[:space:]]*[(:]" "$src" \
      | head -1 | cut -d: -f1 || true)
    if [[ -n "$line" ]]; then
      echo "→ $n  ($(relpath "$src"):$line)"
      exec zed "$src:$line"
    fi
    [[ "$n" == *_* ]] || break
    n="${n%_*}"          # test_parse_args_empty -> parse_args -> parse
  done
fi

# --- 4) No match: top of the file -------------------------------------------------
echo "→ $(relpath "$src") (no matching function)"
exec zed "$src:1"
