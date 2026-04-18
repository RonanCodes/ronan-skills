---
name: migrate-to-tanstack
description: Migrate an existing web app to the canonical TanStack Start + Drizzle + D1 + Cloudflare Workers stack. Use when user wants to migrate, port, move, rewrite, or convert an app to TanStack Start — from Next.js, Vite+Hono, Remix, Nuxt, Express, Fly.io, Vercel, or any other stack.
category: project-setup
argument-hint: [--strategy branch|parallel|fresh] [--keep-data]
allowed-tools: Bash(pnpm *) Bash(pnpx *) Bash(wrangler *) Bash(git *) Bash(grep *) Bash(jq *) Bash(find *) Read Write Edit Glob Grep
---

# Migrate To TanStack

Port an existing app to **TanStack Start + Drizzle + D1 + Cloudflare Workers**. Different shape from `new-tanstack-app`: audit first, port incrementally, cut over last.

## Usage

```
/ro:migrate-to-tanstack                         # ask strategy, run audit
/ro:migrate-to-tanstack --strategy branch       # migrate in a branch of current repo
/ro:migrate-to-tanstack --strategy parallel     # create a sibling directory
/ro:migrate-to-tanstack --strategy fresh        # brand new repo, port source in
/ro:migrate-to-tanstack --keep-data             # plan data migration, not just schema
```

## Process

### 1. Audit (never skip)

Report current stack before touching anything. Probe these files in parallel:

