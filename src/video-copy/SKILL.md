---
name: video-copy
description: Write compelling on-screen text and narration for video scenes. Generates multiple copy versions per scene with different angles and tones. Use when user wants to write video copy, headlines, narration, subtitles, or on-screen text for a video.
argument-hint: <script-file-or-topic> [--tone casual|bold|technical] [--versions 3]
allowed-tools: Read Write Edit Glob Grep
---

# Video Copywriting

Write punchy, specific, memorable on-screen text and narration for video scenes. Every line must pass the "would a human actually say this?" test.

## Usage

```
/video-copy video-script.json                          # Read script, write copy (3 versions, casual tone)
/video-copy video-script.json --tone bold              # Bold/provocative tone
/video-copy video-script.json --tone technical          # Developer-focused precision
/video-copy video-script.json --versions 5              # 5 versions per scene
/video-copy "LLM Wiki promo"                           # Topic-only mode (generates scenes from topic)
```

## Step 1: Read the Script

If given a script file (`video-script.json` or `.md`):

- Parse every scene: id, name, duration, purpose, existing narration/onScreenText
- Note total duration and scene timing — narration must fit within each scene's time budget
- Identify the video's core message and target audience

If given a topic string instead of a file:

- Look for `video-script.json` in the current directory or `sites/videos/`
- If no script exists, ask the user: "No video script found. Want me to write copy for a general topic, or should you run `/video-script` first?"
- For topic-only mode, assume a standard promo structure: hook, problem, solution, features (x2-3), CTA

## Step 2: Write Copy for Each Scene

For every scene, generate the requested number of versions (default: 3).

Each version includes:

| Element | Constraints |
|---------|------------|
| **Headline** | Max 8 words. Punchy, surprising. The thing that catches the eye first. |
| **Subtext** | Max 15 words. Supports the headline — adds context, not repetition. |
| **Narration** | Conversational, 2-3 sentences max. Must be speakable in the scene's time (~3 words/second). |

### Version Differentiation Rules

Each version must take a **genuinely different angle**, not just swap synonyms:

- **Different framing:** one version uses a question, another a statement, another a contrast
- **Different specificity:** one version uses a concrete number/stat, another uses a scenario, another uses an analogy
- **Different emotional register:** even within the same tone setting, vary between curiosity, confidence, urgency, humor

Hard requirements across all versions:

- At least one version must use a **question** as the headline
- At least one version must include a **concrete number or stat**
- At least one version must use a **contrast** ("X, not Y" or "Before/After")

## Step 3: Apply Tone

### casual

Conversational, slightly playful. Write like a smart friend showing you something cool.

- "Your wiki grows while you sleep"
- "One command. 47 pages. Zero copy-paste."
- "Remember that article from last week? Neither do I."

### bold

Confident, direct, slightly provocative. State opinions. Challenge the status quo.

- "Stop re-googling the same thing"
- "Your bookmarks folder is a graveyard"
- "RAG is a crutch. Build real knowledge."

### technical

Precise, developer-focused. Lead with specifics, use technical language naturally.

- "One CLI command. 47 cross-linked markdown pages."
- "YAML frontmatter. Wikilinks. Git-versioned."
- "Ingests 7 source types. Outputs Obsidian-compatible markdown."

## Step 4: Output video-copy.md

Write the file to the same directory as the script (or current directory if topic-only).

Format:

```markdown
# Video Copy — [Project/Topic Name]

**Tone:** [casual|bold|technical]
**Script source:** [filename or "topic-only"]
**Generated:** [date]

---

## Scene 1: [Scene Name] ([duration]s)

**Purpose:** [What this scene needs to accomplish]
**Time budget for narration:** [duration x 3 = max word count] words

### Version A
**Headline:** [max 8 words]
**Subtext:** [max 15 words]
**Narration:** [speakable in allocated time]

### Version B
**Headline:** ...
**Subtext:** ...
**Narration:** ...

### Version C
**Headline:** ...
**Subtext:** ...
**Narration:** ...

---

## Scene 2: [Scene Name] ([duration]s)
...
```

## Step 5: Review with User

Present a summary table for quick scanning:

```
Scene     | Duration | Version A Headline     | Version B Headline     | Version C Headline
----------|----------|------------------------|------------------------|------------------------
Hook      | 4s       | "Ever lost context..."  | "50 tabs. Zero recall." | "What did that article say?"
Problem   | 5s       | "Your brain leaks."     | "Knowledge dies in tabs"| "How many times have you..."
...
```

Ask: "Which versions resonate? I can mix and match — e.g., Version A for the hook, Version C for the CTA."

After the user picks favorites, offer: "Want me to update the `video-script.json` with the selected copy?"

## Banned Words and Phrases

These are **non-negotiable** — if any appear in output, rewrite immediately.

### Banned Buzzwords
leverage, revolutionary, cutting-edge, seamless, empower, synergy, unlock, supercharge, harness, elevate, disrupt, innovate, transform, robust, scalable, next-generation, state-of-the-art, best-in-class, world-class, paradigm

### Banned Openers
"In today's fast-paced world...", "Introducing...", "Say goodbye to...", "What if I told you...", "Imagine a world where...", "Meet [product]...", "The future of X is here"

### Banned AI-isms
"harness the power of", "take X to the next level", "game-changer", "game-changing", "a]a single source of truth", "from X to Y, we've got you covered", "it's that simple", "but that's not all"

### The Rewrite Test

Before finalizing any copy, run these checks:

1. **The Generic Test:** Could this headline appear on any product's landing page? If yes, rewrite with specifics.
2. **The Read-Aloud Test:** Say it out loud. Does it sound like a human talking, or a press release? If stilted, rewrite.
3. **The "So What?" Test:** After reading the headline, would someone think "so what?" If yes, add a concrete outcome.
4. **The Specificity Test:** Are there numbers, scenarios, or concrete details? Vague = bad.

## Copy Principles

1. **Show, don't tell.** "Builds 47 wiki pages from one article" beats "Powerful ingestion engine."
2. **Concrete beats abstract.** "3 seconds to ingest a YouTube video" beats "Fast ingestion."
3. **Questions create curiosity.** "How many times have you re-googled the same thing?" pulls viewers in.
4. **Contrast creates clarity.** "One command, not 47 browser tabs" makes the value obvious.
5. **Short sentences hit harder.** Cut every word that doesn't earn its place.
6. **Subvert expectations.** If the viewer can predict the next word, you've lost them.
7. **Write for muted viewing.** Headlines and subtext are the primary channel — narration is a bonus.

## Integration with Pipeline

This skill fits into the video production pipeline:

```
/video-script  -->  /video-copy  -->  /video-assets  -->  /remotion-video  -->  /video-review  -->  /video-render
```

After copy is approved, the selected versions can be fed into:
- `video-script.json` — updates the `onScreenText` and `narration` fields per scene
- `/video-assets` — copy informs what visual assets are needed
- `/remotion-video` — components render the final copy
