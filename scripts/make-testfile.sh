#!/usr/bin/env bash
# Pull in the appropriate test file template
set -euo pipefail

file="${ZED_FILE:?}"
row="${ZED_ROW:-1}"
root="${ZED_WORKTREE_ROOT:-$(dirname "$file")}"

dir=$(dirname "$file")
base=$(basename "$file")
ext="${base##*.}"
stem="${base%.*}"

# get language of file (extension -> name used in ~/Coding/<language>_projects)
case "$ext" in
  py)          lang="python" ;;
  rs)          lang="rust" ;;
  go)          lang="go" ;;
  js|mjs|cjs)  lang="javascript" ;;
  ts|tsx)      lang="typescript" ;;
  lua)         lang="lua" ;;
  sh|bash)     lang="bash" ;;
  c|h)         lang="c" ;;
  cpp|hpp|cc)  lang="cpp" ;;
  *) echo "Unknown extension: .$ext"; exit 1 ;;
esac

template="$HOME/Coding/${lang}_projects/test_template.${ext}"
if [[ ! -f "$template" ]]; then
  echo "No template at $template"
  echo "Available in ~/Coding:"; ls ~/Coding/
  exit 1
fi

# Name the new test file (Go wants foo_test.go; everything else test_foo.ext)
case "$lang" in
  go) dest="$dir/${stem}_test.${ext}" ;;
  *)  dest="$dir/test_${stem}.${ext}" ;;
esac

# Copy over without clobbering an existing test file
if [[ -e "$dest" ]]; then
  echo "Already exists: $dest (opening it)"
else
  cp "$template" "$dest"
  echo "Created $dest"
fi

zed "$dest"
