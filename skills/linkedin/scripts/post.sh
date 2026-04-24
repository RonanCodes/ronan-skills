#!/usr/bin/env bash
# Publish a text post to the authenticated member's feed.
# Usage: post.sh "post text"
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

TEXT="${1:-}"
if [ -z "$TEXT" ]; then
    echo "usage: post.sh \"text to post\"" >&2
    exit 1
fi

require_token

BODY=$(LINKEDIN_TEXT="$TEXT" python3 - <<'PY'
import json, os
print(json.dumps({
    "author": f"urn:li:person:{os.environ['LINKEDIN_PERSON_SUB']}",
    "commentary": os.environ["LINKEDIN_TEXT"],
    "visibility": "PUBLIC",
    "distribution": {
        "feedDistribution": "MAIN_FEED",
        "targetEntities": [],
        "thirdPartyDistributionChannels": [],
    },
    "lifecycleState": "PUBLISHED",
    "isReshareDisabledByAuthor": False,
}))
PY
)

HEADERS_FILE=$(mktemp -t linkedin-post-headers.XXXXXX)
trap 'rm -f "$HEADERS_FILE"' EXIT

HTTP_CODE=$(curl -sS -o /tmp/linkedin-post-body.$$ -w "%{http_code}" \
    -D "$HEADERS_FILE" \
    -H "Authorization: Bearer $LINKEDIN_ACCESS_TOKEN" \
    -H "LinkedIn-Version: 202411" \
    -H "X-Restli-Protocol-Version: 2.0.0" \
    -H "Content-Type: application/json" \
    -X POST "https://api.linkedin.com/rest/posts" \
    --data "$BODY")

RESP_BODY=$(cat "/tmp/linkedin-post-body.$$" 2>/dev/null || echo "")
rm -f "/tmp/linkedin-post-body.$$"

if [ "$HTTP_CODE" != "201" ] && [ "$HTTP_CODE" != "200" ]; then
    echo "ERROR: LinkedIn returned HTTP $HTTP_CODE" >&2
    echo "Body: $RESP_BODY" >&2
    exit 1
fi

POST_URN=$(grep -i '^x-restli-id:' "$HEADERS_FILE" | head -1 | awk '{print $2}' | tr -d '\r')
if [ -z "$POST_URN" ]; then
    POST_URN=$(grep -i '^x-linkedin-id:' "$HEADERS_FILE" | head -1 | awk '{print $2}' | tr -d '\r')
fi

if [ -z "$POST_URN" ]; then
    echo "Posted (HTTP $HTTP_CODE) but could not find post URN in response headers." >&2
    echo "Check https://www.linkedin.com/in/me/recent-activity/all/" >&2
    exit 0
fi

echo "✓ Posted"
echo "  URN: $POST_URN"
echo "  URL: https://www.linkedin.com/feed/update/${POST_URN}/"
