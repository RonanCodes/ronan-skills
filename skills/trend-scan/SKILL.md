---
name: trend-scan
description: Scan multiple sources (Hacker News, X, Reddit, optionally LinkedIn) in parallel for a topic, rank what's hot, and return a synthesised brief. Use to find cutting-edge ideas, validate hype, or pre-research a product launch.
category: research
argument-hint: <topic> [--sources hn,x,reddit,linkedin] [--since 24h|7d|30d] [--limit N]
allowed-tools: Bash(curl *) Read
---

# Trend Scan

Parallel fan-out across source scanners to answer "what's hot on this topic right now?". Uses `/ro:hn-scan`, `/ro:x-scan`, `/ro:reddit-scan`, and optionally `/ro:linkedin-scan`, then fuses their output into a single ranked brief.

## Usage

```
/ro:trend-scan "agent observability"
/ro:trend-scan "MCP servers" --sources hn,reddit --since 7d
/ro:trend-scan "vibe coding" --since 30d --limit 15
/ro:trend-scan "Claude Code skills" --sources hn,x,reddit,linkedin
```

## Defaults

- **Sources:** `hn,x,reddit` (LinkedIn is opt-in because cookie auth is required)
- **Window:** `7d`
- **Limit:** 10 items per source

## Process

1. **Fan out** — run the selected source scans in parallel. Each is an independent curl call, so they complete in roughly the time of the slowest one.
2. **Normalise** — for each result, capture:
   - `source` (`hn` | `x` | `reddit` | `linkedin`)
   - `title_or_gist` (headline, tweet text, or post summary)
   - `url` (the thread / post URL)
   - `score` (points, likes, upvotes — source-specific units)
   - `comments` (if applicable)
   - `author`
   - `created_at`
3. **Rank** — combine recency + engagement. Simple heuristic:
   - `rank = score / (age_hours + 2)^1.5`
   - Cap score per source (e.g. HN points scale differently from X likes) by computing per-source z-scores before blending, then sort across sources.
4. **Cluster (optional)** — if two items clearly reference the same thing (same linked URL, or near-identical titles), merge them into a single entry with `sources: [hn, x]`.
5. **Summarise** — surface the top N (default 15) across all sources, plus a short "themes" paragraph listing patterns you spot.

## Output format

```
# Trend: "<topic>"  (window: <since>, sources: <which ran>)

## Themes
- <one-line pattern #1>
- <one-line pattern #2>
- <one-line pattern #3>

## Top items

1. [HN, <points>pts, <comments>c] <title>
   https://news.ycombinator.com/item?id=<id>
   <external url if relevant>
   <1-line takeaway>

2. [X, <likes>♥] @<user>: <gist>
   https://x.com/<user>/status/<id>

3. [Reddit, <score>, r/<sub>] <title>
   https://reddit.com/<permalink>

...

## Sources that failed or were skipped
- LinkedIn: not requested (opt-in)
- X: no results (nitter mirrors down — retry later with `--sources hn,reddit`)
```

## Error handling

- **Partial failure is OK** — if X fails but HN + Reddit succeed, return what you have with a note under "Sources that failed".
- **Total failure** — if every source fails, explain why (rate limit, network) and suggest `/ro:perplexity-research` as a fallback.

## When to use which tool

| Task | Use |
|---|---|
| "What's hot on this topic?" | `/ro:trend-scan` |
| "Fetch this specific thread" | `/ro:hn-scan <url>` or `/ro:reddit-scan <url>` |
| "Read this tweet" | `/ro:x-scan <url>` |
| "Research a topic with citations" | `/ro:perplexity-research` |
| "Keep this content long-term" | `llm-wiki /ingest` |

## Dependencies

Inherits dependencies from the scanners it calls (`curl`, optional `firefox-cookies` for LinkedIn).

## See also

- `/ro:hn-scan`, `/ro:x-scan`, `/ro:reddit-scan`, `/ro:linkedin-scan` — the per-source skills this orchestrates.
- `/ro:perplexity-research` — citation-backed AI research; complementary (perplexity = depth, trend-scan = breadth).
- `llm-wiki/.claude/skills/ingest` — when you want to keep the findings.
