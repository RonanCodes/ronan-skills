---
name: cloudflare-mcp-setup
description: One-time setup of the Cloudflare agent surface for Claude Code on a fresh machine. Wires the cloudflare-api MCP (Code Mode, bearer token from .env), the bundled cloudflare/skills plugin (skills + slash commands + 4 product MCPs), and OAuths the cloudflare-observability MCP for log queries. Idempotent. Use when onboarding a new machine, when cloudflare-api MCP is missing, or after running /ro:cloudflare-setup for the first time.
category: project-setup
argument-hint: [--verify | --smoke-test <worker-name> | --include-bindings-builds]
allowed-tools: Bash(claude mcp *) Bash(grep *) Bash(open *) Read
---

# Cloudflare MCP Setup

Wires the full Cloudflare agent surface in three lanes: knowledge (skills), capability (Code Mode), and logs (observability). Run when:

- Onboarding a new machine and `claude mcp list` does not include `cloudflare-api`
- The cloudflare-api MCP is connected but tools never surface in `ToolSearch`
- `/ro:cloudflare-setup` just succeeded for the first time and you want the agent surface too

This skill is the **second step** for a fresh machine. Run `/ro:cloudflare-setup` first to mint the API tokens; this skill assumes `CLOUDFLARE_API_TOKEN` already exists in `~/.claude/.env`.

## Usage

```
/ro:cloudflare-mcp-setup                              # full interactive setup
/ro:cloudflare-mcp-setup --verify                     # list which CF MCPs are connected + auth status
/ro:cloudflare-mcp-setup --smoke-test <worker>        # skip install, just verify against a named worker
/ro:cloudflare-mcp-setup --include-bindings-builds    # also OAuth bindings + builds MCPs (default skips)
```

## The three lanes (mental model)

This is the same model documented in the golden-stack canon at `[[ai-agent-stack]]` § Layer 8.

| Lane | What it gives you | Mechanism | Auth |
|------|-------------------|-----------|------|
| 1. Knowledge | 10 contextual `cloudflare:*` skills auto-loaded by context, plus 2 slash commands | Markdown context, no API calls | None |
| 2. Capability (full CRUD) | 2,500+ CF API endpoints in 2 tools (~1K tokens) via Code Mode | Agent writes JS against typed SDK, executes in CF sandbox | Bearer token from `~/.claude/.env` |
| 3. Capability (logs/metrics) | Workers Observability queries | Dedicated MCP per product surface | OAuth (separate scope) |

Knowledge and the two capability lanes compose; you do not have to pick one.

## Pre-flight checks

Before doing anything, verify:

```bash
# 1. Check token exists in env
grep -E '^CLOUDFLARE_API_TOKEN=' ~/.claude/.env | head -1
# Expected: a non-empty value. If missing, run /ro:cloudflare-setup first.

# 2. Check the manual MCP is not already wired
claude mcp list 2>&1 | grep -E '^cloudflare-api:'
# If "✓ Connected" appears, skip Step 1.

# 3. Check the plugin is not already installed
ls ~/.claude/plugins/cache/cloudflare/ 2>/dev/null
# If non-empty, skip Step 2.
```

## Step 1: Wire the cloudflare-api MCP (Code Mode + bearer token)

Adds the MCP at user scope so it's available in every project. Reuses the existing token (the same one wrangler and `/ro:cf-ship` already use). No new token needed.

```bash
# Source .env in a subshell to expand $CLOUDFLARE_API_TOKEN at shell-time only
# (the token value never appears in the tool output)
. ~/.claude/.env && claude mcp add --transport http -s user cloudflare-api \
  https://mcp.cloudflare.com/mcp \
  --header "Authorization: Bearer $CLOUDFLARE_API_TOKEN"
```

Verify:

```bash
claude mcp list 2>&1 | grep cloudflare-api
# Expected: cloudflare-api: https://mcp.cloudflare.com/mcp (HTTP) - ✓ Connected
```

> **Security note.** `claude mcp get cloudflare-api` will print the bearer token in plaintext. Avoid running it in a screen-sharing session. To rotate the token: regenerate at `dash.cloudflare.com/profile/api-tokens`, update `~/.claude/.env`, then `claude mcp remove cloudflare-api -s user` and re-run Step 1.

