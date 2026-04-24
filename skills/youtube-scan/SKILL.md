---
name: youtube-scan
description: Scan YouTube for videos by topic (search), channel (uploads feed), or URL (metadata). Returns titles, view counts, channel, upload date — no transcripts or summaries. Pair with `/ro:video-summarize` when you want to dig into one.
category: research
argument-hint: <topic-or-url-or-channel> [--since 24h|7d|30d] [--limit N] [--min-views N]
allowed-tools: Bash(yt-dlp *) Bash(curl *) Bash(which *) Bash(date *) Read
---

# YouTube Scan

Three modes, auto-detected from the argument:

- **Topic search** — `"AI agents"` or `"MCP servers"` → `yt-dlp "ytsearchN:<q>"`
- **Channel feed** — `https://www.youtube.com/@<handle>` or channel URL → uploads RSS
- **Video URL** — `https://www.youtube.com/watch?v=...` or `https://youtu.be/...` → single-video metadata

No transcripts, no summaries — this is discovery, not digestion. For a deep dive, pipe a picked URL into `/ro:video-summarize`.

## Usage

```
/ro:youtube-scan "AI agents"                      # topic search, last 7d, top 15 by views
/ro:youtube-scan "MCP servers" --since 24h        # fresh drops
/ro:youtube-scan "vibe coding" --limit 30 --min-views 10000
/ro:youtube-scan https://www.youtube.com/@simonwillison        # channel's latest
/ro:youtube-scan https://www.youtube.com/watch?v=XXXX          # single video metadata
```

## Defaults

- **Window:** `7d`
- **Limit:** `15`
- **Min views:** none (raise with `--min-views` to filter out low-signal uploads)

## Mode: Topic search

```bash
yt-dlp "ytsearch${LIMIT}:${QUERY}" \
  --flat-playlist --dump-json \
  --match-filter "upload_date>=$(date -v-${SINCE} +%Y%m%d)" \
  2>/dev/null
```

Each JSON line has `title`, `url`, `channel`, `view_count`, `upload_date`, `duration`.

**Ranking heuristic:** `views / (days_since_upload + 2)` — similar to HN's age-decay, but view-weighted.

## Mode: Channel feed

Prefer the free RSS endpoint over `yt-dlp` for channel listings — no auth, no rate limiting:

```bash
# If given an @handle, first resolve to channel_id via yt-dlp
CHANNEL_ID=$(yt-dlp --print channel_id "$URL" --playlist-items 0 2>/dev/null | head -1)
curl -s "https://www.youtube.com/feeds/videos.xml?channel_id=${CHANNEL_ID}"
```

Atom XML. Parse with Python (namespace `http://www.w3.org/2005/Atom` and `http://search.yahoo.com/mrss/` for media metadata). Each `<entry>` has `<title>`, `<link href="...">`, `<published>`, `<media:statistics views="...">`.

## Mode: Single video URL

```bash
yt-dlp --dump-json --no-download "$URL"
```

Returns the full metadata blob. Pull: `title`, `uploader`, `view_count`, `like_count`, `upload_date`, `duration`, `description`, `tags`.

## Output

```
# YouTube: "<query>"  (window: <since>, mode: <search|channel|url>)

1. <Title>  (<N> views · <M> days ago · <channel>)
   https://www.youtube.com/watch?v=<id>
   <brief gist from description, 1 line>

2. ...
```

For the single-URL mode, emit:

```
# Video: <title>
Channel:  <channel>
Uploaded: <date> (<N days ago>)
Views:    <count>
Likes:    <count>
Duration: <mm:ss>

<description, first 5 lines>
```

## Discover mode (for trend-scan)

When called by `/ro:trend-scan --discover`, there's no topic. In that case run a handful of broad seeds in sequence:

```
ytsearch15:AI
ytsearch15:coding
ytsearch15:new tool
```

Filter to last 7d, dedupe by URL, sort by view count. Return the top 20.

## Dependencies

- `yt-dlp` (from the `video-summarize` skill install, or `brew install yt-dlp`)
- `curl` (for channel RSS)

## Error handling

- **yt-dlp fails for search** — YouTube occasionally rotates its scraping defenses. Fall back to `--extractor-args "youtube:player_client=web"` or try `--no-check-formats`.
- **Channel feed returns 404** — the channel handle → ID resolution failed. Ask the user for the canonical channel URL.
- **Trending feed** (`youtube.com/feed/trending`) is **broken** as of 2026-04 (redirects to homepage). Don't rely on it for discover mode; use seed searches instead.

## See also

- [`video-summarize`](../video-summarize/SKILL.md) — downstream: pick a video, get its transcript + slides + LLM summary.
- [`hn-scan`](../hn-scan/SKILL.md), [`reddit-scan`](../reddit-scan/SKILL.md), [`x-scan`](../x-scan/SKILL.md) — sibling source scanners.
- [`trend-scan`](../trend-scan/SKILL.md) — upstream: orchestrates all source scanners in parallel.
- [`llm-wiki/.claude/skills/ingest-youtube`](https://github.com/RonanCodes/llm-wiki/blob/main/.claude/skills/ingest-youtube/SKILL.md) — when you want to keep a video in a vault.
