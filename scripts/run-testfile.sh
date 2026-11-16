#!/usr/bin/env bash
# run-testfile.sh
# Run all tests in the current test file (or the current code file's test file).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/test-lib.sh"

tf="$(find_test_file)"
[[ -z "$tf" ]] && die "No test file found (try ,mtf or ,stf first)"

echo "▶ all tests in $(relpath "$tf")"
run_tests "$tf"