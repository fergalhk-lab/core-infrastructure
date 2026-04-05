#!/usr/bin/env bash
# Generates a Markdown diff between two rendered manifest trees.
# Usage: generate-manifest-diff.sh <before-dir> <after-dir> <output-file>

set -euo pipefail

BEFORE="$1"
AFTER="$2"
OUTPUT="$3"

# Collect all relative app paths from both trees
mapfile -t rel_paths < <(
  find "$BEFORE" "$AFTER" -name "manifest.yaml" 2>/dev/null \
    | sed "s|${BEFORE}/||;s|${AFTER}/||" \
    | sort -u
)

body=""
has_changes=false

for rel_path in "${rel_paths[@]}"; do
  before_file="$BEFORE/$rel_path"
  after_file="$AFTER/$rel_path"

  before_arg="${before_file}"
  after_arg="${after_file}"
  [ -f "$before_file" ] || before_arg="/dev/null"
  [ -f "$after_file"  ] || after_arg="/dev/null"

  app_label=$(dirname "$rel_path")  # e.g. management/argocd

  diff_out=$(diff -u "$before_arg" "$after_arg" || true)
  [ -z "$diff_out" ] && continue

  has_changes=true
  body="${body}
<details>
<summary><code>${app_label}</code></summary>

\`\`\`diff
${diff_out}
\`\`\`

</details>"
done

{
  echo "## Manifest diff"
  echo ""
  if [ "$has_changes" = false ]; then
    echo "No changes to rendered manifests."
  else
    echo "$body"
  fi
} > "$OUTPUT"
