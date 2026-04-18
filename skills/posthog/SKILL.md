---
name: posthog
description: Interact with PostHog (EU region) — install SDKs, query events, manage feature flags, run experiments, inspect insights. Use when user wants to track events, add analytics, create/toggle a feature flag, set up an A/B test, query product data, or wire PostHog into a TanStack Start app.
category: analytics
argument-hint: [install | flag <list|get|create|toggle> | experiment <list|get> | query <hogql> | event <recent>] [--project <id>]
allowed-tools: Bash(curl *) Bash(jq *) Bash(pnpm *) Read Write Edit
---

# PostHog

CLI-first PostHog ops via the public API (EU region, `eu.posthog.com`). Covers SDK install, feature flags, experiments, event queries, and HogQL.

## Usage

```
/ro:posthog install [--react|--node|--both]    # wire SDK into current app
/ro:posthog flag list                          # list all feature flags
/ro:posthog flag get <key>
/ro:posthog flag create <key> --rollout 50     # new boolean flag at 50%
/ro:posthog flag toggle <key>                  # enable/disable
/ro:posthog experiment list
/ro:posthog experiment get <id>
/ro:posthog query "SELECT event, count() FROM events GROUP BY event LIMIT 20"
/ro:posthog event recent [--event <name>]      # tail recent events
```

## Prerequisites

- Keys in `~/.claude/.env`:
  - `POSTHOG_PERSONAL_API_KEY` — all-access, for management API
  - `POSTHOG_HOST=https://eu.posthog.com` — management API host
  - `POSTHOG_INGEST_HOST=https://eu.i.posthog.com` — SDK ingest host
- `--project <id>` or `POSTHOG_PROJECT_ID` env var (numeric — look up via `list projects` below)

## Install — SDK wiring

### React (TanStack Start client)

```bash
pnpm add posthog-js
```

Create `src/lib/posthog.ts`:

```ts
import posthog from "posthog-js";

if (typeof window !== "undefined") {
  posthog.init(import.meta.env.VITE_POSTHOG_PROJECT_API_KEY, {
    api_host: import.meta.env.VITE_POSTHOG_INGEST_HOST,
    person_profiles: "identified_only",
  });
}

export { posthog };
```

Expose in Vite env (`.dev.vars`):

```
VITE_POSTHOG_PROJECT_API_KEY=phc_...
VITE_POSTHOG_INGEST_HOST=https://eu.i.posthog.com
```

The **project API key** (`phc_...`, NOT the personal key) lives per-app — generate at `https://eu.posthog.com/project/<id>/settings`.

### Node / Server Functions (TanStack Start server)

```bash
pnpm add posthog-node
```

```ts
// src/lib/posthog-server.ts
import { PostHog } from "posthog-node";

export const posthog = new PostHog(process.env.POSTHOG_PROJECT_API_KEY!, {
  host: process.env.POSTHOG_INGEST_HOST ?? "https://eu.i.posthog.com",
});
```

Important: call `await posthog.shutdown()` at the end of each server function (Workers terminates quickly; unflushed events are lost).

## Feature flags (management API)

All calls go to `${POSTHOG_HOST}/api/projects/<project-id>/feature_flags/` with `Authorization: Bearer ${POSTHOG_PERSONAL_API_KEY}`.

### List

```bash
curl -s "${POSTHOG_HOST}/api/projects/${PROJECT_ID}/feature_flags/" \
  -H "Authorization: Bearer ${POSTHOG_PERSONAL_API_KEY}" \
  | jq '.results[] | {key, active, rollout_percentage: .filters.groups[0].rollout_percentage}'
```

### Create boolean flag at N% rollout

```bash
curl -s -X POST "${POSTHOG_HOST}/api/projects/${PROJECT_ID}/feature_flags/" \
  -H "Authorization: Bearer ${POSTHOG_PERSONAL_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "key": "new-checkout",
    "name": "New checkout flow",
    "active": true,
    "filters": { "groups": [{ "properties": [], "rollout_percentage": 50 }] }
  }'
```

### Toggle

```bash
# First GET to find the id, then PATCH:
curl -s -X PATCH "${POSTHOG_HOST}/api/projects/${PROJECT_ID}/feature_flags/${FLAG_ID}/" \
  -H "Authorization: Bearer ${POSTHOG_PERSONAL_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"active": false}'
```

### Multivariate / experiment flag

Pass variants in `filters.multivariate.variants`. See experiments below.

## Experiments (A/B tests)

```bash
curl -s "${POSTHOG_HOST}/api/projects/${PROJECT_ID}/experiments/" \
  -H "Authorization: Bearer ${POSTHOG_PERSONAL_API_KEY}" \
  | jq '.results[] | {name, feature_flag_key, start_date, end_date, parameters}'
```

Creating via API is possible but the dashboard is cleaner for setup; use API for **monitoring** (win probability, conversion deltas).

## HogQL queries

PostHog's SQL-like layer over events:

```bash
curl -s -X POST "${POSTHOG_HOST}/api/projects/${PROJECT_ID}/query/" \
  -H "Authorization: Bearer ${POSTHOG_PERSONAL_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "query": {
      "kind": "HogQLQuery",
      "query": "SELECT event, count() FROM events WHERE timestamp > now() - INTERVAL 24 HOUR GROUP BY event ORDER BY count() DESC LIMIT 20"
    }
  }' | jq '.results'
```

## Recent events (sanity check ingest)

```bash
curl -s "${POSTHOG_HOST}/api/projects/${PROJECT_ID}/events/?limit=10" \
  -H "Authorization: Bearer ${POSTHOG_PERSONAL_API_KEY}" \
  | jq '.results[] | {event, timestamp, distinct_id, properties: (.properties | {"$current_url", "$lib"})}'
```

## List projects (find your project ID)

```bash
curl -s "${POSTHOG_HOST}/api/projects/" \
  -H "Authorization: Bearer ${POSTHOG_PERSONAL_API_KEY}" \
  | jq '.results[] | {id, name, organization}'
```

## Env var summary

**Global (`~/.claude/.env`)**:
- `POSTHOG_PERSONAL_API_KEY` — for this skill's management calls
- `POSTHOG_SIMPLICITY_LABS_API_KEY` — org-scoped, can substitute for some ops
- `POSTHOG_HOST` — `https://eu.posthog.com`
- `POSTHOG_INGEST_HOST` — `https://eu.i.posthog.com`

**Per-app** (`.dev.vars` + wrangler secret):
- `POSTHOG_PROJECT_API_KEY` (`phc_...`) — client-side SDK init
- Also exposed to Vite as `VITE_POSTHOG_PROJECT_API_KEY` + `VITE_POSTHOG_INGEST_HOST`

## EU region note

Ronan's org is on the EU region. **Do not** use `us.posthog.com` or `app.posthog.com` — they'll 401. The skill hard-codes EU hosts in env for this reason.

## Safety

- Never expose `POSTHOG_PERSONAL_API_KEY` client-side. The client SDK only needs the project API key (`phc_...`), which is safe to ship.
- Flag creation / deletion is destructive for users in an active experiment — confirm with user before toggling a flag that's wired to a running experiment.
- `DELETE` on a flag cannot be undone from the API. Prefer `active: false` over delete.

## See also

- `/ro:sentry` — the other half of observability
- `/ro:new-tanstack-app` — scaffolds with posthog slot ready
- PostHog API docs: https://posthog.com/docs/api — use context7
