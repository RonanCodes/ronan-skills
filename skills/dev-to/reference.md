# dev-to skill — reference

Background detail loaded on demand by Claude when something in `SKILL.md` is unclear or breaks.

## API base

- **Host:** `https://dev.to/api`
- **Auth header:** `api-key: <DEVTO_API_KEY>` (note: lowercase, hyphenated)
- **Versioning:** v1, beta. No version in path. Breaking changes possible.
- **Docs:** https://developers.forem.com/api/v1

## Endpoints used by this skill

| Method | Path | Used by |
|--------|------|---------|
| GET | `/users/me` | `me.sh` |
| GET | `/articles/me/all` | `list.sh all` |
| GET | `/articles/me/published` | `list.sh published` |
| GET | `/articles/me/unpublished` | `list.sh drafts` |
| GET | `/articles/:id` | `get.sh`, `open.sh` |
| POST | `/articles` | `draft.sh` |
| PUT | `/articles/:id` | `publish.sh`, `update.sh` |

## Article body shape

POST and PUT both wrap the article in an `article` key:

```json
{
  "article": {
    "title": "...",
    "body_markdown": "...",
    "published": false,
    "tags": ["ai","claude","sideproject","javascript"],
    "series": "Building with Claude Code",
    "main_image": "https://...",
    "canonical_url": "https://...",
    "description": "...",
    "organization_id": null
  }
}
```

The skill sends ONLY `body_markdown` (and optionally `published` from `--publish`). Forem extracts title, tags, etc. from frontmatter inside the markdown — same parser the dev.to web editor uses. This keeps the source file portable.

## Frontmatter spec

```yaml
---
title: "..."             # required for first save; can be left out on later updates
published: false          # boolean. false = draft, true = live
description: "..."        # social meta description, ~160 chars
tags: ai, claude, js      # comma-separated OR YAML list. Max 4. Lowercase, no hyphens.
canonical_url: https://...# SEO canonical (your own site, if you cross-post)
cover_image: https://...  # hosted URL only; uploads not supported via API
series: "Series name"     # groups posts on the dev.to series UI
---
```

## Tag rules

- Max **4** tags per post.
- Lowercase letters and digits only — `webdev` works, `web-dev` errors with 422.
- Tag must already exist OR be auto-creatable. Reserved or moderated tags can fail. If `422 Tag is not allowed`, drop or rename.

## Pagination

Listing endpoints accept `?per_page=<n>&page=<n>`.
- Default `per_page` is 30, max 1000.
- This skill uses `per_page=100`. If you have >100 articles, extend `list.sh` to loop.

## Common errors

| HTTP | Body | Likely cause | Fix |
|------|------|--------------|-----|
| 401 | `{"error":"unauthorized"}` | Bad / missing API key | Re-check `DEVTO_API_KEY` in `~/.claude/.env` |
| 404 | `{"error":"not found"}` | Wrong article id, or someone else's draft | Use `list drafts` to find your ids |
| 422 | `{"errors":{"tag_list":[...]}}` | Bad tag name (hyphenated, reserved, >4) | Fix frontmatter `tags:` |
| 422 | `{"errors":{"title":["can't be blank"]}}` | First save with no title in frontmatter | Add `title:` to frontmatter |
| 429 | rate limited | Too many writes | Back off; current limit is ~30 writes / 30s |

## Image hosting

Forem does not accept image uploads via the v1 API for `cover_image` or inline images. Options:
- Host on your own site (`https://ronanconnolly.dev/og/...`) — best for OG-image consistency.
- Upload to dev.to's web UI → paste the resulting CDN URL into the markdown.
- Use any public CDN (R2, S3, Cloudinary).

## Cross-posting pattern

Single source markdown → both dev.to and LinkedIn:

```bash
# Source: post.md with frontmatter for dev.to, plus a "## TLDR for LinkedIn" section.

# 1. Publish to dev.to as draft, preview, then promote.
/ro:dev-to draft post.md --open
/ro:dev-to publish <id>

# 2. Strip frontmatter + headings, take the TLDR, post to LinkedIn.
/ro:linkedin post "$(awk '/^## TLDR/{flag=1; next} /^## /{flag=0} flag' post.md)"
```

## Series & Organization

- **Series**: just set `series: "Name"` in frontmatter. dev.to creates the series on first use and groups subsequent posts with the same name.
- **Organization**: post on behalf of an org by adding `organization_id: <int>` to the article body. The skill does NOT pass this through frontmatter today — extend `draft.sh` to read it explicitly if needed.

## Why send body_markdown verbatim instead of parsed JSON

Two reasons:
1. **Single source of truth.** The same .md file works in the dev.to web editor, GitHub gists (with the dev.to GitHub action), Hashnode (similar frontmatter), and as a static site post. No format drift.
2. **Forem owns the parser.** When dev.to evolves frontmatter (new fields, validation), the skill keeps working without changes.

The trade-off: the skill cannot validate frontmatter client-side. A bad tag (hyphenated, >4) only fails at the API. That's acceptable — the error messages are clear and `--open` makes the round-trip fast.
