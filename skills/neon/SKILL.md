---
name: neon
description: Manage Neon serverless Postgres — create project, branches (incl. per-PR preview), wire Drizzle + Neon HTTP driver for Cloudflare Workers, set DATABASE_URL via wrangler secret. Use when user wants Postgres (not SQLite/D1) — needs pgvector / PostGIS / JSONB / preview DB branches / strict types, or when wiring Neon into a TanStack Start + CF Workers app.
category: database
argument-hint: [install | project <list|create> | branch <list|create|delete> | push-secret] [--project <id>] [--branch <name>]
allowed-tools: Bash(curl *) Bash(jq *) Bash(pnpm *) Bash(wrangler *) Read Write Edit
---

# Neon

CLI-first Neon ops via the public API. Covers project/branch management and Drizzle + Neon HTTP driver wiring for TanStack Start on Cloudflare Workers. Chosen because CF Workers does not have native Postgres — Neon's HTTP driver (no TCP) is the idiomatic fit.

## Usage

```
/ro:neon install                               # wire Drizzle + @neondatabase/serverless into current app
/ro:neon project list
/ro:neon project create <name>                 # creates project + default "main" branch, prints DATABASE_URL
/ro:neon branch list --project <id>
/ro:neon branch create <name> --project <id>   # e.g. "preview-pr-42"
/ro:neon branch delete <name> --project <id>
/ro:neon push-secret --project <id> --branch main   # write DATABASE_URL to current app's wrangler secret
```

## Prerequisites

- `NEON_API_KEY` in `~/.claude/.env` — create at https://console.neon.tech/app/settings/api-keys
- For `push-secret`: a TanStack Start app with `wrangler.toml` in the cwd

## When to choose Neon over D1

| Need | Use |
|---|---|
| Default — simple CRUD, SQLite is enough, zero ops | **D1** |
| pgvector (embeddings, RAG), PostGIS, JSONB ops, window funcs | **Neon** |
| Preview DB per PR / feature branch | **Neon** (free-tier branches are cheap, copy-on-write) |
| Strict types (`CHECK`, `DOMAIN`), PL/pgSQL | **Neon** |
| Multi-region reads | **Neon** (read replicas) |

## Install — wire into TanStack Start

### 1. Install dependencies

```bash
pnpm add @neondatabase/serverless drizzle-orm
pnpm add -D drizzle-kit
```

### 2. Drizzle config

`drizzle.config.ts`:

```ts
import { defineConfig } from "drizzle-kit";

export default defineConfig({
  schema: "./src/db/schema.ts",
  out: "./drizzle",
  dialect: "postgresql",
  dbCredentials: { url: process.env.DATABASE_URL! },
});
```

### 3. DB client — `src/db/index.ts`

```ts
import { neon } from "@neondatabase/serverless";
import { drizzle } from "drizzle-orm/neon-http";
import * as schema from "./schema";

export function createDb(env: { DATABASE_URL: string }) {
  const sql = neon(env.DATABASE_URL);
  return drizzle(sql, { schema });
}
```

The Neon HTTP driver works inside Workers because it uses fetch() — no TCP. **Do not** use `@neondatabase/serverless`'s `Pool` / `Client` classes in Workers; only `neon()` + drizzle-orm/neon-http.

### 4. Schema — `src/db/schema.ts`

```ts
import { pgTable, serial, text, timestamp } from "drizzle-orm/pg-core";

export const users = pgTable("users", {
  id: serial("id").primaryKey(),
  email: text("email").notNull().unique(),
  createdAt: timestamp("created_at").defaultNow().notNull(),
});
```

(Note: `pg-core`, not `sqlite-core` — this is the key diff vs a D1 app.)

### 5. Wrangler binding

`wrangler.toml`:

```toml
# DATABASE_URL is a secret, not a binding — do NOT put it here
# Set via: wrangler secret put DATABASE_URL
```

Access in Server Routes / Server Functions via `env.DATABASE_URL` (Workers env), or `process.env.DATABASE_URL` (local dev via `.dev.vars`).

### 6. Local dev

`.dev.vars`:

```
DATABASE_URL=postgresql://user:pass@ep-xyz.eu-central-1.aws.neon.tech/main?sslmode=require
```

Then `wrangler dev` surfaces this as `env.DATABASE_URL`.

### 7. Migrations

```bash
pnpm drizzle-kit generate     # creates ./drizzle/*.sql
pnpm drizzle-kit migrate      # applies against DATABASE_URL
```

For prod: apply against the prod branch's DATABASE_URL before `wrangler deploy`.

## Project management

All calls go to `https://console.neon.tech/api/v2/` with `Authorization: Bearer ${NEON_API_KEY}`.

### Find your org ID (do this once, cache it)

Newer Neon accounts require `org_id` for the projects endpoint. Find it first:

```bash
curl -s "https://console.neon.tech/api/v2/users/me/organizations" \
  -H "Authorization: Bearer ${NEON_API_KEY}" \
  | jq '.organizations[] | {id, name, plan}'
```

Export as `NEON_ORG_ID` in the session or per-app env.

### List projects (org-scoped)

