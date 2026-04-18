---
name: sentry
description: Interact with Sentry (EU region) — install SDK, triage issues, manage releases, upload source maps, CRUD alerts and projects. Use when user wants to track errors, add error monitoring, see recent issues, create a release, upload source maps, wire Sentry into an app, or manage alerts.
category: observability
argument-hint: [install | issue <list|get|resolve> | release <create|finalize> | sourcemaps upload | project <list|create> | alert <list|create>]
allowed-tools: Bash(curl *) Bash(jq *) Bash(pnpm *) Bash(sentry-cli *) Read Write Edit
---

# Sentry

CLI-first Sentry ops via the user API (EU region — `de.sentry.io` for most endpoints, `ronan-connolly.sentry.io` for org URL). Covers SDK install, issue triage, releases, source maps, and project/alert management.

## Usage

```
/ro:sentry install [--tanstack|--node|--both]      # wire SDK into current app
/ro:sentry issue list [--project <slug>] [--limit 20]
/ro:sentry issue get <issue-id>
/ro:sentry issue resolve <issue-id>
/ro:sentry release create <version> [--project <slug>]
/ro:sentry release finalize <version>
/ro:sentry sourcemaps upload <version> --dist <path>
/ro:sentry project list
/ro:sentry project create <slug> --platform javascript-react
/ro:sentry alert list [--project <slug>]
```

## Prerequisites

- Keys in `~/.claude/.env`:
  - `SENTRY_AUTH_TOKEN` — all-access user auth token (scopes: alerts:*, event:*, member:*, org:*, project:*, team:*)
  - `SENTRY_ORG=ronan-connolly`
  - `SENTRY_URL=https://ronan-connolly.sentry.io/` (UI only)
  - `SENTRY_REGION_URL=https://de.sentry.io` (API — EU region routing)
- `sentry-cli` for source-map uploads: `pnpm add -D @sentry/cli` (per-project) or `brew install getsentry/tools/sentry-cli`

## API routing

**Most API calls go to `${SENTRY_REGION_URL}/api/0/...`** (EU region). The non-region URL (`sentry.io`) works for some endpoints but returns 404 for others after the EU migration. Always use the region URL.

## Install — SDK wiring

### TanStack Start (React + server)

```bash
pnpm add @sentry/react @sentry/node @sentry/vite-plugin
```

Client — `src/lib/sentry.ts`:

```ts
import * as Sentry from "@sentry/react";

if (typeof window !== "undefined" && import.meta.env.PROD) {
  Sentry.init({
    dsn: import.meta.env.VITE_SENTRY_DSN,
    integrations: [Sentry.browserTracingIntegration(), Sentry.replayIntegration()],
    tracesSampleRate: 0.1,
    replaysSessionSampleRate: 0.0,
    replaysOnErrorSampleRate: 1.0,
    environment: import.meta.env.MODE,
  });
}
```

Server (Cloudflare Workers) — `src/lib/sentry-server.ts`:

```ts
import * as Sentry from "@sentry/cloudflare";

export const withSentry = Sentry.withSentry(
  (env: CloudflareEnv) => ({
    dsn: env.SENTRY_DSN,
    tracesSampleRate: 0.1,
  }),
  handler,
);
```

Vite plugin for source maps — `vite.config.ts`:

```ts
import { sentryVitePlugin } from "@sentry/vite-plugin";

export default defineConfig({
  plugins: [
    // ...,
    sentryVitePlugin({
      org: process.env.SENTRY_ORG,
      project: process.env.SENTRY_PROJECT,
      authToken: process.env.SENTRY_AUTH_TOKEN,
      url: process.env.SENTRY_REGION_URL,
    }),
  ],
  build: { sourcemap: true },
});
```

## Issue triage

### List recent issues for a project

```bash
curl -s "${SENTRY_REGION_URL}/api/0/projects/${SENTRY_ORG}/${PROJECT_SLUG}/issues/?statsPeriod=24h&limit=20" \
  -H "Authorization: Bearer ${SENTRY_AUTH_TOKEN}" \
  | jq '.[] | {id, title, level, count: .count, userCount, lastSeen, status}'
```

### Get a specific issue

```bash
curl -s "${SENTRY_REGION_URL}/api/0/issues/${ISSUE_ID}/" \
  -H "Authorization: Bearer ${SENTRY_AUTH_TOKEN}" \
  | jq '{title, culprit, platform, permalink, count, userCount, firstSeen, lastSeen}'
```

