#!/usr/bin/env bash
# Create or update a single PR comment identified by a hidden marker.
# usage: pr-comment.sh <repository> <pr-number> <markdown-file> [marker]
# needs GH_TOKEN with pull-requests: write
set -euo pipefail

repo="$1" pr="$2" file="$3" marker="<!-- ${4:-fragment-testbed} -->"
[[ -s "$file" ]] || { echo "empty $file, nothing to post"; exit 0; }

body="$(mktemp)"
trap 'rm -f "$body"' EXIT
{ echo "$marker"; cat "$file"; } > "$body"

id="$(gh api --paginate "repos/$repo/issues/$pr/comments" \
  --jq ".[] | select(.body | startswith(\"$marker\")) | .id" | head -1)"
if [[ -n "$id" ]]; then
  gh api -X PATCH "repos/$repo/issues/comments/$id" -F "body=@$body" --jq .html_url
else
  gh api "repos/$repo/issues/$pr/comments" -F "body=@$body" --jq .html_url
fi
