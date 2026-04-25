#!/usr/bin/env bash
# typefully-draft/scripts/draft.sh
#
# Wraps the Typefully Drafts API. Reads TYPEFULLY_API_KEY from ~/.claude/.env.
# Posts a draft (default), or schedules to a specific time, or queues into the
# next free Typefully slot. Threads use \n---\n as the inter-post separator
# in the input; the script rewrites that to the four-newline separator that
# Typefully expects.
#
# Auth header format is `X-API-Key: Bearer <key>` (note: literal "Bearer"
# prefix is required; without it the API returns "Token is not valid").

set -euo pipefail

usage() {
  cat <<'USAGE' >&2
Usage:
  draft.sh <text> [--thread] [--schedule <iso8601>] [--queue-next] [--share] [--auto-retweet] [--targets <ids>]

Options:
  --thread           Treat <text> as a thread; posts separated by literal "\n---\n".
  --schedule <iso>   Schedule for a specific UTC time, e.g. 2026-04-26T09:00:00Z.
  --queue-next       Queue into Typefully's next free posting slot.
  --share            Return a shareable preview URL in the response.
  --auto-retweet     Auto-retweet 24h after publish (Typefully built-in, X only).
  --targets <ids>    Comma-separated connected-account IDs to scope the draft to.
                     Without this flag, draft posts to the social set's default platforms.
USAGE
  exit 2
}

TEXT=""
IS_THREAD=0
SCHEDULE=""
QUEUE_NEXT=0
SHARE=0
AUTO_RETWEET=0
TARGETS=""

while (("$#")); do
  case "$1" in
    --thread)        IS_THREAD=1; shift ;;
    --schedule)      SCHEDULE="${2:-}"; shift 2 ;;
    --queue-next)    QUEUE_NEXT=1; shift ;;
    --share)         SHARE=1; shift ;;
    --auto-retweet)  AUTO_RETWEET=1; shift ;;
    --targets)       TARGETS="${2:-}"; shift 2 ;;
    -h|--help)       usage ;;
    --*)             echo "Unknown flag: $1" >&2; usage ;;
    *)
      if [ -z "$TEXT" ]; then
        TEXT="$1"
      else
        echo "Multiple positional args; pass thread parts as one string with \\n---\\n separators" >&2
        usage
      fi
      shift
      ;;
  esac
done

[ -n "$TEXT" ] || { echo "Missing <text>" >&2; usage; }

# Mutually-exclusive flag check.
if [ -n "$SCHEDULE" ] && [ "$QUEUE_NEXT" -eq 1 ]; then
  echo "Use --schedule OR --queue-next, not both" >&2
  exit 2
fi
if [ "$SHARE" -eq 1 ] && { [ -n "$SCHEDULE" ] || [ "$QUEUE_NEXT" -eq 1 ]; }; then
  echo "--share is for preview-only drafts; combining with a schedule doesn't fit a real workflow" >&2
  exit 2
fi

# Load creds.
if [ -f "$HOME/.claude/.env" ]; then
  set -a; . "$HOME/.claude/.env"; set +a
fi
: "${TYPEFULLY_API_KEY:?Missing TYPEFULLY_API_KEY in ~/.claude/.env}"

# Translate the human-friendly thread separator to Typefully's four-newline format.
if [ "$IS_THREAD" -eq 1 ]; then
  # shellcheck disable=SC2001
  CONTENT=$(echo "$TEXT" | sed 's/\\n---\\n/\n\n\n\n/g')
else
  CONTENT="$TEXT"
fi

# Convert --targets "a,b,c" into a JSON array (numeric IDs become numbers,
# non-numeric stay as strings). Field name `account_id_to_share_to` is best-guess
# based on Typefully API convention; verify against current docs if posts don't
# route correctly and adjust here.
TARGETS_JSON=""
if [ -n "$TARGETS" ]; then
  TARGETS_JSON=$(echo "$TARGETS" | jq -R 'split(",") | map(gsub("^\\s+|\\s+$"; "")) | map(tonumber? // .)')
fi

# Build payload via jq so quoting and newlines survive intact.
PAYLOAD=$(jq -n \
  --arg content "$CONTENT" \
  --arg schedule "$SCHEDULE" \
  --argjson queue_next "$QUEUE_NEXT" \
  --argjson share "$SHARE" \
  --argjson auto_retweet "$AUTO_RETWEET" \
  --argjson targets "${TARGETS_JSON:-null}" \
  '{ content: $content }
   + (if $schedule != "" then { "schedule-date": $schedule } else {} end)
   + (if $queue_next == 1 then { "schedule-date": "next-free-slot" } else {} end)
   + (if $share == 1 then { share: true } else {} end)
   + (if $auto_retweet == 1 then { auto_retweet_enabled: true } else {} end)
   + (if $targets != null then { account_id_to_share_to: $targets } else {} end)')

# POST to Typefully. Header value requires literal "Bearer " prefix.
RESPONSE=$(curl -sS -w '\n%{http_code}' -X POST https://api.typefully.com/v1/drafts/ \
  -H "X-API-Key: Bearer $TYPEFULLY_API_KEY" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" -lt 200 ] || [ "$HTTP_CODE" -ge 300 ]; then
  echo "Typefully API error (HTTP $HTTP_CODE):" >&2
  echo "$BODY" | jq . >&2 2>/dev/null || echo "$BODY" >&2
  if [ "$HTTP_CODE" = "403" ] && echo "$BODY" | grep -q "Token is not valid"; then
    echo >&2
    echo "Tip: regenerate the key at Typefully → Settings → Integrations → API," >&2
    echo "     then update TYPEFULLY_API_KEY in ~/.claude/.env." >&2
  fi
  exit 1
fi

# Pretty summary.
ID=$(echo "$BODY" | jq -r '.id // empty')
SHARE_URL=$(echo "$BODY" | jq -r '.share_url // empty')
SCHEDULED=$(echo "$BODY" | jq -r '."scheduled-date" // .schedule_date // empty')

echo "Draft created."
[ -n "$ID" ]        && echo "  id:           $ID"
[ -n "$ID" ]        && echo "  review:       https://typefully.com/?d=$ID"
[ -n "$SHARE_URL" ] && echo "  share:        $SHARE_URL"
[ -n "$SCHEDULED" ] && echo "  scheduled:    $SCHEDULED"
echo
echo "Full response:"
echo "$BODY" | jq .
