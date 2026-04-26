#!/usr/bin/env bash
# POST /articles — create a new article from a markdown file with dev.to frontmatter.
# Default: published=false (draft). Use --publish to flip on.
# Use --open to open the resulting URL in the browser.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"
require_key

FILE=""
PUBLISH="false"
OPEN_AFTER="false"

while [ $# -gt 0 ]; do
    case "$1" in
        --publish) PUBLISH="true"; shift ;;
        --open)    OPEN_AFTER="true"; shift ;;
        -*)        echo "unknown flag: $1" >&2; exit 1 ;;
        *)         if [ -z "$FILE" ]; then FILE="$1"; fi; shift ;;
    esac
done

if [ -z "$FILE" ] || [ ! -f "$FILE" ]; then
    echo "usage: draft.sh <markdown-file.md> [--publish] [--open]" >&2
    exit 1
fi

# Build JSON body. Send body_markdown verbatim — Forem extracts frontmatter server-side.
# The --publish flag overrides any `published:` value in the file's frontmatter.
BODY=$(FILE="$FILE" PUBLISH="$PUBLISH" python3 <<'PY'
import json, os
with open(os.environ["FILE"]) as f:
    md = f.read()
art = {"body_markdown": md}
if os.environ.get("PUBLISH") == "true":
    art["published"] = True
print(json.dumps({"article": art}))
PY
)

RESP=$(curl -sS -H "api-key: $DEVTO_API_KEY" \
    -H "Content-Type: application/json" \
    -X POST "$API_BASE/articles" \
    --data "$BODY")

echo "$RESP" | print_article_summary "Created"

if [ "$OPEN_AFTER" = "true" ]; then
    URL=$(echo "$RESP" | python3 -c 'import sys, json; print(json.load(sys.stdin).get("url",""))')
    if [ -n "$URL" ]; then
        echo "  opening:   $URL"
        open "$URL"
    fi
fi
