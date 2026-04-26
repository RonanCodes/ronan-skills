#!/usr/bin/env bash
# Open an article's URL in the default browser.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"
require_key

ID="${1:-}"
if [ -z "$ID" ]; then
    echo "usage: open.sh <article-id>" >&2
    exit 1
fi

URL=$(curl -sS -H "api-key: $DEVTO_API_KEY" "$API_BASE/articles/$ID" \
    | python3 -c 'import sys, json; print(json.load(sys.stdin).get("url",""))')

if [ -z "$URL" ]; then
    echo "ERROR: could not resolve URL for article $ID" >&2
    exit 1
fi

echo "$URL"
open "$URL"
