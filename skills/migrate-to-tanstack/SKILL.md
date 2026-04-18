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

## See also

- `/ro:new-tanstack-app` — the scaffold this skill invokes
- `/ro:cf-ship` — ships the migrated app
- `/ro:cloudflare-dns` — DNS cutover
- `/ro:commit` — per-step commits during porting
