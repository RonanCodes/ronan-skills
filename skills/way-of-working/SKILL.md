---
name: way-of-working
description: Ronan's default working norms — commit cadence, checkpointing, asking for decisions, definition-of-done. Reference skill that should inform every coding session. Load at session start alongside coding-principles.
category: workflow
argument-hint: (reference skill; load automatically at session start)
---

# Way of Working

How Ronan wants day-to-day coding to feel. Short, blunt, non-negotiable unless he says otherwise mid-session.

## Commit cadence — commit at every checkpoint

Treat commits as save points, not milestones.

- Every logical unit of work gets its own commit. Don't let ten changes pile up.
- A checkpoint is any of: a feature works end-to-end, a refactor is complete, a bug is fixed, a dependency is added, a spec/doc is written. If the working tree is in a better-than-before state, commit it.
- Prefer many small emoji-conventional commits over one "kitchen sink" commit. Bisect-ability matters.
- Never leave a session with uncommitted work unless explicitly told to.

Use `/ro:commit` — it handles the emoji prefix, the timestamp rules, and the Co-Authored-By exclusion.

## Checkpointing during long tasks

Before starting a multi-step task, spell out the checkpoints. After each one:

1. Run whatever gates make sense for that checkpoint (typecheck, lint, test, manual UI check).
2. If green → commit.
3. If red → fix before moving on. Don't roll forward onto a broken base.

If a task fans out unexpectedly, break it into a second commit rather than bundling unrelated changes.

## Asking for decisions

If a decision comes up that isn't obvious from context, use `AskUserQuestion`, not a question typed inline in chat. This is enforced by the global CLAUDE.md. Keep doing it — Ronan prefers the structured UI.

## Definition of done

A task isn't done until:

- The code compiles (`tsc --noEmit` clean on TS projects)
- Linters pass (no new warnings)
- Relevant tests pass (unit + any e2e touched)
- For UI changes, the change was verified in a browser — not just "it should work"
- A commit exists for the change (see cadence)
- The user has been told what shipped, in one or two sentences

"It probably works" is not done.

## Defer don't drift

When you discover something unrelated that also wants fixing:

- Note it (todo, followup commit, or a short message to the user)
- Don't silently expand the current task to include it
- Finish what was asked, then propose the follow-up

Scope creep is how clean commits turn into 2,000-line diffs nobody can review.

## Never skip the red flags

- Don't use `--no-verify` on commits unless the user explicitly says so
- Don't `git reset --hard` or force-push without asking
- Don't delete files/branches the user might still need
- Don't silence a failing test to "unblock" — fix the test or the code

The whole point of the cadence above is that recovery is always cheap. Respect that.

## When to reach for Codex

Claude Code is primary. Codex (GPT-5.5-backed desktop app) earns a slot for parallel async refactors and high-volume cheap-token bulk jobs (one cited 10x cost win on a mechanical refactor). Reach for it when the work is mechanical, fan-out parallel, and Claude Code's per-task latency dominates. Default everything else to Claude Code; the `.claude/skills/` library, hooks, and ralph loop are a Claude-Code-native moat that does not port.

## Relation to other skills

- `/ro:coding-principles` — the *what*: simplicity, SOLID, DRY, testing norms
- This skill — the *how*: commit cadence, decision-asking, definition of done

Both should be in mental scope for every session.
