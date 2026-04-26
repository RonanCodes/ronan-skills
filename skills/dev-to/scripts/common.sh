#!/usr/bin/env bash
# Shared env loading for the ro:dev-to skill.
# Sourced, not executed.

ENV_FILE="${DEVTO_ENV_FILE:-$HOME/.claude/.env}"

if [ ! -f "$ENV_FILE" ]; then
    echo "ERROR: $ENV_FILE not found. See skills/dev-to/SKILL.md 'First-time setup'." >&2
    exit 1
fi

set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

require_key() {
    if [ -z "${DEVTO_API_KEY:-}" ]; then
        echo "ERROR: DEVTO_API_KEY not set in $ENV_FILE." >&2
        echo "Get one at: https://dev.to/settings/extensions" >&2
        exit 1
    fi
}

API_BASE="https://dev.to/api"

# Mask a key for safe printing — show last 4 chars only.
mask_key() {
    local t="${1:-}"
    local n=${#t}
    if [ "$n" -lt 5 ]; then
        echo "..."
    else
        echo "...${t: -4}"
    fi
}

# Read curl response from stdin; print summary or exit 1 on Forem error.
# Usage: echo "$RESP" | print_article_summary "Created"
print_article_summary() {
    local raw
    raw=$(cat)
    LABEL="${1:-OK}" RESP_RAW="$raw" python3 <<'PY'
import os, json, sys
raw = os.environ.get("RESP_RAW", "")
try:
    r = json.loads(raw)
except json.JSONDecodeError:
    print(f"ERROR: non-JSON response: {raw[:300]}", file=sys.stderr)
    sys.exit(1)
if isinstance(r, dict) and ("error" in r or r.get("status") in (401, 422, 500)):
    print(f"ERROR: {r}", file=sys.stderr)
    sys.exit(1)
label = os.environ.get("LABEL", "OK")
print(f"✓ {label}")
print(f"  id:        {r.get('id')}")
print(f"  title:     {r.get('title')}")
print(f"  published: {r.get('published')}")
print(f"  url:       {r.get('url')}")
PY
}