## Step 2: Install the cloudflare/skills plugin

The plugin bundles 10 skills, 2 slash commands, and 4 product-specific MCPs (`cloudflare-docs`, `cloudflare-bindings`, `cloudflare-builds`, `cloudflare-observability`). Slash commands cannot be triggered by a tool call, so the user has to type these in Claude Code:

```
/plugin marketplace add cloudflare/skills
/plugin install cloudflare@cloudflare
```

Expected output:

```
✓ Successfully added marketplace: cloudflare
✓ Installed cloudflare. Run /reload-plugins to apply.
```

Verify the plugin landed:

```bash
ls ~/.claude/plugins/cache/cloudflare/cloudflare/
# Expected: a versioned subdirectory like 1.0.0/
```

## Step 3: Restart Claude Code

MCPs added or installed mid-session connect immediately but their tool schemas do not surface in `ToolSearch` until next session start. Adding three new MCPs from the plugin compounds this. Restart now:

```
exit
claude
```

After restart, `ToolSearch` should find tools matching `mcp__cloudflare-api__*` and `mcp__plugin_cloudflare_cloudflare-docs__*`. The OAuth-required MCPs (`bindings`, `builds`, `observability`) will show up as `mcp__plugin_cloudflare_<name>__authenticate` until you complete the OAuth flow.

## Step 4: OAuth the observability MCP

Workers Observability sits on a separate API scope, so even though the bearer token is good for everything else it cannot read logs. The observability MCP handles this via OAuth.

The agent calls `mcp__plugin_cloudflare_cloudflare-observability__authenticate` which returns a URL. Open it:

```bash
# Agent will produce the URL; on macOS, this opens the browser:
open "<authorization-url-from-the-tool-result>"
```

Click "Authorize" on the page. The browser redirects to `localhost:<port>/callback` and the OAuth listener inside Claude Code completes the flow. The MCP's tools (`query_worker_observability`, `observability_keys`, `workers_list`, etc.) become available in the next `ToolSearch` query.

**Fallback if the redirect page errors out** (connection refused, blank page): copy the full URL from the address bar of the failed redirect tab and pass it to `mcp__plugin_cloudflare_cloudflare-observability__complete_authentication` with the `callback_url` param.

## Step 5 (optional): OAuth bindings + builds

Defaulted to **skip** because:

- `cloudflare-bindings` is redundant with the cloudflare-api MCP via Code Mode for D1/KV/R2 CRUD
- `cloudflare-builds` is only useful if you deploy via Workers Builds (CI inside CF) instead of wrangler from local or GitHub Actions

Pass `--include-bindings-builds` to OAuth them anyway. Same flow as Step 4.

## Step 6: Smoke test against a worker

Verify the setup against a real worker (use `--smoke-test <worker-name>` to jump straight here on subsequent runs).

The agent runs four checks in order, all using `mcp__cloudflare-api__execute`:

1. **Worker metadata** read
2. **Deployments list** (latest 5)
3. **Settings + bindings** read
4. **Code Mode write round-trip**: add a `MCP_SMOKE_TEST` plain_text var, verify it landed, remove it, verify it's gone

Then one check via observability:

5. **Logs query**: 5 most recent fetch events from the worker (last 7 days, broad time range to handle low-traffic windows)

Pass criteria: all 5 return without auth errors. Record the worker name and timestamp; if the same worker passes a future re-run after a token rotation, the rotation worked.

Reference smoke test that ran successfully on 2026-04-26 against `connections-helper`:

| Check | MCP | Auth | Result |
|---|---|---|---|
| Worker metadata | cloudflare-api | bearer | ✅ |
| Deployments list | cloudflare-api | bearer | ✅ |
| Settings + bindings | cloudflare-api | bearer | ✅ |
| Code Mode write round-trip | cloudflare-api | bearer | ✅ |
| Logs / observability query | cloudflare-observability | OAuth | ✅ |

## Step 7 (optional): record in canon

