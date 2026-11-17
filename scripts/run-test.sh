#!/usr/bin/env bash
# run-test.sh
# In a test file: run the test under the cursor.
# In a code file: run test_<function under cursor> from its test file.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/test-lib.sh"

if is_test_file; then
  tf="$file"
  case "$ext" in
    js|mjs|cjs|ts|tsx) test="$(enclosing_js_test)" ;;
    *)                 test="$(enclosing_name)" ;;
  esac
  [[ -z "$test" ]] && die "No test under cursor"
else
  name="$(enclosing_name)"
  [[ -z "$name" ]] && die "No enclosing function found"
  tf="$(find_test_file)"
  [[ -z "$tf" ]] && die "No test file found (try ,mtf or ,stf first)"
  case "$ext" in
    go) test="Test_${name}" ;;
    *)  test="test_${name}" ;;
  esac
fi

echo "▶ $test  ($(relpath "$tf"))"
run_tests "$tf" "$test"