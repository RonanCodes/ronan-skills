---
name: dev-to
description: Post and manage articles on dev.to (Forem) via the official API. Create drafts from markdown files, publish or unpublish, list and update existing posts. Use when user wants to publish a dev.to post, draft a dev.to article, fetch their dev.to profile, or sync a markdown file to dev.to.
category: social
argument-hint: <me | list [drafts|published|all] | draft <file.md> [--publish] [--open] | publish <id> | update <id> <file.md> | get <id> | open <id>>
allowed-tools: Bash(curl *) Bash(python3 *) Bash(open *) Read Write Edit
content-pipeline:
  - pipeline:distribution
  - platform:devto
  - role:adapter
---

# DEV (dev.to)

Post and manage articles on dev.to via the Forem REST API. Stable v1, single API key, no OAuth dance. Sibling to `ro:linkedin` for cross-posting.

## Usage

```
/ro:dev-to me                          # smoke-test auth, print profile
/ro:dev-to list                        # list all my articles
/ro:dev-to list drafts                 # list unpublished only
/ro:dev-to list published              # list published only
/ro:dev-to draft post.md               # POST as draft
/ro:dev-to draft post.md --publish     # POST and publish in one shot
/ro:dev-to draft post.md --open        # POST as draft, then open in browser
/ro:dev-to publish <id>                # flip an existing draft to published
/ro:dev-to update <id> post.md         # edit an existing article
/ro:dev-to get <id>                    # fetch one article (markdown)
/ro:dev-to open <id>                   # open the article in the browser
```

## Markdown file format

Standard dev.to frontmatter — same shape as the dev.to web editor accepts:

```markdown
---
title: "Connections Helper: a daily NYT puzzle solver"
published: false
description: "What I built and why it took two weekends, not two hours"
tags: ai, claude, sideproject, javascript
canonical_url: https://ronanconnolly.dev/posts/connections-helper
cover_image: https://ronanconnolly.dev/og/connections-helper.png
series: "Building with Claude Code"
---

# Body markdown here
```

Forem extracts the frontmatter server-side, so the file is portable: same source works in the dev.to web editor, the API, or as a markdown file in your own site.

**Tag rules** — max 4. Lowercase. No hyphens (`webdev` not `web-dev`).
**`canonical_url`** — keep your own site as the SEO source of truth and republish here without duplicate-content penalty.
**`cover_image`** — must be a hosted URL. Forem does not accept uploads via API.

## Dispatch

| Arg | Script |
|-----|--------|
| `me` | `scripts/me.sh` |
| `list [filter]` | `scripts/list.sh` |
| `get <id>` | `scripts/get.sh` |
| `draft <file> [--publish] [--open]` | `scripts/draft.sh` |
| `publish <id>` | `scripts/publish.sh` |
| `update <id> <file>` | `scripts/update.sh` |
| `open <id>` | `scripts/open.sh` |

Pass all trailing args through verbatim.

## First-time setup

1. Generate an API key at https://dev.to/settings/extensions → **DEV Community API Keys** (give it a description like `ronan-skills`).
2. Append to `~/.claude/.env` under a `# --- DEV Community / dev.to ---` header:
   ```
   DEVTO_API_KEY=...
   ```
   `chmod 600 ~/.claude/.env`.
3. Smoke-test: `/ro:dev-to me`. Should print your username + id + bio.

## What this skill does NOT do

- **Cover image upload** — Forem API takes a URL only. Host the image somewhere (your site, R2, S3) or upload via the dev.to web UI and copy the URL out.
- **Delete an article** — no DELETE endpoint in the public v1 API. Closest equivalent is `update <id>` with frontmatter `published: false` to unpublish.
- **Comments / reactions / follows** — endpoints exist but are not wired here. Ask to extend.
- **Posting on behalf of an organization** — needs `organization_id` in the article body. Not wired by default; ask to extend.

## Closing the loop

`draft` and `publish` print the article id and URL on success. Use `--open` to auto-open in the browser. Pair with `/ro:linkedin post` to cross-post the same source markdown to LinkedIn (the LinkedIn skill takes plain text, so trim the dev.to frontmatter and headers first).

## See also

- `ingest-devto` (in llm-wiki) — the inverse: pulls a dev.to article INTO a wiki vault.
- `ro:write-copy` — load before drafting any post body. Required for `/ro:` voice.
- `ro:linkedin` — sibling for LinkedIn posts. Cross-post pattern: write once, publish to dev.to and LinkedIn from the same source.
- `reference.md` — full API reference, error codes, frontmatter spec, pagination.
- Forem API docs: https://developers.forem.com/api/v1
