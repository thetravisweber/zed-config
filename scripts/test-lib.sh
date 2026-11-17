#!/usr/bin/env bash
# test-lib.sh — shared helpers, sourced by run-test.sh and run-testfile.sh

file="${ZED_FILE:?}"
row="${ZED_ROW:-1}"
root="${ZED_WORKTREE_ROOT:-$(dirname "$file")}"
dir=$(dirname "$file")
base=$(basename "$file")
ext="${base##*.}"
stem="${base%.*}"

die() { echo "$*"; exit 1; }

relpath() {
  local abs root_abs
  abs="$(cd "$(dirname "$1")" && pwd -P)/$(basename "$1")"
  root_abs="$(cd "$root" && pwd -P)"
  echo "${abs#"$root_abs"/}"
}

is_test_file() {
  [[ "$base" == test_* || "$base" == *_test.go || "$base" == *.test.* || "$base" == *.spec.* ]] && return 0

  # Also a test file if map.json lists it as some file's test
  local map="$root/.test-meta/map.json"
  if [[ -f "$map" ]] && command -v jq >/dev/null; then
    jq -e --arg t "$(relpath "$file")" 'any(.[]; .test == $t)' "$map" >/dev/null && return 0
  fi
  return 1
}

# Function enclosing the cursor (breadcrumb symbol, else nearest def above)
enclosing_name() {
  local name=""
  if [[ -n "${ZED_SYMBOL:-}" ]]; then
    name=$(sed -E 's/\(.*//' <<<"$ZED_SYMBOL" | awk '{print $NF}')
  fi
  if [[ -z "$name" ]]; then
    name=$(head -n "$row" "$file" \
      | grep -oE '(def|fn|func|function)[[:space:]]+[A-Za-z_][A-Za-z0-9_]*' \
      | tail -1 | awk '{print $2}' || true)
  fi
  echo "$name"
}

# For JS/TS test files: nearest test("...") / it("...") above the cursor
enclosing_js_test() {
  head -n "$row" "$file" \
    | grep -oE '(test|it)\([[:space:]]*["'"'"'`][^"'"'"'`]+' \
    | tail -1 | sed -E 's/^(test|it)\([[:space:]]*.//' || true
}

# Test file for the current file: itself, map.json, sibling, or anywhere in project
find_test_file() {
  if is_test_file; then echo "$file"; return; fi

  local map="$root/.test-meta/map.json" mapped test_name found
  if [[ -f "$map" ]] && command -v jq >/dev/null; then
    mapped=$(jq -r --arg c "$(relpath "$file")" \
      '.[] | select(.code == $c) | .test' "$map" | head -1)
    [[ -n "$mapped" ]] && { echo "$root/$mapped"; return; }
  fi

  case "$ext" in
    go) test_name="${stem}_test.go" ;;
    *)  test_name="test_${stem}.${ext}" ;;
  esac
  [[ -f "$dir/$test_name" ]] && { echo "$dir/$test_name"; return; }

  found=$(find "$root" -name "$test_name" -not -path '*/node_modules/*' \
    -not -path '*/.git/*' 2>/dev/null | head -1)
  echo "$found"
}

python_bin() {
  if [[ -x "$root/.venv/bin/python" ]]; then echo "$root/.venv/bin/python"; else echo python3; fi
}

# run_tests <test_file> [test_name]   (no test_name = whole file)
run_tests() {
  local tf="$1" name="${2:-}" rel tdir names
  rel="$(relpath "$tf")"

  case "$ext" in
    py)
      cd "$root"
      if [[ -n "$name" ]]; then
        exec "$(python_bin)" -m pytest -v -s "$rel::$name"
      else
        exec "$(python_bin)" -m pytest -v -s "$rel"
      fi ;;

    rs)
      cd "$root"
      if [[ "$rel" == tests/* ]]; then           # integration test file
        if [[ -n "$name" ]]; then
          exec cargo test --test "$(basename "$tf" .rs)" "$name"
        else
          exec cargo test --test "$(basename "$tf" .rs)"
        fi
      else                                        # unit tests in src/
        exec cargo test "${name:-$(basename "$tf" .rs)::}"
      fi ;;

    go)
      tdir=$(dirname "$tf"); cd "$tdir"
      if [[ -n "$name" ]]; then
        exec go test -v -run "^${name}\$" .
      else
        names=$(grep -oE '^func Test[A-Za-z0-9_]*' "$tf" | awk '{print $2}' | paste -sd'|' -)
        [[ -z "$names" ]] && die "No tests in $rel"
        exec go test -v -run "^(${names})\$" .
      fi ;;

    js|mjs|cjs|ts|tsx)
      cd "$root"
      if [[ -x node_modules/.bin/vitest ]]; then
        if [[ -n "$name" ]]; then exec npx vitest run "$rel" -t "$name"; else exec npx vitest run "$rel"; fi
      elif [[ -x node_modules/.bin/jest ]]; then
        if [[ -n "$name" ]]; then exec npx jest "$rel" -t "$name"; else exec npx jest "$rel"; fi
      else
        die "No vitest or jest in node_modules"
      fi ;;

    lua)
      if [[ -n "$name" ]]; then
        exec lua -e "dofile('$tf'); $name(); print('ok: $name')"
      else
        exec lua -e "dofile('$tf')
          for k, v in pairs(_G) do
            if type(v) == 'function' and k:match('^test_') then print('== ' .. k); v() end
          end"
      fi ;;

    sh|bash)
      if [[ -n "$name" ]]; then
        exec bash -c 'source "$1" && "$2" && echo "ok: $2"' _ "$tf" "$name"
      else
        exec bash -c 'source "$1"
          for f in $(declare -F | awk "{print \$3}" | grep "^test_"); do
            echo "== $f"; "$f" || exit 1
          done' _ "$tf"
      fi ;;

    *) die "Don't know how to run .$ext tests" ;;
  esac
}
