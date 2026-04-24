#!/usr/bin/env bash
# Shared env loading and token checks for the ro:linkedin skill.
# Sourced, not executed.

ENV_FILE="${LINKEDIN_ENV_FILE:-$HOME/.claude/.env}"

if [ ! -f "$ENV_FILE" ]; then
    echo "ERROR: $ENV_FILE not found. See skills/linkedin/SKILL.md 'First-time setup'." >&2
    exit 1
fi

set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

require_token() {
    if [ -z "${LINKEDIN_ACCESS_TOKEN:-}" ]; then
        echo "ERROR: LINKEDIN_ACCESS_TOKEN not set. Run: /ro:linkedin auth" >&2
        exit 1
    fi
    if [ -z "${LINKEDIN_PERSON_SUB:-}" ]; then
        echo "ERROR: LINKEDIN_PERSON_SUB not set. Re-run: /ro:linkedin auth" >&2
        exit 1
    fi
    local now expires days
    now=$(date +%s)
    expires="${LINKEDIN_ACCESS_TOKEN_EXPIRES_AT:-0}"
    if [ "$now" -ge "$expires" ]; then
        echo "ERROR: LINKEDIN_ACCESS_TOKEN expired. Re-run: /ro:linkedin auth" >&2
        exit 1
    fi
    days=$(( (expires - now) / 86400 ))
    if [ "$days" -lt 7 ]; then
        echo "Warning: LinkedIn token expires in $days day(s). Re-run /ro:linkedin auth soon." >&2
    fi
}

# Mask a token for safe printing — show last 4 chars only.
mask_token() {
    local t="${1:-}"
    local n=${#t}
    if [ "$n" -lt 5 ]; then
        echo "…"
    else
        echo "…${t: -4}"
    fi
}
