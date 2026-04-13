# Skills

Personal agent skills for Claude Code, Cursor, Codex, and [40+ other AI agents](https://agentskills.io).

## Install

### Option 1: Claude Code Plugin Marketplace (recommended)

```bash
# Add the marketplace (one-time)
/plugin marketplace add RonanCodes/skills

# Install individual plugins
/plugin install ralph@ronan-skills
/plugin install frontend-design@ronan-skills
```

### Option 2: Clone + additionalDirectories

Clone anywhere on your machine:

```bash
git clone https://github.com/RonanCodes/skills.git <your-path>/skills
```

Add to `~/.claude/settings.json`:

```json
{
    "additionalDirectories": ["<your-path>/skills"]
}
```

Update anytime: `cd <your-path>/skills && git pull`

### Option 3: Clone to personal skills

```bash
git clone https://github.com/RonanCodes/skills.git ~/.claude/skills
```

### Option 4: npx (any agent, not just Claude)

```bash
npx skills add RonanCodes/skills/ralph -g
npx skills add RonanCodes/skills/frontend-design -g
```

## Skills

| Skill | Description |
|-------|-------------|
| [ralph](/ralph) | Autonomous build loop. Reads PRD, implements one story per iteration, validates, commits, tracks progress. Based on the Ralph Wiggum technique. |
| [frontend-design](/frontend-design) | Create distinctive, production-grade frontend interfaces. Avoids generic AI aesthetics. |
| [create-skill](/create-skill) | Meta-skill for creating new skills with proper SKILL.md structure, frontmatter, and best practices. |
| [doc-standards](/doc-standards) | Documentation conventions: mermaid diagrams, formatting, when to use which diagram type. |

## How It Works

These skills follow the [Agent Skills](https://agentskills.io) open standard. Each skill is a `SKILL.md` file with YAML frontmatter.

The repo supports multiple install methods:

```
skills/
├── ralph/SKILL.md                    ← direct skills (Options 2-4)
├── frontend-design/SKILL.md
├── create-skill/SKILL.md
├── doc-standards/SKILL.md
├── .claude/skills/                   ← symlinks for additionalDirectories
├── .claude-plugin/marketplace.json   ← marketplace catalog (Option 1)
└── plugins/                          ← plugin-wrapped skills (Option 1)
    ├── ralph/
    ├── frontend-design/
    ├── create-skill/
    └── doc-standards/
```

## License

MIT
