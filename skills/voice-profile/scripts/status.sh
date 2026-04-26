#!/usr/bin/env bash
# Show interview progress: per-category answered/target, total, current section, status.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"
require_jq

if [ ! -f "$STATE_FILE" ]; then
    echo "No state file at $STATE_FILE."
    echo "Start a new interview: /ro:voice-profile start"
    exit 0
fi

NAME=$(jq -r '.name' "$STATE_FILE")
STATUS=$(jq -r '.status' "$STATE_FILE")
STARTED=$(jq -r '.started_at' "$STATE_FILE")
UPDATED=$(jq -r '.last_updated_at' "$STATE_FILE")

echo "Voice profile for: $NAME"
echo "Status:  $STATUS"
echo "Started: $STARTED"
echo "Updated: $UPDATED"
echo
printf "%-3s %-30s  %s / %s\n" "#" "Category" "done" "target"
echo "------------------------------------------------------------"

TOTAL_DONE=0
TOTAL_TARGET=0
NEXT_CAT=""

for i in "${!CAT_KEYS[@]}"; do
    KEY="${CAT_KEYS[$i]}"
    TITLE="${CAT_TITLES[$i]}"
    TARGET="${CAT_TARGETS[$i]}"
    DONE=$(jq -r --arg k "$KEY" '.categories[$k].answered | length' "$STATE_FILE")
    NUM=$((i+1))
    printf "%-3s %-30s  %3s / %s" "$NUM." "$TITLE" "$DONE" "$TARGET"
    if [ "$DONE" -ge "$TARGET" ]; then
        printf "  ✓\n"
    else
        printf "\n"
        if [ -z "$NEXT_CAT" ]; then
            NEXT_CAT="Section $NUM ($TITLE)"
            NEXT_Q=$((DONE + 1))
        fi
    fi
    TOTAL_DONE=$((TOTAL_DONE + DONE))
    TOTAL_TARGET=$((TOTAL_TARGET + TARGET))
done

echo "------------------------------------------------------------"
printf "%-34s  %3s / %s\n" "Total" "$TOTAL_DONE" "$TOTAL_TARGET"
echo

if [ -n "$NEXT_CAT" ]; then
    echo "Next: Q$NEXT_Q of $NEXT_CAT"
else
    echo "All 100 answered. Run: /ro:voice-profile compile"
fi
