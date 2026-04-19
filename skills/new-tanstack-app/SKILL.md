---
name: new-tanstack-app
description: Orchestrate scaffolding a new TanStack Start app on the canonical stack (TanStack Start + Drizzle + Cloudflare Workers + shadcn/ui). Dispatches to sub-skills for DB (D1 / Neon), auth (Better Auth), observability (PostHog, Sentry, UptimeRobot), DNS, and ship. Use when user wants to start, create, scaffold, bootstrap, or kick off a new TanStack Start project / small app / side project.
category: project-setup
argument-hint: <app-name> [--db d1|neon] [--auth] [--posthog] [--sentry] [--uptime] [--domain <host>] [--skip-deploy] [--skip-ci] [--interactive]
allowed-tools: Bash(pnpm *) Bash(pnpx *) Bash(wrangler *) Bash(git *) Bash(corepack *) Bash(mkdir *) Bash(cd *) Bash(cp *) Read Write Edit
---

# New TanStack App (orchestrator)

Scaffold a new TanStack Start app, then dispatch to sub-skills for the pieces the user wants. Target: $0/mo at small scale, one evening to a working deploy.

## Usage

```
/ro:new-tanstack-app my-app                              # baseline: D1, no auth, no observability, deploy
/ro:new-tanstack-app my-app --interactive                # asks what to wire (uses AskUserQuestion)
/ro:new-tanstack-app my-app --db neon                    # Postgres via Neon instead of D1
/ro:new-tanstack-app my-app --auth                       # + Better Auth
/ro:new-tanstack-app my-app --posthog --sentry --uptime  # + full observability
/ro:new-tanstack-app my-app --domain api.ronan.dev       # + custom domain via /ro:cloudflare-dns
/ro:new-tanstack-app my-app --skip-deploy                # scaffold only, no D1 / no deploy
/ro:new-tanstack-app my-app --db neon --auth --posthog --sentry --uptime --domain app.ronan.dev  # everything
```

## What it actually does

This skill is an **orchestrator** — it owns the baseline scaffolding (scaffold / UI / testing / hygiene) and delegates everything else to sibling skills. That keeps each piece evolvable on its own.

```
/ro:new-tanstack-app <app> [flags]
  1. scaffold + CF adapter + wrangler binding            (inline)
  2. DB wiring:
       --db d1 (default)  → inline D1 wiring
       --db neon          → /ro:neon install + project + push-secret
  3. UI: tailwind + shadcn + lucide                       (inline)
  4. Testing: vitest + playwright + bruno dirs            (inline)
  5. Code hygiene: prettier + eslint + husky + commitlint (inline)
  6. --auth      → /ro:better-auth install
  7. --posthog   → /ro:posthog install --both
  8. --sentry    → /ro:sentry install --tanstack + project create
  9. --uptime    → /ro:uptimerobot monitor create          (post-deploy)
 10. --domain    → /ro:cloudflare-dns add <host>           (post-deploy)
 11. deploy      → /ro:cf-ship                             (unless --skip-deploy)
 12. GitHub CI  → add .github/workflows/ci.yml            (quality gate + auto-deploy)
 13. final commit → /ro:commit                             (emoji format)
```

## Prerequisites

- Node 20+
- `pnpm` (install: `corepack enable pnpm`)
- `wrangler` 4.x — `pnpm add -g wrangler` (skill checks and offers to install)
- `CLOUDFLARE_API_TOKEN` in `~/.claude/.env` with Workers Scripts + D1 + Account Settings + Zone DNS scopes
- Git configured
- For optional flags, the corresponding env vars must be set (skill checks):
  - `--db neon` → `NEON_API_KEY`
  - `--posthog` → `POSTHOG_PERSONAL_API_KEY`, `POSTHOG_HOST`, `POSTHOG_INGEST_HOST`
  - `--sentry` → `SENTRY_AUTH_TOKEN`, `SENTRY_ORG`, `SENTRY_REGION_URL`
  - `--uptime` → `UPTIMEROBOT_API_KEY`
  - `--domain` → `CLOUDFLARE_API_TOKEN` with `Zone:DNS:Edit`

## Interactive mode (`--interactive`)

Runs an `AskUserQuestion` preamble to collect:

1. **Database** — D1 (SQLite, default) or Neon (Postgres)?
2. **Auth** — Better Auth or none?
3. **Observability** — Which of [PostHog, Sentry, UptimeRobot]?
4. **Custom domain** — `<host>` or skip?
5. **Deploy now** — yes (via `/ro:cf-ship`) or scaffold-only?

Answers are converted to flags and the non-interactive flow proceeds. Use this as the default when a user invokes without flags AND without `--skip-interactive`.

## Process

### 1. Baseline scaffold (always)

```bash
pnpm create tsrouter-app@latest <app-name> --template start
cd <app-name>
pnpm install
git init && git add -A && git commit -m "🧹 chore: scaffold tanstack start"
```

### 2. Wire Cloudflare adapter (always)

```bash
pnpm add -D @cloudflare/workers-types wrangler
```

Set `app.config.ts` → `preset: 'cloudflare-module'`. Create `wrangler.toml` with app name + compatibility date.

