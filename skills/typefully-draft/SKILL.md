---
name: typefully-draft
description: Draft and queue social posts via the Typefully API across X, LinkedIn, Threads, Bluesky, and any other Typefully-connected account. Creates a draft you review in the Typefully app/web before it auto-posts, optionally schedules to a specific time, queues into the next free slot, returns a shareable preview link, or targets specific connected accounts. Supports single posts and threads (4-newline separator). Reads TYPEFULLY_API_KEY from ~/.claude/.env. Use when user wants to schedule, queue, draft, or cross-post to any Typefully-connected platform.
category: marketing
argument-hint: <text> [--thread] [--schedule <iso>] [--queue-next] [--share] [--auto-retweet] [--targets <ids>]
allowed-tools: Bash(bash *) Bash(curl *) Bash(jq *) Bash(set *) Bash(unset *) Bash(source *) Read
---

# Typefully Draft

Draft a post into Typefully so it stays in your review loop before it goes live. Threads, scheduling, shareable preview links, and per-account targeting are first-class. Posts never bypass the Typefully approval gate, which keeps connected accounts (e.g. `@ronancodes`) clear of bot-flag risk.

This skill is a Typefully API wrapper, not a direct platform poster. Whatever accounts you have connected in Typefully (X, LinkedIn, Threads, Bluesky, Mastodon, etc.) are reachable through it.

## Usage

```bash
# Single post, draft only (review in Typefully app before publishing)
/ro:typefully-draft "shipped a 16:9 promo for connectionshelper.app today. PH next month."

# Single post, scheduled for a specific time (UTC)
/ro:typefully-draft "good morning EU" --schedule "2026-04-26T07:00:00Z"

# Queue into Typefully's next free slot (uses your configured posting schedule)
/ro:typefully-draft "build-in-public day 3: shipped k6 load tests" --queue-next

# Thread: pass one --thread flag, then split posts with the literal token \n---\n
/ro:typefully-draft --thread "Day 1 of launching connectionshelper.app.\n---\nThe stack: TanStack Start, Cloudflare Workers, D1, Drizzle.\n---\nWhat I'm watching this week: r/NYTConnections."

# Get a shareable preview URL (for showing a friend before approval)
/ro:typefully-draft "thinking about a new tagline" --share

# Auto-retweet 24h after publish (Typefully built-in, X-only)
/ro:typefully-draft "PH launch day for connectionshelper.app. Link in replies." --queue-next --auto-retweet

# Target only specific connected accounts (skip cross-post defaults)
/ro:typefully-draft "engineering deep-dive on D1 caching" --targets "$TYPEFULLY_ACCOUNT_LINKEDIN"
```

## Prerequisites

- **Typefully account** at <https://typefully.com>. Free tier supports the API; check current limits at <https://typefully.com/pricing>.
- **API key** from Typefully Settings → Integrations → API. Add to `~/.claude/.env`:

  ```
  # Typefully
  TYPEFULLY_API_KEY=tf_xxxxxxxxxxxxxxxxxxxx

  # Optional: per-account targeting. Look up account IDs in the Typefully UI
  # (Settings → Social Sets → click an account → URL contains the ID) or via
  # a successful draft response (the response includes the routed account IDs).
  TYPEFULLY_ACCOUNT_X=123
  TYPEFULLY_ACCOUNT_LINKEDIN=456
  TYPEFULLY_ACCOUNT_THREADS=789
  TYPEFULLY_ACCOUNT_BLUESKY=012
  ```

- `curl` and `jq` (both standard on macOS).
- The Typefully account must have at least one social account connected — the draft becomes a real post when published, on whichever connected accounts the draft targets.

## Auth header

Typefully expects the literal string `Bearer` inside the `X-API-Key` header value:

```
X-API-Key: Bearer <your-key>
```

This is non-obvious. Without the `Bearer` prefix the API returns `403 Token is not valid`.

## What this skill does NOT do

- **Doesn't write the post for you.** Compose the text in conversation; this skill is the queue mechanism. Voice rules live in `/ro:write-copy`.
- **Doesn't post directly to any platform.** Everything routes through Typefully so you stay in the approval loop. If you want direct X API posting (no third-party in the loop), build a separate skill against `POST /2/tweets` — that path has bot-flag risk on a personal-brand account and requires a Twitter Developer app. Same calculus for LinkedIn (their OAuth posts API) or Bluesky (the AT Protocol).
- **Doesn't handle media uploads (yet).** Typefully has a media-upload endpoint; it's a v2 addition.
- **Doesn't auto-publish.** Default is "draft only." Add `--schedule` or `--queue-next` to schedule, but you should still eyeball in the Typefully app before the scheduled time hits.

## Process

### 1. Verify API key

```bash
set -a && source ~/.claude/.env && set +a
[ -n "$TYPEFULLY_API_KEY" ] || { echo "Missing TYPEFULLY_API_KEY in ~/.claude/.env" >&2; exit 1; }
```

