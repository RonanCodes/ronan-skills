#!/usr/bin/env bash
# Draft-only profile edits. LinkedIn has no public write API for profile sections.
# This script copies the draft to the clipboard and opens the closest LinkedIn edit URL.
#
# Usage:
#   draft-edit.sh <about|headline|experience|education|skills> ["draft text"]
#
# If no draft text is given, just opens the editor.
set -euo pipefail

SECTION="${1:-}"
TEXT="${2:-}"

if [ -z "$SECTION" ]; then
    cat >&2 <<EOF
usage: draft-edit.sh <section> ["draft text"]
sections: about | headline | experience | education | skills
EOF
    exit 1
fi

PROFILE="https://www.linkedin.com/in/me/"
case "$SECTION" in
    about)
        URL="$PROFILE"
        HINT="Scroll to the About section and click the pencil icon."
        ;;
    headline)
        URL="$PROFILE"
        HINT="Click the pencil icon on the intro card (top) to edit your headline."
        ;;
    experience)
        URL="https://www.linkedin.com/in/me/add-edit/POSITION/"
        HINT="Fill the Add position form. If this 404s, open $PROFILE and use the + next to Experience."
        ;;
    education)
        URL="https://www.linkedin.com/in/me/add-edit/EDUCATION/"
        HINT="Fill the Add education form. If this 404s, open $PROFILE and use the + next to Education."
        ;;
    skills)
        URL="$PROFILE"
        HINT="Scroll to Skills and click the pencil icon."
        ;;
    *)
        echo "unknown section: $SECTION (use: about, headline, experience, education, skills)" >&2
        exit 1
        ;;
esac

echo "# LinkedIn draft-edit — $SECTION"
echo

if [ -n "$TEXT" ]; then
    echo "## Draft copy"
    echo
    printf '%s\n' "$TEXT"
    echo
    if command -v pbcopy >/dev/null 2>&1; then
        printf '%s' "$TEXT" | pbcopy
        echo "✓ Copied to clipboard (pbcopy)."
    elif command -v xclip >/dev/null 2>&1; then
        printf '%s' "$TEXT" | xclip -selection clipboard
        echo "✓ Copied to clipboard (xclip)."
    else
        echo "(no clipboard tool found — copy the text above manually)"
    fi
    echo
fi

echo "## Open in browser"
echo "  $URL"
echo "  $HINT"

if command -v open >/dev/null 2>&1; then
    open "$URL"
elif command -v xdg-open >/dev/null 2>&1; then
    xdg-open "$URL" >/dev/null 2>&1 &
fi
