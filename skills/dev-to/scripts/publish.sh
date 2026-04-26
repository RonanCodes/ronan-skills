#!/usr/bin/env bash
# PUT /articles/:id — flip published flag to true on an existing article.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"
require_key

ID="${1:-}"
if [ -z "$ID" ]; then
    echo "usage: publish.sh <article-id>" >&2
    exit 1
fi

RESP=$(curl -sS -H "api-key: $DEVTO_API_KEY" \
    -H "Content-Type: application/json" \
    -X PUT "$API_BASE/articles/$ID" \
    --data '{"article":{"published":true}}')

echo "$RESP" | print_article_summary "Published"
