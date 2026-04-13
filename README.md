# Skills

Personal agent skills for Claude Code, Cursor, Codex, and [40+ other AI agents](https://agentskills.io).

## Install

### With npx (any agent)

```bash
# Install a single skill globally
npx skills add RonanCodes/skills/ralph -g
npx skills add RonanCodes/skills/frontend-design -g
npx skills add RonanCodes/skills/create-skill -g

# Install to current project only (no -g)
npx skills add RonanCodes/skills/ralph
```

### With Claude Code

Clone to your personal skills directory (available in every project):

```bash
git clone https://github.com/RonanCodes/skills.git ~/.claude/skills
```

Update anytime: `cd ~/.claude/skills && git pull`

## Skills

| Skill | Description |
|-------|-------------|
| [ralph](/ralph) | Autonomous build loop. Reads PRD, implements one story per iteration, validates, commits, tracks progress. Based on the Ralph Wiggum technique. |
| [frontend-design](/frontend-design) | Create distinctive, production-grade frontend interfaces. Avoids generic AI aesthetics. Includes Observatory design system tokens. |
| [create-skill](/create-skill) | Meta-skill for creating new skills with proper SKILL.md structure, frontmatter, and best practices. |
| [doc-standards](/doc-standards) | Documentation conventions: mermaid diagrams, formatting, when to use which diagram type. |

## How It Works

These skills follow the [Agent Skills](https://agentskills.io) open standard. Each skill is a `SKILL.md` file with YAML frontmatter that tells the agent when to use it and markdown content with instructions.

```
skills/              ← this repo, cloned to ~/.claude/skills/
├── ralph/SKILL.md
├── frontend-design/SKILL.md
├── create-skill/SKILL.md
├── doc-standards/SKILL.md
└── README.md
```

## License

MIT
