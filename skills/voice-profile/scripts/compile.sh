#!/usr/bin/env bash
# Compile state.json into voice-profile.md.
# Works on partial state — unanswered sections are marked.
# Does NOT derive Quick Reference Card or Anti-Overfitting labels — that's Claude's job
# in a follow-up Edit pass after compile produces the skeleton.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"
require_jq

if [ ! -f "$STATE_FILE" ]; then
    echo "ERROR: no state file at $STATE_FILE. Run start first." >&2
    exit 1
fi

NAME=$(jq -r '.name' "$STATE_FILE")
NOW=$(date -u +"%Y-%m-%d")

# Q-number offsets per section (Q1-15, Q16-35, Q36-50, Q51-65, Q66-80, Q81-90, Q91-100).
declare -a Q_OFFSETS=(0 15 35 50 65 80 90)

{
    echo "# VOICE PROFILE: $NAME"
    echo
    echo "> Built via /ro:voice-profile on $NOW. Source methodology: Ruben Hassid, \"I am just a text file\" (Jan 2026) — https://ruben.substack.com/p/i-am-just-a-text-file"
    echo
    echo "## Core Identity"
    echo
    echo "_TODO: Claude to write a 2–3 sentence essence here after reviewing the full interview below._"
    echo
    echo "---"
    echo

    for i in "${!CAT_KEYS[@]}"; do
        KEY="${CAT_KEYS[$i]}"
        TITLE="${CAT_TITLES[$i]}"
        TARGET="${CAT_TARGETS[$i]}"
        OFFSET="${Q_OFFSETS[$i]}"
        DONE=$(jq -r --arg k "$KEY" '.categories[$k].answered | length' "$STATE_FILE")
        SECTION_NUM=$((i+1))

        echo "## Section $SECTION_NUM — $TITLE"
        echo
        if [ "$DONE" -eq 0 ]; then
            echo "_(not yet answered — $TARGET questions outstanding)_"
            echo
            continue
        fi

        # Each Q&A entry.
        jq -r --arg k "$KEY" --argjson offset "$OFFSET" '
            .categories[$k].answered
            | to_entries[]
            | "### Q\(.key + $offset + 1): \(.value.q)\n\n\(.value.a)\n" +
              (if (.value.follow_ups // [] | length) > 0
               then "\n**Follow-ups:**\n" + (
                    .value.follow_ups | map("- _\(.q)_\n  \(.a)") | join("\n")
                ) + "\n"
               else "" end)
        ' "$STATE_FILE"

        if [ "$DONE" -lt "$TARGET" ]; then
            REMAINING=$((TARGET - DONE))
            echo
            echo "_(${REMAINING} more questions to answer in this section)_"
            echo
        fi
    done

    echo "---"
    echo
    echo "## Quick Reference Card"
    echo
    echo "_TODO: Claude to derive the following from the interview answers above._"
    echo
    echo "### Always"
    echo "- _(extracted patterns)_"
    echo
    echo "### Never"
    echo "- _(extracted from Hard Nos, Aesthetic Crimes, Red Flags)_"
    echo
    echo "### Signature Phrases & Structures"
    echo "- _(quoted from the interview)_"
    echo
    echo "### Voice Calibration"
    echo "- _(key quotes from the interview that capture the voice)_"
    echo
    echo "---"
    echo
    echo "## How to Use This Document (Anti-Overfitting Guide)"
    echo
    echo "### Frequency labels"
    echo "Each tendency above carries one of:"
    echo
    echo "- **HARD RULE** — never violate. Rare; mostly in \"Never\" / \"Hard Nos\"."
    echo "- **STRONG TENDENCY** — do this 70–80% of the time. Breaking it occasionally is fine."
    echo "- **LIGHT PREFERENCE** — nice to have. Context decides."
    echo
    echo "If unlabelled, assume LIGHT PREFERENCE."
    echo
    echo "### Litmus test"
    echo
    echo "Before finalising any output written \"as me,\" ask:"
    echo
    echo "> Does this sound like something I would actually write — or does it sound like an AI trying very hard to imitate me?"
    echo
    echo "If it feels forced, pull back. **Less imitation, more inhabitation.**"
    echo
    echo "### Format adaptation"
    echo
    echo "Voice adapts to format. Tweet ≠ newsletter ≠ LinkedIn ≠ long-form. Tendencies tagged \"tweet-only\" or \"long-form-only\" should be honored only in their format."
    echo
    echo "---"
    echo
    echo "## Instructions for Claude"
    echo
    echo "Read this file first. Then do whatever the user asked. Every drafting prompt should start with this file in context."
    echo
    echo "When asked to \"write something in my voice,\" apply the rules — especially the Never section and the Aesthetic Crimes section. When in doubt, default to the litmus test above."
} > "$OUTPUT_FILE"

# Mark state as compiled (but keep status as-is if interview is incomplete).
TOTAL_DONE=$(jq '[.categories[] | .answered | length] | add' "$STATE_FILE")
if [ "$TOTAL_DONE" -ge 100 ]; then
    jq '.status = "compiled" | .compiled_at = (now | todate)' "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"
fi

echo "✓ Compiled voice profile"
echo "  output: $OUTPUT_FILE"
echo "  total answered so far: $TOTAL_DONE / 100"
if [ "$TOTAL_DONE" -lt 100 ]; then
    echo
    echo "Note: interview is incomplete. The output marks unanswered sections."
    echo "      Re-run compile after each session to refresh."
fi
echo
echo "Next: Claude should now Edit $OUTPUT_FILE to fill in:"
echo "  - Core Identity (2–3 sentences)"
echo "  - Quick Reference Card (Always / Never / Signature Phrases / Voice Calibration)"
echo "  - Frequency labels on individual answers above"
