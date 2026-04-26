#!/usr/bin/env bash
# GET /articles/:id — fetch one article as markdown (with metadata header).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"
require_key

ID="${1:-}"
if [ -z "$ID" ]; then
    echo "usage: get.sh <article-id>" >&2
    exit 1
fi

RESP=$(curl -sS -H "api-key: $DEVTO_API_KEY" "$API_BASE/articles/$ID")

RESP_RAW="$RESP" python3 <<'PY'
import os, json, sys
a = json.loads(os.environ['RESP_RAW'])
if "error" in a:
    print(f"ERROR: {a['error']}", file=sys.stderr)
    sys.exit(1)
print("# meta")
print(f"# id:        {a.get('id')}")
print(f"# title:     {a.get('title')}")
print(f"# published: {a.get('published')}")
print(f"# url:       {a.get('url')}")
print(f"# tags:      {', '.join(a.get('tag_list', []))}")
print()
print(a.get("body_markdown",""))
PY
