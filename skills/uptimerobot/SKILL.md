---
name: uptimerobot
description: Manage UptimeRobot monitors — create, list, pause, delete HTTP/keyword/port/ping monitors; set up alert contacts; fetch uptime stats. Use when user wants to add uptime monitoring, create a status check, pause a monitor, see uptime %, or wire a new deployed app into external monitoring.
category: observability
argument-hint: [monitor <list|create|pause|resume|delete>] [contact <list|create>] [account] [--readonly]
allowed-tools: Bash(curl *) Bash(jq *) Read Write Edit
---

# UptimeRobot

CLI-first UptimeRobot ops via the v2 API. Covers monitors, alert contacts, and account queries. Uses `UPTIMEROBOT_API_KEY` by default; `--readonly` switches to the read-only key.

## Usage

```
/ro:uptimerobot account                                  # account + monitor limit + usage
/ro:uptimerobot monitor list                             # all monitors with status + uptime ratio
/ro:uptimerobot monitor create https://app.com --name "My App"
/ro:uptimerobot monitor create https://api.com --name "API" --keyword "ok"
/ro:uptimerobot monitor pause <id>
/ro:uptimerobot monitor resume <id>
/ro:uptimerobot monitor delete <id>                      # irreversible — asks confirm
/ro:uptimerobot contact list
/ro:uptimerobot contact create --email you@x.com
/ro:uptimerobot monitor list --readonly                  # uses read-only key
```

## Prerequisites

- Keys in `~/.claude/.env`:
  - `UPTIMEROBOT_API_KEY` — main key, full CRUD
  - `UPTIMEROBOT_READONLY_API_KEY` — read-only (safe for dashboards, status pages)

Both verified working on 2026-04-19 against `api.uptimerobot.com/v2`.

## API shape

UptimeRobot v2 API uses **POST** for every call (GET is not supported). Responses are JSON when `format=json` is passed.

Base URL: `https://api.uptimerobot.com/v2`

## Account details

```bash
curl -s -X POST "https://api.uptimerobot.com/v2/getAccountDetails" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "api_key=${UPTIMEROBOT_API_KEY}&format=json" \
  | jq '.account | {email, monitor_limit, up_monitors, down_monitors, paused_monitors, total_monitors_count, registered_at}'
```

Ronan's account (2026-04-19): free tier, 50-monitor limit.

## Monitors

### List

```bash
curl -s -X POST "https://api.uptimerobot.com/v2/getMonitors" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "api_key=${UPTIMEROBOT_API_KEY}&format=json&custom_uptime_ratios=1-7-30" \
  | jq '.monitors[] | {id, friendly_name, url, type, status, uptime_7d: (.custom_uptime_ratio // "n/a")}'
```

Status values:
- `0` — paused
- `1` — not checked yet
- `2` — up
- `8` — seems down
- `9` — down

### Create HTTP monitor

```bash
curl -s -X POST "https://api.uptimerobot.com/v2/newMonitor" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  --data-urlencode "api_key=${UPTIMEROBOT_API_KEY}" \
  --data-urlencode "format=json" \
  --data-urlencode "friendly_name=My App" \
  --data-urlencode "url=https://app.example.com" \
  --data-urlencode "type=1" \
  --data-urlencode "interval=300"
```

`type` values:
- `1` — HTTP(s)
- `2` — keyword (needs `keyword_type=1|2` and `keyword_value=<str>`)
- `3` — ping
- `4` — port (needs `sub_type` + `port`)
- `5` — heartbeat (passive — call the monitor URL from your app)

`interval` is seconds (min 60 on paid plans, 300 / 5min on free).

### Create keyword monitor (substring must be present in response)

```bash
curl -s -X POST "https://api.uptimerobot.com/v2/newMonitor" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  --data-urlencode "api_key=${UPTIMEROBOT_API_KEY}" \
  --data-urlencode "format=json" \
  --data-urlencode "friendly_name=API Health" \
  --data-urlencode "url=https://api.example.com/health" \
  --data-urlencode "type=2" \
  --data-urlencode "keyword_type=2" \
  --data-urlencode "keyword_value=ok"
```

`keyword_type`: `1` = exists, `2` = not exists (alert when absent).

### Pause / resume

```bash
# Pause
curl -s -X POST "https://api.uptimerobot.com/v2/editMonitor" \
  -d "api_key=${UPTIMEROBOT_API_KEY}&format=json&id=${ID}&status=0"

# Resume
curl -s -X POST "https://api.uptimerobot.com/v2/editMonitor" \
  -d "api_key=${UPTIMEROBOT_API_KEY}&format=json&id=${ID}&status=1"
```

### Delete

```bash
curl -s -X POST "https://api.uptimerobot.com/v2/deleteMonitor" \
  -d "api_key=${UPTIMEROBOT_API_KEY}&format=json&id=${ID}"
```

**Skill always prompts for confirmation before delete — irreversible.**

## Alert contacts

```bash
# List
curl -s -X POST "https://api.uptimerobot.com/v2/getAlertContacts" \
  -d "api_key=${UPTIMEROBOT_API_KEY}&format=json" \
  | jq '.alert_contacts[] | {id, friendly_name, type, value, status}'

# Create email contact
curl -s -X POST "https://api.uptimerobot.com/v2/newAlertContact" \
  -d "api_key=${UPTIMEROBOT_API_KEY}&format=json&type=2&value=you@example.com&friendly_name=Me"
```

`type`: `2` = email, `3` = webhook, `9` = Slack, `11` = Discord, etc.

## Attach contacts to a monitor (on create or edit)

Pass `alert_contacts=<contact_id>_<threshold>_<recurrence>-<contact_id>_0_0-...`:

- `contact_id` — from getAlertContacts
- `threshold` — minutes before alerting (0 for immediate)
- `recurrence` — minutes between re-alerts (0 for one-shot)

Example — alert contact `1234` immediately and never re-alert:

```
alert_contacts=1234_0_0
```

## Read-only mode

Pass `--readonly` to swap `UPTIMEROBOT_API_KEY` for `UPTIMEROBOT_READONLY_API_KEY`. Any mutation (`newMonitor`, `editMonitor`, `deleteMonitor`, `newAlertContact`) returns:

```json
{"stat":"fail","error":{"type":"not_authorized","message":"You are not allowed to perform this request"}}
```

Use for status-page rendering or CI dashboards where write access is unwanted.

## Failure mode patterns

- **`stat: fail` + `error.type: "invalid_parameter"`** — usually missing `format=json` or a required param. Add `--data-urlencode` to every value to avoid breakage on URLs with `&` or `=`.
- **No response / 429** — rate limited. Free plan: ~10 req/s. Back off 1s and retry.
- **"URL is not resolving" on create** — UptimeRobot validates URLs synchronously; fix the URL or use `type=3` (ping) for non-HTTP endpoints.

## Safety

- Delete is irreversible — skill always confirms.
- The **main** API key has full CRUD across all monitors AND access to billing — never ship it anywhere except `~/.claude/.env`.
- For status-page widgets or public dashboards, always use `UPTIMEROBOT_READONLY_API_KEY` — it's scoped to reads only.
- UptimeRobot does not support creating monitors through the public API for some advanced types (e.g. SSL checks) — use dashboard for those.

## See also

- `/ro:cf-ship` — pair a fresh deploy with a new monitor
- `/ro:sentry` — for in-app error tracking (complements UR's external HTTP checks)
- UptimeRobot API docs: https://uptimerobot.com/api — use context7 if syntax changes
