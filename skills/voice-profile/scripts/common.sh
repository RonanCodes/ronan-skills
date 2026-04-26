#!/usr/bin/env bash
# Shared paths + helpers for the ro:voice-profile skill.
# Sourced, not executed.

STATE_FILE="${VOICE_PROFILE_STATE:-$HOME/.claude/voice-profile-state.json}"
OUTPUT_FILE="${VOICE_PROFILE_OUTPUT:-$HOME/.claude/voice-profile.md}"

# Total per category (must match the methodology).
CAT_KEYS=(1_beliefs 2_mechanics 3_aesthetic_crimes 4_voice_personality 5_structural 6_hard_nos 7_red_flags)
CAT_TARGETS=(15       20         15                 15                  15          10         10)
CAT_TITLES=(
  "Beliefs & Contrarian Takes"
  "Writing Mechanics"
  "Aesthetic Crimes"
  "Voice & Personality"
  "Structural Preferences"
  "Hard Nos"
  "Red Flags"
)

ensure_claude_dir() {
    mkdir -p "$(dirname "$STATE_FILE")"
}

require_jq() {
    if ! command -v jq >/dev/null 2>&1; then
        echo "ERROR: jq is required but not installed. brew install jq" >&2
        exit 1
    fi
}