### Resolve / ignore

```bash
curl -s -X PUT "${SENTRY_REGION_URL}/api/0/issues/${ISSUE_ID}/" \
  -H "Authorization: Bearer ${SENTRY_AUTH_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"status": "resolved"}'
```

Valid statuses: `resolved`, `unresolved`, `ignored`.

## Releases

Releases pair errors to deploys. Create one per deploy — the skill's `release create` runs on deploy (pairs well with `/ro:cf-ship`).

```bash
VERSION=$(git rev-parse --short HEAD)

# 1. Create release
curl -s -X POST "${SENTRY_REGION_URL}/api/0/organizations/${SENTRY_ORG}/releases/" \
  -H "Authorization: Bearer ${SENTRY_AUTH_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{
    \"version\": \"${VERSION}\",
    \"projects\": [\"${PROJECT_SLUG}\"],
    \"refs\": [{\"repository\": \"ronan-connolly/${REPO}\", \"commit\": \"${VERSION}\"}]
  }"

# 2. Upload source maps (via sentry-cli)
sentry-cli releases files "${VERSION}" upload-sourcemaps ./dist --url-prefix '~/'

# 3. Finalize
curl -s -X PUT "${SENTRY_REGION_URL}/api/0/organizations/${SENTRY_ORG}/releases/${VERSION}/" \
  -H "Authorization: Bearer ${SENTRY_AUTH_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"dateReleased": "'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'"}'
```

`sentry-cli` honours `SENTRY_AUTH_TOKEN`, `SENTRY_ORG`, `SENTRY_URL` env vars — point `SENTRY_URL` to the region URL for uploads:

```bash
export SENTRY_URL=${SENTRY_REGION_URL}
```

## Project management

### List

```bash
curl -s "${SENTRY_REGION_URL}/api/0/organizations/${SENTRY_ORG}/projects/" \
  -H "Authorization: Bearer ${SENTRY_AUTH_TOKEN}" \
  | jq '.[] | {slug, name, platform, id}'
```

### Create

```bash
curl -s -X POST "${SENTRY_REGION_URL}/api/0/teams/${SENTRY_ORG}/${TEAM_SLUG}/projects/" \
  -H "Authorization: Bearer ${SENTRY_AUTH_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "my-app",
    "slug": "my-app",
    "platform": "javascript-react"
  }'
```

Grab the DSN from the response's `keys[0].dsn.public` — this is what goes in the app's `SENTRY_DSN` (per-app, `.dev.vars` + wrangler secret).

## Alerts

```bash
curl -s "${SENTRY_REGION_URL}/api/0/projects/${SENTRY_ORG}/${PROJECT_SLUG}/rules/" \
  -H "Authorization: Bearer ${SENTRY_AUTH_TOKEN}" \
  | jq '.[] | {id, name, status, conditions: [.conditions[] | .name]}'
```

Creating alert rules via API is verbose (complex condition/action schemas) — the skill prefers the dashboard for creation and API for listing/auditing.

## Env var summary

**Global (`~/.claude/.env`)**:
- `SENTRY_AUTH_TOKEN` — this skill's management API
- `SENTRY_ORG=ronan-connolly`
- `SENTRY_URL=https://ronan-connolly.sentry.io/` — for UI permalinks in output
- `SENTRY_REGION_URL=https://de.sentry.io` — for all API calls

**Per-app** (`.dev.vars` + wrangler secret):
- `SENTRY_DSN` — client + server init. Generate via `sentry project create` or dashboard
- `SENTRY_PROJECT` — project slug (used by Vite plugin)
- Also exposed to Vite as `VITE_SENTRY_DSN`

## EU region note

Ronan's org is on the EU region (`de.sentry.io`). The UI URL (`ronan-connolly.sentry.io`) works in browser, but API calls must hit `de.sentry.io` or you get 404/403. `SENTRY_REGION_URL` captures this distinction.

## Safety

- `SENTRY_AUTH_TOKEN` has org-admin scope — NEVER ship it to the client or commit it. Server-only.
- Deleting a project is irreversible (destroys all historical events). This skill does NOT implement project delete — do it manually if needed.
- Before resolving an issue en masse, show the user the count of affected events and ask to confirm.
- Source-map uploads are idempotent — safe to re-run.

## See also

- `/ro:posthog` — the other half of observability
- `/ro:cf-ship` — chain release creation + finalize into deploy pipeline
- Sentry API docs: https://docs.sentry.io/api — use context7
