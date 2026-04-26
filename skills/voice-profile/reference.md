# voice-profile skill — reference

Detail loaded on demand by Claude when something in `SKILL.md` is unclear or when running the interview.

## Source documents

- **Origin essay:** Ruben Hassid, "I am just a text file," Jan 2026 — https://ruben.substack.com/p/i-am-just-a-text-file
- **Wiki concept page (Ronan only):** [ai-research:voice-extraction-methodology](obsidian://open?vault=llm-wiki-ai-research&file=wiki%2Fconcepts%2Fvoice-extraction-methodology) — synthesised methodology with the 7-category breakdown, output template, and anti-overfitting layer.

## The mechanism (why this works)

LLMs without context default to the **statistical middle** — the average of everything they've seen. The most common patterns. The safest choices.

A voice file shifts the conditional distribution: the model is no longer "complete this in the most likely way" but "complete this in the way this specific writer would, especially avoiding what they would never do."

**Refusals do more work than preferences.** There are infinitely many ways to "write conversationally" but a finite set of patterns the writer has explicitly excluded. Each rejection cuts the search space. Preferences widen it; rejections narrow it.

This is why ~80% of a good voice file is "I do NOT..." rather than "I do...".

## Per-category interview guidance

Generate questions dynamically. The probes below are areas to interrogate, not literal question wording.

### Section 1 — Beliefs & Contrarian Takes (15 questions)

**Probes:**
- Hot takes about your field
- Conventional wisdom you think is wrong
- Beliefs your peers don't share
- Things that get you fired up to write a rebuttal
- Industry advice you ignore
- "Best practices" you've abandoned

**Push-back examples:**
- "That's a common-enough take. What's the version of it that would get you pushback from your peers?"
- "Give me a specific person/post/book that represents the conventional wisdom you're rejecting."

### Section 2 — Writing Mechanics (20 questions, the largest section)

**Probes:**
- Sentence length default (short, medium, long)
- How you open a piece (story? claim? question? data?)
- How you close a piece (call to action? quiet line? open question?)
- Punctuation habits (semicolons? em-dashes? brackets?)
- Formatting habits (headers? bullets? bold for emphasis?)
- Words you overuse and need to police
- Words you love and use deliberately
- Words you'd never use
- Tense preferences (present? past? mixed?)
- Person preferences (first? second? third?)
- Use of questions in body text
- Use of one-line paragraphs
- Use of lists vs. prose
- Code-switching mid-piece (technical → casual)
- Numbers (always digits? "two" vs "2"?)
- Quotes — how attributed?
- Footnotes / asides
- Hedging words you ban
- Filler you ban
- Section transitions

**Push-back examples:**
- "Show me a real opener you've written that captures this."
- "You said you ban hedging — give me the last sentence you cut for that reason."
- "When you say short sentences, are we talking 5 words, 10 words, or 15?"

### Section 3 — Aesthetic Crimes (15 questions)

**Probes:**
- What makes you cringe in others' writing
- Specific phrases that trigger you
- Lazy patterns you spot immediately
- Genre conventions you find embarrassing (LinkedIn-thought-leader voice, "in today's fast-paced world", "I'm thrilled to announce")
- AI-tells you spot
- Empty signals (em-dashes used as filler, tricolons-for-the-sake-of, "not just X but Y")
- Performative humility ("just a small project I built")
- False precision (made-up percentages, fake statistics)

**Push-back examples:**
- "Quote a phrase. Don't describe it — quote it."
- "Where did you last see this and want to throw your phone?"

### Section 4 — Voice & Personality (15 questions)

**Probes:**
- How much humor (none, dry, broad, self-deprecating)
- Serious vs casual default
- How you handle disagreement (direct? Socratic? avoid?)
- How you sound when excited
- How you sound when skeptical
- Vulnerability — share or guard?
- Self-deprecation — embraced or banned?
- Strong opinions — stated or implied?
- Profanity?
- Pop culture references — yes/no/sparingly?
- Emoji?
- Personal stories — central or absent?
- Authority claims — credentials-up-front or earn-it-on-the-page?
- Reader address (you, we, the reader)
- Generosity vs. punchy?

**Push-back examples:**
- "When you say dry humor — is it observational, sarcastic, deadpan, absurdist?"
- "Last time you cracked a joke in a piece, what was it?"

### Section 5 — Structural Preferences (15 questions)

**Probes:**
- Default piece structure (problem-solution? story-then-lesson? lesson-then-story? listicle?)
- Use of headers (none, every section, every paragraph)
- Use of subheaders
- Pull quotes / callouts?
- Image placement preferences
- Code snippet style (inline, fenced, screenshots)
- Footnotes / asides
- TOC for long pieces?
- Conclusions — yes / no / one line / extended?
- Internal links (cross-reference your own work?)
- External links (footnote vs inline)
- Length preferences per format (tweet, LinkedIn, blog, essay)
- Numbered lists vs bullets
- Tables — when?
- Front-load conclusion or build to it?

**Push-back examples:**
- "What's the wrong way to use a header for you? Show me an article that does it badly."
- "When you say short — 800 words? 1500? 3000?"

### Section 6 — Hard Nos (10 questions)

**Probes:**
- Topics you'd never write about
- Approaches you'd never take (e.g. fake-vulnerable bait posts)
- Lines you won't cross (e.g. won't dunk on named individuals)
- Audiences you'd never write for
- Formats you've sworn off
- Sponsorship / promo styles you reject
- "Hot take" you'd never make
- Personal disclosures you guard
- Engagement bait you refuse
- Controversies you stay out of

