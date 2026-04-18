---
name: skill-retro
description: Retrospective on skills used in the current session — surfaces friction, proposes concrete edits to SKILL.md files, and commits improvements. Use when the user wants to evolve, improve, review, refine, or retro the skills they just ran. Also use proactively at the end of a multi-skill task.
category: development
argument-hint: [--skill <name>] [--apply] [--since <ref>]
allowed-tools: Bash(git *) Bash(grep *) Bash(find *) Read Write Edit Glob Grep
---

# Skill Retro

Close the loop on skill usage. Walk back through what ran this session, surface friction, propose concrete edits, commit the improvements. Skills compound only if they get sharper with use.

## Usage

```
/ro:skill-retro                           # review all skills used this session
/ro:skill-retro --skill new-tanstack-app  # focus on one skill
/ro:skill-retro --apply                   # also apply the proposed edits (otherwise just draft)
/ro:skill-retro --since HEAD~20           # review skills referenced in last N commits
```

## When To Use

- At the end of a multi-skill task (e.g. after `/ro:new-tanstack-app` + `/ro:cf-ship`)
- After a skill hit a rough edge (missing step, ambiguous flag, silent failure)
- Proactively on a slow day — pick a skill, read it critically, find what's stale
- Before committing a post-mortem — post-mortems are for bugs, this is for tools

## Process

### 1. Enumerate skills used

Determine which skills touched this session. Sources in order:

1. The conversation context — any `/ro:<name>` invocations or `skills/<name>/SKILL.md` reads
2. If `--since <ref>` is given: `git log <ref>..HEAD --all -- skills/` to find skills referenced in commits
3. If `--skill <name>` is given: just that one

If nothing is detectable, ask the user which skills to review.

### 2. For each skill, interrogate

Read the SKILL.md file. For each, answer:

- **Did it deliver?** Did the user get the outcome the description promises?
- **Friction?** Where did the agent pause, ask the user, or guess? Those are signals.
- **Missing steps?** Did the skill assume prior state that didn't exist? (e.g. assumed `wrangler` was installed, or a `.env` variable was set)
- **Outdated?** Commands, flags, pricing, URLs that no longer match reality?
- **Scope creep?** Is the skill doing too many things? Should it split?
- **Silent gaps?** Parts of the workflow the skill should cover but doesn't?

Capture findings in a structured report.

### 3. Draft the report

Output to stdout (not a file unless user asks):

```markdown
## Skill Retro — <date>

### /ro:new-tanstack-app
- ✅ Worked end-to-end for connections-helper migration scaffold
- ⚠️ Friction: assumed `corepack enable` was already done; hit "pnpm not found" on first try
- 💡 Proposed edit: add explicit `command -v pnpm || corepack enable pnpm` check in step 1 before running `pnpm create`
- 📝 Diff sketch: [show the proposed change to SKILL.md]

### /ro:cf-ship
- ✅ Pre-flight caught a type error that would have shipped broken
- ⚠️ Smoke check hit a 500 but gave no hint about which binding was missing
- 💡 Proposed edit: on smoke-check failure, auto-run `wrangler tail` for 10s and surface the first error line
- 📝 Diff sketch: [...]
```

### 4. Propose diffs

For each 💡, show the concrete SKILL.md edit inline so the user can accept or redirect. Keep edits small and focused — if a skill needs a major restructure, say so and stop there; don't rewrite without discussion.

### 5. Apply (if `--apply`)

If `--apply` was passed, apply the diffs via `Edit` tool, then:

```bash
cd /Users/ronan/Dev/ronan-skills    # adjust if different
git add skills/<name>/SKILL.md
git commit -m "♻️ refactor: evolve <skill-name> — <what changed>"
```

Use `/ro:commit` for the commit if that skill is loaded (handles timestamp rules + emoji format). Otherwise inline the message in the emoji + conventional format.

### 6. Bump frontmatter

Optionally bump a `last-reviewed: YYYY-MM-DD` field in the skill frontmatter to track which skills haven't been retro'd recently. If the field doesn't exist yet, add it.

## Anti-Patterns

- **Rewriting on first use.** A skill isn't broken because it didn't predict every edge case. Needs several runs of friction before it's worth a big edit.
- **Adding "safety" catches.** Don't pile on defensive checks for impossible states. If the check would fire once in 1000 runs, it's noise in the SKILL.md file.
- **Documentation drift.** Don't update the SKILL.md *description* (frontmatter) from retro — that's how Claude routes to the skill. Only change it if the skill's actual scope changed.
- **Batching a full repo retro into one commit.** One skill per commit. Easier to revert, easier to read.

## Feedback Signals Cheat Sheet

| Signal during a task | What it likely means | Retro action |
|---|---|---|
| Agent asked the user a clarifying question | Skill missing a step or ambiguous | Add the step / clarify the flag |
| Agent guessed at a value and was wrong | Skill assumes prior state | Add an explicit check or env-var fallback |
| Same shell command fails repeatedly | Command drifted (tool update, deprecation) | Update the command |
| User interrupted with "don't do X" | Anti-pattern surfaced | Add to Safety or Anti-Patterns section |
| Skill did nothing useful, user did manually | Skill is obsolete or miscategorised | Delete or merge into another |

## See also

- `/ro:post-mortem` — for bugs in the *product*, not the skill (different shape)
- `/ro:create-skill` — for brand-new skills surfaced by the retro as gaps
- `/ro:commit` — emoji-conventional commits for the retro changes
