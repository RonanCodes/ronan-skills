#!/usr/bin/env bash
# PUT /articles/:id — replace body (and frontmatter-derived fields) from a markdown file.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"
require_key

ID="${1:-}"
FILE="${2:-}"
if [ -z "$ID" ] || [ -z "$FILE" ] || [ ! -f "$FILE" ]; then
    echo "usage: update.sh <article-id> <markdown-file.md>" >&2
    exit 1
fi

BODY=$(FILE="$FILE" python3 <<'PY'
import json, os
with open(os.environ["FILE"]) as f:
    md = f.read()
print(json.dumps({"article": {"body_markdown": md}}))
PY
)

RESP=$(curl -sS -H "api-key: $DEVTO_API_KEY" \
    -H "Content-Type: application/json" \
    -X PUT "$API_BASE/articles/$ID" \
    --data "$BODY")

echo "$RESP" | print_article_summary "Updated"