- `package.json` — framework (`next`, `@remix-run`, `vite`, `nuxt`, `@tanstack/start`, `hono`, `express`), ORM (`prisma`, `drizzle-orm`, `@neondatabase/serverless`, raw `pg`/`better-sqlite3`), auth (`better-auth`, `@clerk/*`, `next-auth`, `@auth/core`, `lucia`)
- `fly.toml` / `vercel.json` / `netlify.toml` / `wrangler.toml` — deploy target
- `.env*` files — current secrets surface (don't print values, just keys)
- `prisma/schema.prisma`, `db/schema.ts`, `drizzle.config.ts` — schema source
- `src/routes/` vs `pages/` vs `app/` — routing convention
- `tsconfig.json` — strict flags already set?

Produce an audit report:

```
Current stack:
  Framework:  <e.g. Vite + Hono>
  Routing:    <file-based / programmatic>
  ORM:        <Drizzle / Prisma / raw>
  DB:         <SQLite-on-disk / Postgres / D1>
  Auth:       <Clerk / NextAuth / Better Auth / rolled-own>
  Deploy:     <Fly / Vercel / Cloudflare / other>
  LOC:        <routes>, <components>, <server>
  Tests:      <Vitest / Jest / Playwright / none>
```

### 2. Strategy decision

If `--strategy` wasn't given, ask the user via AskUserQuestion:

- **branch** — migrate in a new branch of the current repo. Good when git history matters and you want PRs per-step.
- **parallel** — create a sibling directory `../<app>-tanstack`, port source in, cut over by renaming dirs. Good when the old stack must keep running during migration.
- **fresh** — brand new repo. Good when the rewrite is significant enough that history is noise.

Tag the current state before any changes:

```bash
git tag pre-tanstack-migration && git push --tags
```

### 3. Scaffold target

Delegate to `/ro:new-tanstack-app <app-name> --skip-deploy` for the skeleton. This gives you `wrangler.toml`, Drizzle, Zod, shadcn, hygiene config, testing setup — all in the target location.

### 4. Port schema first

- **Already Drizzle** — copy `db/schema.ts` as-is, swap `dialect` to `'sqlite'` if moving from Postgres (note: review JSONB, array columns, Postgres-specific types — SQLite uses TEXT for JSON).
- **Prisma** — convert `schema.prisma` to Drizzle manually (or use `prisma-to-drizzle`). Keep naming identical so queries port 1:1 later.
- **Raw SQL migrations** — write Drizzle schema matching final state; generate a baseline migration.

Run `pnpm drizzle-kit generate` + `wrangler d1 migrations apply --local` to verify the schema builds against D1.

### 5. Port server logic

Map source → target:

| From | To |
|---|---|
| Next.js API route (`app/api/*/route.ts`) | TanStack Server Route (`src/routes/api/*.ts`) |
| Next.js RSC / action | TanStack Server Function (`createServerFn`) |
| Hono route (`app.get('/x', ...)`) | Server Route with method handlers |
| Express route | Server Route (hand-port the handler body) |
| Remix loader / action | Server Function or Server Route |

Port one surface at a time. After each, run the test suite against it.

### 6. Port UI

- **React** (Next/Vite/Remix) — components mostly port as-is. Swap router imports (`next/link` → `@tanstack/react-router`). Move data-fetching out of RSC/loaders into TanStack Router `loader`/`beforeLoad` or server functions.
- **Vue/Svelte/Solid** — rewrite in React. Not a port; budget accordingly.
- **shadcn components** — already there from step 3. Re-add any extras the old app used: `pnpm dlx shadcn@latest add <comp>`.

### 7. Port auth

- **Clerk / NextAuth / Auth0** → **Better Auth**. User records can be imported (Better Auth has an import script). Session tokens do NOT transfer — users get signed out on cutover; plan comms.
- **Already Better Auth** — copy `lib/auth.ts`, re-mount at `src/routes/api/auth/$.ts`.

Delegate to `/ro:better-auth` if that skill exists; otherwise inline the wiring.

### 8. Data migration (only if `--keep-data`)

Strategy by source DB:

- **SQLite-on-disk** → D1: `sqlite3 db.sqlite .dump > dump.sql`, clean Postgres-isms if any, `wrangler d1 execute <db> --remote --file=dump.sql`.
- **Postgres** → D1: dump with `pg_dump --data-only --column-inserts`, rewrite type-incompatible inserts (UUIDs → TEXT, JSONB → JSON string, timestamps → integer ms), apply via `wrangler d1 execute --file`.
- **Postgres** → Neon (keeping Postgres): `pg_dump | psql` against the new Neon URL. Simpler path if schema leans on Postgres features.

Always dry-run against `--local` D1 first.

### 9. Cut over

In order:

1. Deploy target via `/ro:cf-ship`
2. Push secrets to the Worker (`wrangler secret put` each one)
3. Smoke-check new URL
4. Swap DNS to point domain at the new Worker (use `/ro:cloudflare-dns`)
5. Monitor old + new in parallel for 24–48h
6. Decommission old stack (Fly: `flyctl apps destroy`; Vercel: delete project) **only after** confirming the new one is stable

### 10. Report

Summarise: strategy used, current state, what's ported, what's left, rollback command (`git reset --hard pre-tanstack-migration` or DNS swap back).

## Safety

- NEVER delete old stack until user confirms new one is live and stable
- Tag pre-migration state before any destructive action
- Data migration: always dry-run locally first
- DNS cutover: lower TTL 24h in advance to shorten rollback window

## Learnings from real migrations

Hard-won patterns — read before skipping.

### Pre-migration state: tag AND branch

`git tag pre-tanstack-migration` alone is enough for rollback, but GitHub's branch-compare UI only works for branches. Also create `git branch pre-tanstack-migration pre-tanstack-migration && git push origin pre-tanstack-migration` — future-you will want to diff the migration in GitHub without cloning.

### Observability keys: runtime injection, not `VITE_*`

Default TanStack scaffolds hard-code `VITE_SENTRY_DSN` and `VITE_POSTHOG_PROJECT_API_KEY` into the bundle at build time. For a public-facing app, prefer runtime injection:

1. Store keys as Cloudflare Worker `vars` in `wrangler.jsonc` (public by design — Sentry DSNs and PostHog `phc_` keys ship to browsers)
2. Add `src/routes/api/config.ts` that returns `{ sentryDsn, posthogKey, posthogHost }` from `env`
3. Add `src/lib/runtime-config.ts` with a memoised client-side `fetch('/api/config')`
4. Rewrite `initSentry()` / `initPostHog()` as async, read from runtime-config, no-op if keys are empty

Trade-off: first paint does one extra fetch before analytics init. Benefits: keys rotate without rebuild, CI builds without secrets, forks don't ship your keys. Document in ARCHITECTURE.md.

### `wrangler types` and `no-unnecessary-condition`

If `wrangler.jsonc` has `vars` with string defaults (`"SENTRY_DSN": ""`), `wrangler types` generates **literal** types (`SENTRY_DSN: ""`). Subsequent `env.SENTRY_DSN ?? ''` becomes a lint error (TS knows it's always truthy/always empty-string). Fix: use the env value directly, no fallback — the Worker's runtime `vars` will override the default at deploy time anyway.

Add `worker-configuration.d.ts` to the eslint `ignores` list — it's autogenerated and full of benign patterns that trip strict rules.

### Vitest + Cloudflare Vite plugin = cryptic startup error

If you don't have a dedicated `vitest.config.ts`, vitest loads `vite.config.ts` which pulls in `@cloudflare/vite-plugin` → startup fails with `TypeError: require_react is not a function` from the workers runner pool. Fix: create a minimal `vitest.config.ts` with `environment: 'jsdom'` and `passWithNoTests: true`. Do NOT share vite.config.

### One `quality` script, one CI step

Collapse the local quality gate into a single script:

```json
"quality": "pnpm run format && pnpm run lint && pnpm run build && pnpm run test"
```

CI runs the same script — no drift between local and CI. `pnpm test:e2e` and integration tests stay separate (they need a running server).

### Custom domain: pre-delete conflicting DNS

When attaching a Worker to a domain that previously pointed at another host (Fly, Vercel, etc.), `PUT /accounts/:id/workers/domains` fails with error 10007 "Hostname already has externally managed DNS records". `override_existing_dns_record: true` does NOT reliably work. Fix: DELETE the old A/AAAA records first, THEN attach the Worker domain.

### `workers.dev` subdomain rename is dashboard-only

The default `<account>-<slug>.workers.dev` hostname can only be renamed via the Cloudflare dashboard, not the API. When running `wrangler deploy` for the first time, the account's `workers.dev` subdomain is auto-chosen from the account name — pick the account alias carefully before the first deploy if you care about the URL.

### Push-to-main auto-deploy gated on tests

```yaml
deploy:
  needs: test
  if: github.ref == 'refs/heads/main' && github.event_name == 'push'
  environment: production
  concurrency: { group: deploy-production, cancel-in-progress: false }
```

`needs: test` is the gate. `cancel-in-progress: false` on deploy prevents a second push from cancelling a deploy mid-flight. Pass observability secrets via `wrangler deploy --var KEY:"$KEY"` — reads from GitHub Actions secrets, never written to the bundle.

### Ported routes: TanStack's `server.handlers`

Hono's `app.get('/x', h)` → `createFileRoute('/api/x')({ server: { handlers: { GET: h } } })`. Note: Cloudflare bindings come from `import { env } from 'cloudflare:workers'` — there's no `c.env` equivalent in handlers. Hand-port the body; don't try to share code between the two shapes.

## See also

- `/ro:new-tanstack-app` — the scaffold this skill invokes
- `/ro:cf-ship` — ships the migrated app
- `/ro:cloudflare-dns` — DNS cutover
- `/ro:commit` — per-step commits during porting
