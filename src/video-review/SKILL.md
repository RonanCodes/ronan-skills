---
name: video-review
description: Review a Remotion composition or rendered video against quality criteria and the video script. Catches issues before the expensive render step. Use when user wants to review, check, QA, or validate a video before rendering.
argument-hint: <composition-id-or-path> [--against <script-file>]
allowed-tools: Bash(*) Read Write Edit Glob Grep
---

# Video Quality Review

Review a Remotion composition (pre-render) or rendered MP4 against quality criteria and the video script. Catches issues before the expensive render step.

## Usage

```
/video-review MainVideo                                    # Review composition in Remotion project
/video-review MainVideo --against video-script.json        # Review against specific script
/video-review out/video.mp4                                # Review rendered output
/video-review out/video.mp4 --against video-script.json    # Review render against script
```

## Step 1: Identify What to Review

### If given a composition ID (e.g., `MainVideo`):

1. Locate the Remotion project — check `sites/videos/`, `videos/`, or current directory for `remotion.config.ts`
2. Find the composition definition — search for `<Composition id="[compositionId]"` in source files
3. Read all `.tsx` source files used by that composition (Root, scenes, shared components)
4. Extract: total duration, fps, resolution, scene structure from `<Sequence>` components
5. If the project has a `public/` folder, inventory available assets

### If given an MP4 path:

1. Verify the file exists and get metadata: `ffprobe -v quiet -print_format json -show_format -show_streams <path>`
2. Extract: duration, resolution, codec, file size
3. Note: source code review checklist items will be skipped (no code to review)

### If --against flag is provided:

1. Read the script file (`video-script.json` or `.md`)
2. Parse expected scenes, durations, on-screen text, narration, and visual directions
3. Each review item will be checked against the script's requirements

## Step 2: Content & Pacing Review

Run through these checks in order. For each, report: PASS, NEEDS WORK, or FAIL with specific details.

### Hook (Critical Priority)

