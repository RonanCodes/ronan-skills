#!/usr/bin/env bash
# Fetch basic profile identity via /v2/userinfo (OIDC).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

require_token

RESP=$(curl -sS -w "\n%{http_code}" \
    -H "Authorization: Bearer $LINKEDIN_ACCESS_TOKEN" \
    "https://api.linkedin.com/v2/userinfo")

HTTP_CODE=$(printf '%s' "$RESP" | tail -n1)
BODY=$(printf '%s' "$RESP" | sed '$d')

if [ "$HTTP_CODE" != "200" ]; then
    echo "ERROR: HTTP $HTTP_CODE" >&2
    echo "$BODY" >&2
    exit 1
fi

echo "$BODY" | python3 -m json.tool