If this is the first time this machine has been wired up, the decision is already in canon at `[[ai-agent-stack]]` § Layer 8. No `/stack-update` call needed unless a step here changed (e.g. CF added a new MCP, or the install command changed).

If something HAS changed, run:

```
/stack-update "noted change in CF MCP setup: <one-line>"
```

The skill auto-routes to `ai-agent-stack.md` based on `mcp` + `cloudflare` keywords.

## What this does NOT do

- Does not run `/ro:cloudflare-setup` (that mints the API tokens; this skill assumes they exist)
- Does not replace `/ro:cf-ship` for deploys (that encodes the pre-flight checklist; this skill is for ad-hoc agent ops)
- Does not replace `wrangler` (still the canonical Workers CLI)
- Does not write to `~/.claude/.env` (no new env vars; reuses existing `CLOUDFLARE_API_TOKEN`)

## Verify mode (`--verify`)

Lists every CF-related MCP and its auth status. Useful as a health check after machine setup or after a Claude Code update:

```bash
claude mcp list 2>&1 | grep -iE 'cloudflare|^plugin:cloudflare'
```

Expected post-setup state:

```
plugin:cloudflare:cloudflare-docs: https://docs.mcp.cloudflare.com/mcp (HTTP) - ✓ Connected
plugin:cloudflare:cloudflare-bindings: https://bindings.mcp.cloudflare.com/mcp (HTTP) - ! Needs authentication
plugin:cloudflare:cloudflare-builds: https://builds.mcp.cloudflare.com/mcp (HTTP) - ! Needs authentication
plugin:cloudflare:cloudflare-observability: https://observability.mcp.cloudflare.com/mcp (HTTP) - ✓ Connected
cloudflare-api: https://mcp.cloudflare.com/mcp (HTTP) - ✓ Connected
```

(Bindings + builds showing "Needs authentication" is expected and fine; they're deferred.)

## Common failures

| Symptom | Likely cause | Fix |
|---|---|---|
| `claude mcp add` fails: `command not found` | Claude Code CLI not on PATH | Reinstall Claude Code; verify `which claude` |
| `cloudflare-api: ... ! Needs authentication` after Step 1 | Token expired or wrong scope | Rotate token in CF dashboard; update `.env`; re-run Step 1 |
| `mcp__cloudflare-api__execute` returns `10000: Authentication error` on the observability endpoint specifically | Bearer token lacks Workers Observability scope (this is expected) | Use the cloudflare-observability MCP (Step 4) for log queries; do not broaden the bearer token |
| Tools not in ToolSearch after restart | MCP connected but Claude Code's deferred-tool registry was cached | Force-restart: `pkill -f claude-code` then `claude` |
| OAuth tab shows "connection refused" after authorize | Claude Code's local OAuth listener wasn't up | Use the `complete_authentication` tool fallback (Step 4) |
| Plugin install prompt: `marketplace not found` | `/plugin marketplace add` step skipped | Re-run Step 2's first command |

## Anti-patterns

- **Do not** add the bearer token to multiple MCP configs (e.g. patching the plugin MCPs to use the bearer too). The OAuth-per-product split is intentional; broadening the token defeats it.
- **Do not** run `claude mcp get cloudflare-api` in a recorded or screen-shared session. It prints the token in plaintext.
- **Do not** install the `cloudflare/skills` plugin via `npx skills add`. The Claude Code marketplace flow (`/plugin marketplace add`) is the canonical path; the npx flow puts files in a different directory and bypasses plugin lifecycle hooks.
- **Do not** wire the bindings or builds MCPs by default. They duplicate Code Mode functionality for the use cases this user has today. Add later if Workers Builds gets adopted.

## Sources

- [Cloudflare MCP servers catalog](https://developers.cloudflare.com/agents/model-context-protocol/mcp-servers-for-cloudflare/)
- [Cloudflare Code Mode](https://blog.cloudflare.com/code-mode-mcp/)
- [Cloudflare Skills plugin (cloudflare/skills)](https://github.com/cloudflare/skills)
- Canon entry: `[[ai-agent-stack]]` § Layer 8 in `llm-wiki-research`
- Verified setup: 2026-04-26 against `connections-helper`