### 3. Database — dispatch

- **D1 (default)**: inline wiring. Add `[[d1_databases]]` binding in `wrangler.toml`, then `wrangler d1 create <app-name>_db`, patch `database_id`. Install `drizzle-orm` + `drizzle-kit` with `dialect: 'sqlite'`, `driver: 'd1-http'`.
- **`--db neon`**: `/ro:neon install` wires Drizzle + `@neondatabase/serverless` with `drizzle-orm/neon-http`. Then `/ro:neon project create <app-name>` and `/ro:neon push-secret` to write `DATABASE_URL` as a wrangler secret.

Either way, create `src/db/schema.ts` with a minimal example table.

### 4. UI stack (always)

```bash
pnpm add -D tailwindcss @tailwindcss/vite
pnpm add lucide-react
pnpm dlx shadcn@latest init
pnpm dlx shadcn@latest add button dialog input form
```

Add `@tailwindcss/vite` plugin. Add `@import "tailwindcss";` to the root CSS.

### 5. Testing (always)

```bash
pnpm add -D vitest @testing-library/react @testing-library/jest-dom jsdom
pnpm add -D @playwright/test
pnpm dlx playwright install
```

Configs for Vitest + Playwright. Create `e2e/` with a placeholder spec. Create `bruno/` directory for API contract tests.

### 6. Code hygiene (always)

```bash
pnpm add -D prettier eslint typescript \
  @typescript-eslint/parser @typescript-eslint/eslint-plugin \
  eslint-config-prettier prettier-plugin-tailwindcss \
  husky lint-staged \
  @commitlint/cli @commitlint/config-conventional
pnpm dlx husky init
```

- `.prettierrc.json`, flat `eslint.config.js` with `strictTypeChecked` + `prettier` last
- `tsconfig.json` strict (`strict`, `noUncheckedIndexedAccess`, `exactOptionalPropertyTypes`)
- `lint-staged` block in `package.json`
- `.husky/pre-commit` (`pnpm lint-staged`) and `.husky/commit-msg` (`pnpm commitlint --edit $1`)
- `commitlint.config.js` enforcing the **emoji + conventional** format (✨ feat / 🐛 fix / 🧪 test / 📝 docs / 🧹 chore / ♻️ refactor / 🚀 deploy / 🔧 config / ⚡ perf / 🔒 security)

### 7. `--auth` → `/ro:better-auth install`

Delegate to `/ro:better-auth install`. Afterwards:
- Remind user: `BETTER_AUTH_SECRET` generated via `openssl rand -base64 32` lives in `.dev.vars` + `wrangler secret put` — NOT in `~/.claude/.env`.

### 8. `--posthog` → `/ro:posthog install --both`

Delegate. Client + server SDK. For public-facing apps, prefer **runtime config injection** over `VITE_*` (see "Runtime-injected observability" below) — the key still ships to browsers either way, but runtime injection means forks don't ship your key and rotations don't need a rebuild.

### 9. `--sentry` → `/ro:sentry install --tanstack` + `project create`

Delegate install. Then `/ro:sentry project create <app-slug> --platform javascript-react` creates a Sentry project and returns the DSN. For public-facing apps, prefer **runtime config injection** (see below) over `VITE_SENTRY_DSN`.

### Runtime-injected observability (recommended default)

Instead of baking Sentry DSN + PostHog key into the bundle via `VITE_*` vars, store them as Cloudflare Worker `vars` and expose them via an `/api/config` endpoint the client fetches on load. Scaffold:

- `wrangler.jsonc` → `vars: { SENTRY_DSN: "", POSTHOG_PROJECT_KEY: "", POSTHOG_INGEST_HOST: "https://eu.i.posthog.com" }`
- `src/routes/api/config.ts` → GET returns `{ sentryDsn, posthogKey, posthogHost }` from `env`
- `src/lib/runtime-config.ts` → memoised client-side `fetch('/api/config')`
- `initSentry()` / `initPostHog()` are **async**, read from runtime-config, no-op if keys are empty

Benefits: keys rotate without rebuilds, CI builds without observability secrets, forks don't ship your keys. Cost: one extra fetch before analytics init (fine for non-critical-path analytics). Document the flow in `ARCHITECTURE.md`.

### 10. `--uptime` → `/ro:uptimerobot monitor create` (post-deploy)

Deferred to post-deploy — needs the Worker URL first. After `/ro:cf-ship` prints the URL:

```
/ro:uptimerobot monitor create <worker-url> --name "<app-name>"
```

### 11. `--domain <host>` → `/ro:cloudflare-dns` (post-deploy)

Deferred to post-deploy. After the Worker is live:
- Add custom domain binding via `wrangler.toml` → `routes` or `wrangler custom-domains add`
- `/ro:cloudflare-dns add <host>` adds a CNAME to the Worker (proxied/orange-cloud)

### 12. Deploy — `/ro:cf-ship` (always, unless `--skip-deploy`)

Run `/ro:cf-ship` for the full pre-flight gate: typecheck, lint, format, test, D1 migrations, secrets diff, build, deploy, smoke check. This replaces the inline `wrangler deploy` from the old version of this skill — the pre-flight gate is a big value-add and shouldn't be duplicated.

