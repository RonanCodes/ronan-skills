#!/usr/bin/env bash
# GET /articles/me[/published|/unpublished|/all]
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"
require_key

FILTER="${1:-all}"

case "$FILTER" in
    drafts|unpublished) PATH_SUFFIX="/articles/me/unpublished" ;;
    published)          PATH_SUFFIX="/articles/me/published" ;;
    all|*)              PATH_SUFFIX="/articles/me/all" ;;
esac

RESP=$(curl -sS -H "api-key: $DEVTO_API_KEY" "$API_BASE$PATH_SUFFIX?per_page=100")

RESP_RAW="$RESP" python3 <<'PY'
import os, json
arts = json.loads(os.environ['RESP_RAW'])
if not arts:
    print("(no articles)")
    raise SystemExit(0)
for a in arts:
    status = "PUB" if a.get("published") else "DRAFT"
    title = a.get("title","(untitled)")
    print(f"  {a.get('id'):>9}  [{status:5}]  {title}")
    url = a.get("url") or ""
    if url:
        print(f"             {url}")
print()
print(f"{len(arts)} article(s)")
PY
