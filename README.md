# Ronan Skills (`ro`)

A Claude Code plugin bundling 26 personal skills for development, quality, browser/visual, audio/media, research, and project setup. Invoke any skill as `/ro:<skill-name>`.

Also publishable to Cursor, and individual skills work with [40+ other AI agents](https://agentskills.io) via `npx skills add`.

## Install

### Claude Code (recommended — bundles all 26 skills in one command)

```bash
/plugin marketplace add RonanCodes/ronan-skills
/plugin install ro@ronan-skills
```

Skills then appear as `/ro:ralph`, `/ro:commit`, `/ro:tdd`, etc. Run `/plugin` to manage.

### Cursor

The same repo is also a Cursor plugin (see `.cursor-plugin/plugin.json`). Submit via [cursor.com/marketplace/publish](https://cursor.com/marketplace/publish) or point Cursor at the `skills/` directory locally. Cursor CLI does not yet support plugins — IDE only.

### Other agents (Codex, Cline, etc.) — per-skill install

```bash
npx skills add RonanCodes/ronan-skills/skills/ralph -g
npx skills add RonanCodes/ronan-skills/skills/commit -g
# ...etc per skill, -g for global, omit for project-local
```

## Configuration

Skills that need API keys (e.g. `perplexity-research`) read from a shared env file:

- **Claude Code**: `${CLAUDE_PLUGIN_DATA}/.env` — persistent, survives plugin updates
- **Other agents**: `~/.config/ro/.env`

Copy `.env.example` as a starting point, or run `/ro:setup-wizard --tokens` for a guided walkthrough.

## Skills

All skills invoke as `/ro:<skill-name>` in Claude Code.

### Development Workflow

| Skill | Description |
|-------|-------------|
| [ralph](skills/ralph) | Autonomous build loop. Picks tasks from `.ralph/prd.json`, implements, validates, commits. |
| [write-a-prd](skills/write-a-prd) | Generate a PRD through an interactive interview. Quick or plan mode. |
| [tdd](skills/tdd) | Test-driven development with red-green-refactor cycles and vertical slices. |
| [commit](skills/commit) | Emoji conventional commit format. Handles staging, messages, timestamp rules. |
| [close-the-loop](skills/close-the-loop) | Verification loop — tests pass, UI works, screenshots match. |
| [debug-escape](skills/debug-escape) | Break out of debugging loops by stepping back and researching. |
| [post-mortem](skills/post-mortem) | Document a resolved bug as a structured post-mortem. |
| [coding-principles](skills/coding-principles) | KISS, SOLID, DRY, tracer bullets. Index always loaded, detail files on demand. |

### Quality & Review

| Skill | Description |
|-------|-------------|
| [grill-me](skills/grill-me) | Stress-test plans, designs, PRDs, or code with relentless probing questions. |
| [ubiquitous-language](skills/ubiquitous-language) | DDD-style glossary for consistent domain terminology. |
| [git-guardrails](skills/git-guardrails) | Blocks destructive git commands, suggests safer alternatives. _(auto-loaded)_ |

### Browser & Visual

| Skill | Description |
|-------|-------------|
| [frontend-design](skills/frontend-design) | Distinctive, production-grade frontend interfaces. Avoids generic AI aesthetics. |
| [browser-dev](skills/browser-dev) | Lightweight browser automation via custom scripts. No MCP required. |
| [playwright-check](skills/playwright-check) | Playwright MCP — navigate, interact, screenshot, check console errors. |
| [visual-diff](skills/visual-diff) | Compare two images using pixel diff and Claude vision. |
| [firefox-cookies](skills/firefox-cookies) | Extract cookies from Firefox for authenticated scraping. macOS only. _(internal)_ |

### Research

| Skill | Description |
|-------|-------------|
| [perplexity-research](skills/perplexity-research) | Sourced web research via the Perplexity API. |

### Audio & Media

| Skill | Description |
|-------|-------------|
| [tts-elevenlabs](skills/tts-elevenlabs) | Text-to-speech via ElevenLabs API. Multiple voices, multilingual. |
| [sfx-elevenlabs](skills/sfx-elevenlabs) | Sound effects generation via ElevenLabs. Text-to-sound, 0.5–30s. |
| [music-elevenlabs](skills/music-elevenlabs) | Music generation via ElevenLabs. Instrumental, composition plans. |
| [audio-mix](skills/audio-mix) | Combine voice + music + SFX via ffmpeg. Volume, fade, timestamps. |
| [generate-image](skills/generate-image) | Image generation via AI APIs. |
| [transcribe](skills/transcribe) | Audio/video transcription to text. |

### Project Setup & Tooling

| Skill | Description |
|-------|-------------|
| [create-skill](skills/create-skill) | Scaffold a new `SKILL.md` with proper structure and frontmatter. |
| [setup-wizard](skills/setup-wizard) | Interactive onboarding — plugin install, IDE, MCP servers, API tokens. |
| [doc-standards](skills/doc-standards) | Documentation conventions — mermaid diagrams, formatting. _(auto-loaded)_ |

## Recommended MCPs

Skills pair well with these MCP servers. Install globally:

```bash
claude mcp add -s user playwright -- npx @playwright/mcp@latest
claude mcp add -s user context7 -- npx -y @upstash/context7-mcp@latest
```

| MCP | What it does |
|-----|-------------|
| [Playwright](https://github.com/microsoft/playwright-mcp) | Browser automation — test UIs, screenshot, interact with pages |
| [Context7](https://github.com/upstash/context7) | Up-to-date library docs in context (no API key needed) |

## Repo Structure

```
ronan-skills/
├── .claude-plugin/
│   ├── plugin.json          # Claude Code plugin manifest (name: "ro")
│   └── marketplace.json     # Marketplace entry
├── .cursor-plugin/
│   └── plugin.json          # Cursor plugin manifest
├── skills/
│   ├── ralph/SKILL.md
│   ├── write-a-prd/SKILL.md
│   ├── tdd/SKILL.md
│   ├── commit/SKILL.md
│   ├── close-the-loop/SKILL.md
│   ├── debug-escape/SKILL.md
│   ├── post-mortem/SKILL.md
│   ├── coding-principles/SKILL.md
│   ├── grill-me/SKILL.md
│   ├── ubiquitous-language/SKILL.md
│   ├── git-guardrails/SKILL.md
│   ├── frontend-design/SKILL.md
│   ├── browser-dev/SKILL.md
│   ├── playwright-check/SKILL.md
│   ├── visual-diff/SKILL.md
│   ├── firefox-cookies/SKILL.md
│   ├── perplexity-research/SKILL.md
│   ├── create-skill/SKILL.md
│   ├── setup-wizard/SKILL.md
│   ├── doc-standards/SKILL.md
│   ├── tts-elevenlabs/SKILL.md
│   ├── sfx-elevenlabs/SKILL.md
│   ├── music-elevenlabs/SKILL.md
│   ├── audio-mix/SKILL.md
│   ├── generate-image/SKILL.md
│   └── transcribe/SKILL.md
├── .env.example
├── README.md
└── LICENSE
```

Each skill is a `SKILL.md` with YAML frontmatter (`name`, `description`, `category`, ...). Follows the [Agent Skills](https://agentskills.io) open standard.

## Versioning & Plugin Updates

**Important:** Claude Code's plugin system caches plugins by version. `claude plugin update` and `autoUpdate` both compare the `version` field in `.claude-plugin/plugin.json` — if it hasn't changed, updates silently no-op even if new skills were added.

**Convention:** Bump the version in `.claude-plugin/plugin.json` whenever skills are added, removed, or significantly changed. Use semver:
- **Patch** (1.1.1 → 1.1.2): Fixes within existing skills
- **Minor** (1.1.0 → 1.2.0): New skills added
- **Major** (1.0.0 → 2.0.0): Breaking changes to existing skills

Without a version bump, colleagues running `claude plugin update ro@ronan-skills` will miss new skills.

## License

MIT
