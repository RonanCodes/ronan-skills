#!/usr/bin/env bash
# Initialize a new voice-profile state file.
# Args: <full-name>  (required, free text)
# Idempotent: if state file already exists, prints status and exits non-zero.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"
require_jq
ensure_claude_dir

NAME="${1:-}"
if [ -z "$NAME" ]; then
    echo "usage: start.sh \"<your full name>\"" >&2
    exit 1
fi

if [ -f "$STATE_FILE" ]; then
    echo "State file already exists: $STATE_FILE" >&2
    echo "Use 'resume' to continue, or delete the state file to start over." >&2
    exit 2
fi

NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Build categories object via jq for safety.
CATEGORIES_JSON=$(jq -n \
    --arg t1 "${CAT_TARGETS[0]}" --arg t2 "${CAT_TARGETS[1]}" --arg t3 "${CAT_TARGETS[2]}" \
    --arg t4 "${CAT_TARGETS[3]}" --arg t5 "${CAT_TARGETS[4]}" --arg t6 "${CAT_TARGETS[5]}" \
    --arg t7 "${CAT_TARGETS[6]}" \
    '{
        "1_beliefs":           {target: ($t1|tonumber), answered: []},
        "2_mechanics":         {target: ($t2|tonumber), answered: []},
        "3_aesthetic_crimes":  {target: ($t3|tonumber), answered: []},
        "4_voice_personality": {target: ($t4|tonumber), answered: []},
        "5_structural":        {target: ($t5|tonumber), answered: []},
        "6_hard_nos":          {target: ($t6|tonumber), answered: []},
        "7_red_flags":         {target: ($t7|tonumber), answered: []}
    }')

jq -n \
    --arg name "$NAME" \
    --arg now "$NOW" \
    --argjson cats "$CATEGORIES_JSON" \
    '{
        version: 1,
        name: $name,
        started_at: $now,
        last_updated_at: $now,
        status: "in_progress",
        categories: $cats
    }' > "$STATE_FILE"

echo "✓ Initialized voice-profile state for: $NAME"
echo "  state:  $STATE_FILE"
echo "  output: $OUTPUT_FILE (created on compile)"
echo
echo "Next: ask Q1 of Section 1 (Beliefs & Contrarian Takes)."
