#!/usr/bin/env bash
# Print the compiled voice-profile.md.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

if [ ! -f "$OUTPUT_FILE" ]; then
    echo "No compiled profile yet at $OUTPUT_FILE." >&2
    echo "Run: /ro:voice-profile compile" >&2
    exit 1
fi

cat "$OUTPUT_FILE"