```bash
curl -s "https://console.neon.tech/api/v2/projects?org_id=${NEON_ORG_ID}" \
  -H "Authorization: Bearer ${NEON_API_KEY}" \
  | jq '.projects[] | {id, name, region_id, created_at, pg_version}'
```

**Gotcha:** calling `/projects` without `?org_id=` returns `{"code":"","message":"org_id is required, you can find it on your organization settings page"}` — skill always passes the org id.

### Create project

```bash
curl -s -X POST "https://console.neon.tech/api/v2/projects" \
  -H "Authorization: Bearer ${NEON_API_KEY}" \
  -H "Content-Type: application/json" \
  -d "{
    \"project\": {
      \"name\": \"my-app\",
      \"org_id\": \"${NEON_ORG_ID}\",
      \"region_id\": \"aws-eu-central-1\",
      \"pg_version\": 17
    }
  }" | jq '{id: .project.id, connection_uri: .connection_uris[0].connection_uri}'
```

`pg_version: 17` is the current Neon default — bump this as Neon adds majors.

Region IDs: `aws-eu-central-1` (Frankfurt), `aws-us-east-1` (Virginia), `aws-us-east-2` (Ohio), `aws-ap-southeast-1` (Singapore). Pick closest to your CF Workers primary region.

The `connection_uri` in the response is your `DATABASE_URL` — push it to wrangler (`push-secret` below).

## Branches (preview DB per PR)

Branches in Neon are copy-on-write snapshots — cheap, instant, free tier includes 10 branches per project.

### List

```bash
curl -s "https://console.neon.tech/api/v2/projects/${PROJECT_ID}/branches" \
  -H "Authorization: Bearer ${NEON_API_KEY}" \
  | jq '.branches[] | {id, name, primary, created_at, parent_id}'
```

### Create branch (typically off main, for a PR preview)

```bash
curl -s -X POST "https://console.neon.tech/api/v2/projects/${PROJECT_ID}/branches" \
  -H "Authorization: Bearer ${NEON_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"branch": {"name": "preview-pr-42"}, "endpoints": [{"type": "read_write"}]}' \
  | jq '{id: .branch.id, name: .branch.name, connection_uris: .connection_uris}'
```

### Delete

```bash
curl -s -X DELETE "https://console.neon.tech/api/v2/projects/${PROJECT_ID}/branches/${BRANCH_ID}" \
  -H "Authorization: Bearer ${NEON_API_KEY}"
```

**Skill always confirms before delete** — branches are not in a trash, deletion is immediate.

## push-secret — DATABASE_URL to wrangler

```bash
# Fetch the connection URI for the specified branch
CONN=$(curl -s "https://console.neon.tech/api/v2/projects/${PROJECT_ID}/connection_uri?branch_id=${BRANCH_ID}&database_name=neondb&role_name=neondb_owner" \
  -H "Authorization: Bearer ${NEON_API_KEY}" | jq -r '.uri')

# Push to wrangler (prompts for confirm)
echo "$CONN" | wrangler secret put DATABASE_URL
```

## Preview-per-PR workflow (advanced)

Wire into CI so each PR gets its own branch:

```yaml
# .github/workflows/pr-preview.yml
- name: Create preview DB branch
  run: |
    BRANCH_NAME="preview-pr-${{ github.event.pull_request.number }}"
    curl -X POST ".../projects/${{ secrets.NEON_PROJECT_ID }}/branches" \
      -H "Authorization: Bearer ${{ secrets.NEON_API_KEY }}" \
      -d "{\"branch\":{\"name\":\"$BRANCH_NAME\"},\"endpoints\":[{\"type\":\"read_write\"}]}"
- name: Run migrations against branch
- name: Deploy to Workers preview with branch DATABASE_URL
- name: On PR close — delete branch
```

## Env var summary

**Global (`~/.claude/.env`)**:
- `NEON_API_KEY` — this skill's management API

**Per-app** (`.dev.vars` + wrangler secret):
- `DATABASE_URL` — Neon connection URI for the current branch. Format: `postgresql://role:pass@ep-xyz.region.aws.neon.tech/dbname?sslmode=require`

## Why Neon HTTP driver, not TCP?

Cloudflare Workers don't support long-lived TCP sockets. The Neon HTTP driver makes each query a fetch() call, which works in the Workers runtime. For normal Postgres clients, you'd need Cloudflare **Hyperdrive** (their Postgres pooler), but the Neon HTTP driver skips the pooler — faster cold starts, simpler wiring.

## Safety

- Branch delete is immediate. Skill confirms.
- Project delete is catastrophic — this skill does NOT implement project delete. Do it in the dashboard with eyes open.
- `DATABASE_URL` is a secret. NEVER commit `.dev.vars`. NEVER put it in `wrangler.toml`. Always use `wrangler secret put`.
- Connection strings rotate on role reset — if auth suddenly fails in prod, check whether the role password was reset and re-run `push-secret`.

## See also

- `/ro:new-tanstack-app --db neon` — scaffolds with neon pre-wired (once orchestrator is built)
- `/ro:cf-ship` — ships after migrations are applied
- Neon API docs: https://api-docs.neon.tech — use context7 for current syntax