### 13. GitHub CI + auto-deploy (always, unless `--skip-ci`)

Every app ships with CI from day one. Two jobs: a `test` job that runs on every push and PR (format + lint + build + test, collapsed into a single `pnpm quality` script), and a `deploy` job that runs only on push to main, gated on `test`, deploying to Cloudflare with secrets from the `production` environment.

Create `.github/workflows/ci.yml`:

```yaml
name: CI
on:
  push: { branches: [main] }
  pull_request:
concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true
jobs:
  test:
    name: Quality checks (format + lint + build + test)
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v4
        with: { version: 9 }
      - uses: actions/setup-node@v4
        with: { node-version: 22, cache: pnpm }
      - run: pnpm install --frozen-lockfile
      - run: pnpm quality
  deploy:
    name: Deploy to Cloudflare Workers
    needs: test
    if: github.ref == 'refs/heads/main' && github.event_name == 'push'
    runs-on: ubuntu-latest
    environment: production
    concurrency:
      group: deploy-production
      cancel-in-progress: false
    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v4
        with: { version: 9 }
      - uses: actions/setup-node@v4
        with: { node-version: 22, cache: pnpm }
      - run: pnpm install --frozen-lockfile
      - run: pnpm build
      - name: Apply D1 migrations
        run: pnpm wrangler d1 migrations apply <db-name> --remote
        env:
          CLOUDFLARE_API_TOKEN: ${{ secrets.CLOUDFLARE_API_TOKEN }}
          CLOUDFLARE_ACCOUNT_ID: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
      - name: Deploy worker
        run: pnpm wrangler deploy
        env:
          CLOUDFLARE_API_TOKEN: ${{ secrets.CLOUDFLARE_API_TOKEN }}
          CLOUDFLARE_ACCOUNT_ID: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
```

If `--posthog` / `--sentry` are set, add `--var` flags to the `wrangler deploy` step (reading from `secrets.SENTRY_DSN` and `secrets.POSTHOG_PROJECT_KEY`), matching the runtime-config pattern from step 8-9.

Add a collapsing `quality` script to `package.json` so local + CI share one command:

```json
"scripts": {
  "quality": "pnpm run format && pnpm run lint && pnpm run build && pnpm run test"
}
```

Push secrets to the `production` environment (needs a `gh` token with `repo` scope and admin on the environment — if it 401s, run `gh auth refresh -h github.com -s admin:repo_hook` and pass `--repo <owner>/<name>` explicitly):

```bash
gh secret set CLOUDFLARE_API_TOKEN --env production --repo <owner>/<repo> --body "$CLOUDFLARE_API_TOKEN"
gh secret set CLOUDFLARE_ACCOUNT_ID --env production --repo <owner>/<repo> --body "$CLOUDFLARE_ACCOUNT_ID"
# observability (if wired):
gh secret set SENTRY_DSN --env production --repo <owner>/<repo> --body "$SENTRY_DSN"
gh secret set POSTHOG_PROJECT_KEY --env production --repo <owner>/<repo> --body "$POSTHOG_PROJECT_KEY"
```

Why `environment: production` and not repo-level secrets: preview branches / PRs never see the deploy token. Required status checks can gate deploys per-environment. Audit log shows which env a secret was used in.

Skip with `--skip-ci` if (and only if) the user explicitly doesn't want CI. Default is on.

### 14. Final commit — `/ro:commit`

Delegate to `/ro:commit` so the emoji format and weekday-timestamp rule are enforced.

## Output summary

Print the following after everything runs:

- App name + directory
- DB: D1 database ID, OR Neon project ID + branch
- Auth: enabled / disabled
- Observability wired: PostHog flag, Sentry project slug + DSN source, UptimeRobot monitor ID
- Deployed URL + custom domain (if `--domain`)
- Next-step suggestions: add more shadcn components, write first Server Function, `pnpm dev`

## Safety

- Every sub-skill has its own safety rules — this orchestrator does not override them.
- If a sub-skill's required env var is missing, skill fails fast at the top with "Missing: X. Add to `~/.claude/.env`" — does NOT attempt partial setup.
- `--skip-deploy` implies `--uptime` and `--domain` are also skipped (they're post-deploy).
- If `wrangler whoami` shows an insufficient-scope token, skill fails fast before any `wrangler d1 create` / `wrangler deploy` call.

## Anti-patterns it guards against

- Inlining sub-skill logic here (drifts from the sub-skill's source of truth)
- Silently continuing when a sub-skill fails (bad state + partial deploy)
- Assuming a token has full Workers scope without verifying
- Using TCP drivers for Postgres inside Workers (Neon HTTP driver only — enforced by `/ro:neon`)

## See also

- `/ro:migrate-to-tanstack` — port an existing app to this stack (the migration sibling)
- `/ro:neon` — Postgres wiring
- `/ro:better-auth`, `/ro:posthog`, `/ro:sentry`, `/ro:uptimerobot`, `/ro:cloudflare-dns`
- `/ro:cf-ship` — the deploy pipeline
- `/ro:commit` — emoji conventional commits