### 2. Build the payload

The wrapper script handles this: `scripts/draft.sh` accepts the args from the argument-hint and emits the right JSON.

Single post payload:

```json
{ "content": "<text>" }
```

Thread payload — Typefully separates posts with **four newlines** (`\n\n\n\n`) inside `content`. The script translates `\n---\n` (a clearer human marker) into the four-newline separator before sending.

Optional fields:

| Field | Use |
|---|---|
| `schedule-date` | ISO 8601 UTC, or the literal string `"next-free-slot"` for queued posting |
| `share` | `true` to receive a public preview URL in the response |
| `auto_retweet_enabled` | `true` to auto-retweet 24h after publish (X only) |
| `account_id_to_share_to` | Connected-account ID (or list of IDs) to scope the draft to specific platforms. Field name based on Typefully API convention; verify against current docs if posts don't route correctly. |

### 3. POST to Typefully

```bash
curl -sS -X POST https://api.typefully.com/v1/drafts/ \
  -H "X-API-Key: Bearer $TYPEFULLY_API_KEY" \
  -H "Content-Type: application/json" \
  -d "$payload" | jq
```

### 4. Read the response

The response includes `id`, `share_url` (if `share=true`), and `scheduled_date`. Open `https://typefully.com/?d=<id>` to review and approve.

## The wrapper script

`scripts/draft.sh` is the entry point invoked by the slash command. Reads args, builds JSON, POSTs, prints a one-line success summary plus the full JSON for piping.

```bash
bash scripts/draft.sh "<text>"                                    # draft only
bash scripts/draft.sh --thread "p1\n---\np2\n---\np3"             # thread, draft only
bash scripts/draft.sh "<text>" --schedule "2026-04-26T09:00:00Z"
bash scripts/draft.sh "<text>" --queue-next
bash scripts/draft.sh "<text>" --share
bash scripts/draft.sh "<text>" --queue-next --auto-retweet
bash scripts/draft.sh "<text>" --targets "123,456"                # specific accounts only
```

## Per-account targeting

Without `--targets`, the draft posts to whatever the social-set's "default platforms for new drafts" toggle says (set in Typefully → Settings → Social Sets). For per-draft targeting:

1. Find each connected-account ID in the Typefully UI or by inspecting a successful draft response.
2. Store them in `~/.claude/.env` as `TYPEFULLY_ACCOUNT_<PLATFORM>` env vars.
3. Pass IDs (comma-separated) via `--targets`.

**Heads-up:** the field name (`account_id_to_share_to`) is a best-guess based on Typefully API convention. Public docs don't expose it. If the API rejects your `--targets` call, check the latest [Typefully API docs](https://help.typefully.com/) and update the field name in `scripts/draft.sh`.

## Voice rules (when drafting in conversation)

When Claude composes the post text inside the conversation, load `/ro:write-copy` first. The rules that bite hardest on social:

- **No em-dashes (—) or en-dashes (–).** Use commas, colons, parentheses, full stops.
- **No AI-tells:** delve, leverage, robust, seamless, unlock, streamline, "in today's fast-paced world", "at the intersection of."
- **Hooks do work in the first 7 words.** Social feeds cut off fast; bury nothing.
- **Threads:** keep each post ≤ 250 chars to leave room for retweet quoting. Don't pad to 280.
- **Build-in-public posts:** lead with the specific (a number, a screenshot reference, a concrete fix). Skip the meta-narration.
- **No call-to-action stuffing.** One CTA per post, last line, or skip.

## Anti-patterns

- **Posting bypassing the Typefully review gate** (e.g. via direct platform APIs in this skill). The whole point of the third-party scheduler is the human-in-the-loop check on a personal brand account.
- **Auto-scheduling without `--schedule` or `--queue-next`.** Default is "draft only"; user should approve in the Typefully UI before publish.
- **Threads of more than 5 posts.** Most feeds punish long threads now; if the content needs more, write a blog post and link it.
- **Using `--share` with `--schedule`.** Pick one: a preview link is for "show a friend, then I'll publish manually"; a schedule is for "publish at this time, no further intervention." Combining them implies a workflow that doesn't exist.
- **Cross-posting identical copy to all four platforms blindly.** LinkedIn rewards different rhythm and length than X; Bluesky has a different culture than Threads. Use `--targets` to scope a draft to one platform when the voice doesn't translate.

## See also

- `/ro:write-copy` — voice rules (em-dashes, AI-tells, scroll-stop hooks)
- `/ro:x-scan` — read-only X scraper for trend / competitor research
- `/ro:linkedin-scan` — read-only LinkedIn scraper for competitor analysis
- `/ro:trend-scan` — find what's trending before drafting
- [Typefully API docs](https://help.typefully.com/)
