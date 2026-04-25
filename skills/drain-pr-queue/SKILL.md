---
name: drain-pr-queue
description: Merge a stack of open PRs sequentially without babysitting each one. Discovers (or accepts) a list of PRs, arms auto-merge on all of them, then update-branches in a loop as each one lands so the next becomes mergeable. Handles BEHIND, DIRTY, and CI-failure cases. Use when you have several PRs ready to ship and don't want to merge them one at a time. Sibling to /ro:gh-ship (that one drives a single feature; this one drains a queue).
category: development
argument-hint: [--prs 37,39,40] [--author @me|app/dependabot] [--dry-run]
allowed-tools: Bash(gh *) Bash(git *) Bash(curl *) Read
---

# Drain PR Queue

Merge a stack of N open PRs to main without manual hand-holding. Each merge invalidates the others (BEHIND main), so the loop keeps update-branching the rest until the queue is empty.

## Usage

```
/ro:drain-pr-queue                          # all open PRs by current user
/ro:drain-pr-queue --prs 37,39,40           # explicit list
/ro:drain-pr-queue --author app/dependabot  # drain dependabot's queue
/ro:drain-pr-queue --dry-run                # show plan, don't merge
```

## When to use

- Multiple PRs are open against `main`, all CI-green, all reviewed.
- You wrote them yourself and want them in without merging one, waiting for CI to re-pass on the next, then merging that one.
- A dependabot batch landed and you're ready to take them all.

## When NOT to use

- A PR has unresolved review comments. This skill assumes "ready to ship".
- You only have one PR (just use `gh pr merge` directly).
- The PRs touch overlapping logic that needs conflict review beyond a lockfile rebase. This skill resolves trivial rebases, not semantic conflicts.

## Process

### 1. Discover the queue

Unless `--prs` is given, list candidates:

```bash
gh pr list --state open --author "${AUTHOR:-@me}" \
  --json number,title,headRefName,mergeStateStatus,mergeable,statusCheckRollup,autoMergeRequest \
  --limit 50
```

Filter out:
- Draft PRs
- PRs with **failing required checks** (the user needs to fix those first; this skill doesn't fix CI)
- PRs that are mergeable: false (real conflicts that need human resolution)

Show the user the filtered list and confirm before proceeding (unless `--dry-run`, in which case just print and stop).

### 2. Topo-order to minimise rebase rounds

For each PR, get the changed files:

```bash
gh pr view N --json files -q '.files[].path'
```

Sort the queue so:
- Lockfile-touching PRs (`pnpm-lock.yaml`, `package-lock.json`, `yarn.lock`, `Cargo.lock`) go LAST. They invalidate every other PR's lockfile when they land, but landing first means everyone behind needs a lockfile rebase.
- Same-file pairs land adjacent so you only do the conflict resolution once.
- All others go first in PR-number order (oldest first is a fine tiebreaker).

### 3. Arm auto-merge on everything

```bash
for pr in "${QUEUE[@]}"; do
  gh pr merge "$pr" --squash --delete-branch --auto
done
```

If `gh pr merge --auto` fails with "Auto merge is not allowed for this repository", run once:

```bash
gh repo edit "$REPO" --enable-auto-merge
```

Then retry.

Do NOT change merge strategy without checking. Default to squash; respect the repo if it enforces a different strategy (look at branch protection: `gh api repos/$REPO/branches/main/protection`).

### 4. Bring everything up to date

```bash
for pr in "${QUEUE[@]}"; do
  gh api -X PUT "repos/$REPO/pulls/$pr/update-branch" 2>&1 | head -c 200
done
```

This kicks off CI on the rebased commits. As each one passes, auto-merge fires.

### 5. The watch loop

Cache-aware sleep is critical. Anthropic prompt cache TTL is 5min:

- 60-270s: cache stays warm, fine for active polling
- 300-3600s: cache miss; only when genuinely idle for that long
- **Don't pick 300s** (worst of both)

Default to **240s** between checks during a drain (CI on this codebase is ~3min per cycle, so 240s usually catches the next batch of merges).

Each cycle:

1. List remaining open PRs from the queue.
2. For each:
   - **MERGED** → mark progress, drop from queue.
   - **BEHIND, all checks green** → `gh api -X PUT .../update-branch` to bring current.
   - **BEHIND, CI running** → leave alone, the CI is from a previous update.
   - **DIRTY** → handle conflicts (next section).
   - **BLOCKED, failing required check** → stop the drain. Surface the failure: `gh run view --log-failed`. Don't try to fix; that's outside scope.
3. If the queue is empty, write the final summary and stop.
4. Otherwise, schedule another wakeup at 240s.

### 6. Handling DIRTY (real conflict)

For dependabot PRs:

```bash
gh pr comment "$pr" --body "@dependabot rebase"
```

Wait one cycle (240s), then re-check. Dependabot typically rebases within 1-3min.

For user-authored PRs (or if dependabot rebase failed):

```bash
git fetch origin "pull/$pr/head:pr-$pr-tmp" --force
git checkout "pr-$pr-tmp"

# Reset to current main and re-apply just the PR's logical change.
# This works when the conflict is purely lockfile/generated noise. For
# semantic conflicts, BAIL and tell the user — don't guess.
git reset --hard origin/main
# <re-apply the change manually here, OR cherry-pick the original head>

git push origin "pr-$pr-tmp:$BRANCH" --force
git checkout main
git branch -D "pr-$pr-tmp"
```

Auto-merge stays armed across force-pushes (verify with `gh pr view N --json autoMergeRequest`).

### 7. Final report

When the queue empties:

```
Drained N PRs in ~M minutes:
  ✅ #N1 — <title>
  ✅ #N2 — <title>
  ...
  ⚠️  #N3 — BLOCKED on <reason> (left open)
```

## Hard rules

- **Never** bypass branch protection (`--no-verify`, `--admin`, force-push to main).
- **Never** merge a PR with failing required checks. Stop and surface.
- **Never** auto-resolve a semantic merge conflict. Lockfile/generated-file conflicts are fine to rebase through; logic conflicts mean stop.
- **Never** force-push to `main`/`master`. Force-push only to feature branches you control.
- **Always** use squash by default. Match the repo's branch-protection setting if different.

## Cycle budget

A typical drain of 5 PRs on a repo with ~3min CI is ~50min wall clock. Most of that is CI wait. The watch loop should NOT busy-poll under 60s.

## Why this is faster than merging one-by-one manually

Without the skill: merge → wait for CI on next → realise it's BEHIND → update-branch → wait again → merge → repeat. You're context-switching every 3min.

With the skill: arm auto-merge once, then update-branch + sleep loop. You get notified at the end.

## Composition

- `/ro:gh-ship` ships ONE feature branch (PR open + watch + merge).
- `/ro:drain-pr-queue` ships N already-open PRs in sequence.
- Use `/ro:gh-ship` per feature, then `/ro:drain-pr-queue` once you have a backlog.