- [ ] **Strong opening in first 3 seconds** — Is there a compelling hook, or does it start with a logo fade / blank screen / slow animation?
- [ ] **No product name in hook** — The hook should lead with a problem or question, not the product name (unless it's a demo video)
- [ ] **Visual movement immediately** — Something must be animating from frame 1 to prevent scroll-past

### Pacing (Critical Priority)

- [ ] **Scene timing matches script** — If reviewing against a script, compare each scene's actual frame count vs. scripted duration. Flag deviations >1 second.
- [ ] **No dead spots** — Look for gaps where nothing changes for >2 seconds (>60 frames at 30fps). Check for sequences with static content and no animation.
- [ ] **Micro-payoffs every 10-15 seconds** — Something new, surprising, or visually distinct must happen at regular intervals.
- [ ] **Total duration in bounds** — Promo: 60-90s (1800-2700 frames at 30fps). Demo: 120-180s (3600-5400 frames).

### Copy Quality (Critical Priority)

- [ ] **No banned buzzwords** — Check all on-screen text against the banned list: leverage, revolutionary, cutting-edge, seamless, empower, synergy, unlock, supercharge, harness, elevate, disrupt, innovate, transform, robust, scalable, next-generation, state-of-the-art, best-in-class, world-class, paradigm
- [ ] **No banned openers** — Check for: "In today's fast-paced world", "Introducing", "Say goodbye to", "What if I told you", "Imagine a world where", "Meet [product]", "The future of X is here"
- [ ] **No AI-isms** — Check for: "harness the power of", "take X to the next level", "game-changer", "from X to Y, we've got you covered", "it's that simple", "but that's not all"
- [ ] **Headlines under 8 words** — Count words in all headline text elements
- [ ] **Subtext under 15 words** — Count words in all supporting text elements
- [ ] **"Would a human say this?" test** — Flag any copy that sounds like a press release or generic marketing

### Feature Count (High Priority)

- [ ] **3-5 features shown** — Count distinct features demonstrated. Fewer than 3 is too thin. More than 5 dilutes impact.
- [ ] **Each feature is visually distinct** — Different layout, different visual treatment. Not just text swaps on the same template.

### Call to Action (High Priority)

- [ ] **Clear CTA in final 3-5 seconds** — One action verb + one URL. Not three CTAs.
- [ ] **URL is readable** — Large enough font, on screen long enough to read (~2 seconds minimum)
- [ ] **CTA matches script** — If reviewing against a script, verify the CTA text and URL match

## Step 3: Visual & Design Review

### Text Readability (Critical Priority)

- [ ] **Headline font size >= 56px** — Check fontSize in headline components. Anything smaller is hard to read on mobile.
- [ ] **Body/subtext font size >= 36px** — Check fontSize in body text components.
- [ ] **Sufficient contrast** — Light text on dark backgrounds (or vice versa). No light gray on white.
- [ ] **Text not clipped** — Ensure text doesn't overflow its container or get cut off at edges.

### Mobile Safe Zones (High Priority)

- [ ] **Top safe zone: 150px** — No critical content in the top 150px (platform UI overlays)
- [ ] **Bottom safe zone: 170px** — No critical content in the bottom 170px (player controls, captions)
- [ ] **Side safe zones: 60px** — No critical content within 60px of left/right edges
- [ ] **Check at 1920x1080** — Safe zones are calibrated for this resolution

### Visual Consistency (Medium Priority)

- [ ] **Observatory color theme** — Are the project colors used? Amber (#e0af40) for user/sources, cyan (#5bbcd6) for engine/skills, green (#7dcea0) for outputs.
- [ ] **Consistent typography** — Same font family throughout. No mixed sans/serif unless intentional.
- [ ] **Consistent spacing** — Padding and margins feel uniform across scenes.

### Transitions (Medium Priority)

- [ ] **Using TransitionSeries** — Transitions between scenes should use Remotion's `<TransitionSeries>` (not hard cuts or CSS transitions)
- [ ] **Transitions are smooth** — No jarring jumps. Transitions should feel natural.
- [ ] **Consistent transition style** — Using the same transition type throughout (or a deliberate pattern)

### Assets (Medium Priority)

- [ ] **Using Remotion's `<Img>`** — All images use `import { Img } from "remotion"`, not native `<img>` tags. Native img causes rendering issues.
- [ ] **Assets loading** — All referenced images/videos exist in `public/` or `src/assets/`
- [ ] **No placeholder images** — No broken images, stock photo watermarks, or "TODO" placeholders

### Audio (Low Priority — skip if no audio)

- [ ] **Background music present** — If specified in script, verify audio file is loaded
- [ ] **Fade-in/fade-out** — Music should fade in over first 1-2 seconds and fade out over last 1-2 seconds
- [ ] **Volume below narration** — Background music volume should be 0.1-0.3 (narration at 0.8-1.0)

## Step 4: Code Quality Review (Source Only)

Skip this section entirely if reviewing an MP4 file (no source code to review).

### Animation Patterns

- [ ] **`useCurrentFrame()` for all animations** — No CSS transitions, no `setTimeout`, no `requestAnimationFrame`. Remotion is frame-based.
- [ ] **`interpolate()` uses `extrapolateRight: "clamp"`** — Without clamp, values keep interpolating beyond the target. Almost always a bug.
- [ ] **Springs have configured damping** — `spring({ frame, fps, config: { damping: 12 } })` — not bare `spring({ frame, fps })` which uses defaults that feel mushy.

### Font Loading

- [ ] **`loadFont()` at module top level** — Fonts must be loaded before render. Not inside components, not in useEffect.
- [ ] **Google Fonts via `@remotion/google-fonts`** — Not manual `@font-face` declarations or CDN links.

### Component Structure

- [ ] **`<Img>` from remotion** — `import { Img } from "remotion"` — not native HTML `<img>`.
- [ ] **`<Video>` from remotion** — If embedding video clips, use `import { Video } from "remotion"`.
- [ ] **No `position: fixed`** — Fixed positioning breaks in Remotion's rendering context.
- [ ] **`<AbsoluteFill>` for layering** — Use Remotion's fill component, not manual absolute positioning with explicit width/height.

### Performance

- [ ] **No heavy computation in render** — No API calls, no file reads, no expensive calculations inside component render functions.
- [ ] **Static assets in `public/`** — Large images/videos should be in `public/`, not imported as modules.

## Step 5: Generate Review Report

Output a structured review to the console (and optionally save to `video-review.md`).

### Report Format

```markdown
# Video Review — [Composition ID or Filename]

**Reviewed:** [date]
**Script:** [script filename or "none"]
**Source:** [composition source / MP4 path]

## Overall: [PASS | NEEDS WORK | FAIL]

[1-2 sentence summary]

---

## Critical Issues (fix before render)

### 1. [Issue title]
**Check:** [which checklist item]
**Location:** [file:line or timestamp]
**Problem:** [specific description]
**Fix:** [concrete suggestion]

### 2. ...

---

## Warnings (should fix)

### 1. [Issue title]
**Check:** [which checklist item]
**Location:** [file:line or timestamp]
**Problem:** [specific description]
**Fix:** [concrete suggestion]

---

## Minor (nice to fix)

### 1. ...

---

## Passed Checks

- [x] Hook in first 3 seconds
- [x] Text readability (headlines 64px, body 40px)
- [x] Mobile safe zones respected
- ...

---

## Summary

| Category | Pass | Warn | Fail |
|----------|------|------|------|
| Content & Pacing | 4 | 1 | 0 |
| Visual & Design | 5 | 2 | 1 |
| Code Quality | 3 | 0 | 0 |
| **Total** | **12** | **3** | **1** |

**Recommendation:** [Fix 1 critical issue, then proceed to render / Needs significant rework / Ready to render]
```

### Scoring Rules

- **PASS** — All critical checks pass. Warnings are acceptable (cosmetic or preference-based).
- **NEEDS WORK** — No critical failures, but multiple high-priority warnings that will noticeably affect quality.
- **FAIL** — One or more critical checks failed. Do not render until fixed.

## Step 6: Offer Next Steps

Based on the review results:

- **If PASS:** "All checks passed. Ready to render with `/video-render`."
- **If NEEDS WORK:** "Found [N] issues to address. Want me to fix them now, or review the report first?"
- **If FAIL:** List the critical issues and offer to fix them. "These [N] critical issues need fixing before render. Want me to start with [highest priority issue]?"

If the user asks to fix issues, make the changes directly in the source files and then offer to re-run the review to verify.

## Integration with Pipeline

This skill fits into the video production pipeline:

```
/video-script  -->  /video-copy  -->  /video-assets  -->  /remotion-video  -->  /video-review  -->  /video-render
```

### Called by Other Skills

- `/close-the-loop` can invoke `/video-review` as part of verification
- After fixes are applied, re-run to verify improvements
- When all checks pass, the pipeline proceeds to `/video-render`

### Re-review Pattern

```
/video-review MainVideo          # Initial review — finds 3 issues
# ... fix issues ...
/video-review MainVideo          # Re-review — verifies fixes, finds 0 issues
/video-render MainVideo          # Proceed to render
```
