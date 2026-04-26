#!/usr/bin/env bash
# Print canonical paths for state file and compiled output.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

echo "state:  $STATE_FILE"
echo "output: $OUTPUT_FILE"

if [ -f "$STATE_FILE" ]; then
    echo
    echo "state status:"
    if command -v jq >/dev/null 2>&1; then
        jq -r '"  name:    \(.name)\n  status:  \(.status)\n  started: \(.started_at)\n  updated: \(.last_updated_at)"' "$STATE_FILE"
    else
        echo "  (install jq for details)"
    fi
fi

if [ -f "$OUTPUT_FILE" ]; then
    echo
    echo "output exists. Bytes: $(wc -c < "$OUTPUT_FILE")"
fi
