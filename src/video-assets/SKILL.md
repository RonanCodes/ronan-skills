---
name: video-assets
description: Generate visual assets for video production — terminal mockups, diagrams, UI screenshots, code snippets. Use when user needs to create video assets, generate screenshots, render mockups, or prepare visuals for a Remotion video.
argument-hint: <script-file> [--generate-all]
allowed-tools: Bash(*) Read Write Edit Glob Grep
---

# Video Assets

Generate visual assets needed for a video — terminal mockups, Mermaid diagrams, UI screenshots, and syntax-highlighted code blocks. Reads a `video-script.json` to determine what's needed, generates each asset, and produces an asset manifest.

## Usage

```
/video-assets video-script.json              # Generate missing assets only
/video-assets video-script.json --generate-all  # Regenerate everything
/video-assets                                # Look for video-script.json in current dir
```

## Prerequisites

- Node.js 16+
- Chromium or Chrome (for HTML-to-screenshot rendering)
- Optional: `npx @mermaid-js/mermaid-cli` (for Mermaid diagrams)
- Optional: `npx playwright install chromium` (if Playwright available for screenshots)

## Step 1: Read the Script

Read `video-script.json` and extract all asset requirements:

- For each scene, check `visual.type` and `visual.assets`
- Build a list of assets to generate with their target dimensions
- Default dimensions: 1920x1080 (full-frame), 960x1080 (half for split-screen)

## Step 2: Generate Assets by Type

### Terminal Mockups

Create HTML files styled as terminal windows, then render to PNG.

```html
<div style="
  background: #1a1a2e;
  border-radius: 12px;
  padding: 0;
  font-family: 'SF Mono', 'Fira Code', monospace;
  width: 1920px;
  height: 1080px;
  display: flex;
  flex-direction: column;
">
  <!-- Title bar -->
  <div style="padding: 12px 16px; display: flex; gap: 8px;">
    <span style="width:12px;height:12px;border-radius:50%;background:#ff5f56;display:inline-block;"></span>
    <span style="width:12px;height:12px;border-radius:50%;background:#ffbd2e;display:inline-block;"></span>
    <span style="width:12px;height:12px;border-radius:50%;background:#27ca40;display:inline-block;"></span>
  </div>
  <!-- Content -->
  <pre style="
    padding: 24px 32px;
    color: #e0e0e0;
    font-size: 22px;
    line-height: 1.6;
    flex: 1;
  ">
<span style="color: #e0af40;">$</span> <span style="color: #5bbcd6;">your-command here</span>
<span style="color: #7dcea0;">Output text here</span>
  </pre>
</div>
```

**Color theme (Observatory):**
- Amber `#e0af40` — prompts, user input, highlights
- Cyan `#5bbcd6` — commands, links, emphasis
- Green `#7dcea0` — output, success states
- Background `#1a1a2e` — terminal background
- Text `#e0e0e0` — default text

Render to PNG using one of these methods (try in order):
1. Playwright: `npx playwright screenshot --viewport-size=1920,1080`
2. Puppeteer: write a quick render script
3. `wkhtmltoimage` if available

### Mermaid Diagrams

Write Mermaid syntax to a `.mmd` file, then render:

```bash
npx @mermaid-js/mermaid-cli -i diagram.mmd -o diagram.png -w 1920 -H 1080 \
  --backgroundColor transparent
```

Use the Observatory color theme in Mermaid:

```mermaid
%%{init: {'theme': 'dark', 'themeVariables': {
  'primaryColor': '#e0af40',
  'secondaryColor': '#5bbcd6',
  'tertiaryColor': '#7dcea0',
  'primaryTextColor': '#e0e0e0',
  'lineColor': '#5bbcd6'
}}}%%
```

If mermaid-cli is not available, create an HTML page with `<script src="https://cdn.jsdelivr.net/npm/mermaid/dist/mermaid.min.js">` and render via browser.

### UI Mockups (Obsidian-style)

Create HTML pages styled to look like Obsidian in dark mode:

- Dark sidebar with file tree (`#1e1e1e` background)
- Main content area with rendered markdown (`#262626` background)
- Graph view: SVG with nodes (circles) and edges (lines), using Observatory colors
- Backlinks panel at bottom

Render via browser to PNG at target resolution.

### Code Snippets

Create syntax-highlighted HTML using inline styles (no external CSS dependencies):

- Dark background (`#1a1a2e`)
- Keywords: cyan (`#5bbcd6`)
- Strings: green (`#7dcea0`)
- Functions: amber (`#e0af40`)
- Comments: muted (`#6a6a8a`)
- Font: monospace, 20-24px for readability at 1080p

Render to PNG via browser.

## Step 3: Save Assets

Save all generated assets to the Remotion project's `public/assets/` directory:

```
public/
  assets/
    hook-terminal.png
    problem-chaos.png
    solution-reveal.png
    hero-feature-demo.png
    diagram-architecture.png
    ...
```

Naming convention: `<scene-id>-<descriptor>.<ext>`

## Step 4: Generate Asset Manifest

Create `public/assets/assets.json`:

```json
{
  "generated": "2024-01-15T10:30:00Z",
  "assets": [
    {
      "file": "hook-terminal.png",
      "scene": "hook",
      "type": "terminal",
      "width": 1920,
      "height": 1080,
      "description": "Terminal showing the problem scenario"
    },
    {
      "file": "solution-reveal.png",
      "scene": "solution",
      "type": "ui-mockup",
      "width": 1920,
      "height": 1080,
      "description": "Obsidian-style wiki view with graph"
    }
  ]
}
```

## Step 5: Report

Display a summary table:

```
Asset                    | Type     | Size     | Scene
-------------------------|----------|----------|--------
hook-terminal.png        | terminal | 1920x1080| hook
problem-chaos.png        | terminal | 1920x1080| problem
solution-reveal.png      | mockup   | 1920x1080| solution
diagram-architecture.png | diagram  | 1920x1080| hero
```

Ask: "All assets generated. Want to preview any, or regenerate specific ones?"

## Rules

1. **All assets must be PNG** at the target resolution (default 1920x1080). No SVG in final output — Remotion's `<Img>` works best with raster images.
2. **Use staticFile() paths** — assets go in `public/` so Remotion can load them via `staticFile('assets/filename.png')`.
3. **Observatory colors only** — amber, cyan, green on dark backgrounds. Consistent visual identity across all assets.
4. **Readable at 1080p** — minimum 18px font size for body text, 28px+ for headlines. Test that text is legible.
5. **Mobile safe zones** — keep critical content within 150px top, 170px bottom, 60px sides margins.
6. **Idempotent** — running without `--generate-all` only creates missing assets. Existing files are preserved.
7. **No external image dependencies** — all assets are self-contained. Don't reference CDN images that might disappear.