**Push-back examples:**
- "Why won't you write about that — what's the cost if you did?"
- "That sounds principled. Have you ever broken it? When?"

### Section 7 — Red Flags (10 questions)

**Probes:**
- What makes you distrust a piece of content immediately
- Tells that the writer doesn't know what they're talking about
- Surface signals of LLM-generated content
- Authorial bad faith signals
- Tells of a paid post pretending to be organic
- "Expert" tells that signal not-actually-expert
- Genre clichés that mark someone as junior
- Visuals that signal lack of taste
- Engagement-farm signals
- Self-promotion tells

**Push-back examples:**
- "Last article you bounced from — what was the specific signal?"
- "Tells of LLM-generated content — give me three concrete ones."

## State file shape

Path: `~/.claude/voice-profile-state.json`

```json
{
  "version": 1,
  "name": "Ronan Connolly",
  "started_at": "2026-04-26T03:15:00Z",
  "last_updated_at": "2026-04-26T03:30:00Z",
  "status": "in_progress",
  "categories": {
    "1_beliefs": { "target": 15, "answered": [/* {q, a, follow_ups, answered_at} */] },
    "2_mechanics": { "target": 20, "answered": [] },
    "3_aesthetic_crimes": { "target": 15, "answered": [] },
    "4_voice_personality": { "target": 15, "answered": [] },
    "5_structural": { "target": 15, "answered": [] },
    "6_hard_nos": { "target": 10, "answered": [] },
    "7_red_flags": { "target": 10, "answered": [] }
  }
}
```

`status` flips to `"compiled"` after `scripts/compile.sh` runs successfully.

## Output template (compile target)

`~/.claude/voice-profile.md`:

```
# VOICE PROFILE: <name>

> Built via /ro:voice-profile on <date>. Source methodology: Ruben Hassid, "I am just a text file" (Jan 2026).

## Core Identity

<2–3 sentence essence. Derived from the interview, written by Claude during compile.>

---

## Section 1 — Beliefs & Contrarian Takes

### Q1: <question>
<full answer>

[follow-ups inline if present]

### Q2: <question>
<full answer>

... (Q1–Q15)

## Section 2 — Writing Mechanics

### Q16 ... (Q16–Q35)

[etc through Section 7]

---

## Quick Reference Card

### Always
- <derived patterns from answers>

### Never
- <derived from "Hard Nos", "Aesthetic Crimes", "Red Flags">

### Signature Phrases & Structures
- <quoted from the interview>

### Voice Calibration
- <key quotes from interview that capture the voice>

---

## How to Use This Document (Anti-Overfitting Guide)

### Frequency labels
Each tendency above carries one of:
- **HARD RULE** — never violate. Rare; mostly in "Never" / "Hard Nos".
- **STRONG TENDENCY** — do this 70–80% of the time. Breaking it occasionally is fine.
- **LIGHT PREFERENCE** — nice to have. Context decides.

If unlabelled, assume LIGHT PREFERENCE.

### Litmus test

Before finalising any output written "as me," ask:

> Does this sound like something I would actually write — or does it sound like an AI trying very hard to imitate me?

If it feels forced, pull back. **Less imitation, more inhabitation.**

### Format adaptation

Voice adapts to format. Tweet ≠ newsletter ≠ LinkedIn ≠ long-form. Tendencies tagged "tweet-only" or "long-form-only" should be honored only in their format.

---

## Instructions for Claude

Read this file first. Then do whatever the user asked. Every drafting prompt should start with this file in context.

If a user asks you to "write something in my voice," you read this file and apply the rules — especially the Never section and the Aesthetic Crimes section. When in doubt, default to the litmus test.
```

## Anti-overfitting layer (why it matters)

Without it, the file produces stiff, over-imitative output that triggers the uncanny valley.

- **Frequency labels** prevent every tendency being treated as binding.
- **Litmus test** is the single most important paragraph — re-read it before publishing anything generated against this profile.
- **Format adaptation** prevents long-form tendencies leaking into tweets and vice versa.
- **Spirit over letter**: the file documents how the writer thinks, not a regex they must satisfy.

## Updating the file

When the writer's voice drifts (every 6–12 months, or after a major positioning shift):

1. Read existing `voice-profile.md`.
2. Run `/ro:voice-profile start` again — confirms with user before overwriting state.
3. Skip to categories where you suspect drift (e.g. just re-do Voice & Personality + Hard Nos).
4. Recompile.
