---
name: remotion-video
description: Build Remotion video compositions from a video script — React components with transitions, animations, and assets. Use when user wants to build a video, create video components, compose scenes, animate, or assemble a Remotion project.
argument-hint: [--from-script | --scaffold] <project-or-topic>
allowed-tools: Bash(*) Read Write Edit Glob Grep
---

# Remotion Video — Composition Builder

Build professional Remotion video compositions from a `video-script.json`. Creates React components for each scene with transitions, spring animations, text reveals, and Ken Burns effects. This is the core assembly step in the video pipeline.

## Usage

```
/remotion-video --from-script llm-wiki   # Build compositions from video-script.json
/remotion-video --scaffold my-project    # Scaffold a new Remotion project + build
/remotion-video my-project               # Auto-detect: use script if exists, else scaffold
```

## Pipeline Context

This skill is step 3 in the video production pipeline:

```
/video-script  ->  /video-assets  ->  /remotion-video  ->  /video-render
(plan scenes)     (generate PNGs)    (build React)       (render MP4)
```

Each step can also run independently.

## Step 1: Project Setup

### If no Remotion project exists, scaffold one:

```bash
npx create-video@latest sites/videos --template blank
cd sites/videos
npm install @remotion/transitions @remotion/google-fonts
```

### If a project exists, ensure required packages:

```bash
cd sites/videos  # or videos/, or wherever the project lives
npm ls @remotion/transitions 2>/dev/null || npm install @remotion/transitions
npm ls @remotion/google-fonts 2>/dev/null || npm install @remotion/google-fonts
```

### Required packages

| Package | Purpose |
|---------|---------|
| `remotion` | Core — Composition, Sequence, useCurrentFrame, interpolate, spring |
| `@remotion/transitions` | TransitionSeries, fade(), slide(), wipe() |
| `@remotion/google-fonts` | Load Inter or Space Grotesk at module level |
| `@remotion/media-utils` | Audio duration, volume callbacks |

## Step 2: Read the Script

If `video-script.json` exists (produced by `/video-script`), read it and use scene definitions to drive composition building. Extract:

- Total duration and FPS
- Scene list with durations, text, visual types, animations, transitions
- Asset references (cross-reference with `public/assets/assets.json` if it exists)

If no script exists, interview the user about what scenes to build (minimal version of `/video-script`).

## Step 3: Build the Root Composition

### Root.tsx — Register all compositions

```tsx
import { Composition } from "remotion";
import { MainVideo } from "./MainVideo";

export const RemotionRoot: React.FC = () => {
  return (
    <>
      <Composition
        id="MainVideo"
        component={MainVideo}
        durationInFrames={totalFrames}  // duration * fps
        fps={30}
        width={1920}
        height={1080}
      />
    </>
  );
};
```

### MainVideo.tsx — Scene assembly with transitions

Use `TransitionSeries` from `@remotion/transitions` instead of plain `<Sequence>`. Every scene transition uses an explicit effect.

```tsx
import { AbsoluteFill, staticFile, Img, Audio } from "remotion";
import { TransitionSeries, linearTiming } from "@remotion/transitions";
import { fade } from "@remotion/transitions/fade";
import { slide } from "@remotion/transitions/slide";
import { wipe } from "@remotion/transitions/wipe";
import { loadFont } from "@remotion/google-fonts/Inter";

// Load font at module top level — NEVER inside a component
const { fontFamily } = loadFont();

export const MainVideo: React.FC = () => {
  return (
    <AbsoluteFill style={{ fontFamily, backgroundColor: "#0a0a1a" }}>
      <TransitionSeries>
        <TransitionSeries.Sequence durationInFrames={120}>
          <HookScene />
        </TransitionSeries.Sequence>
        <TransitionSeries.Transition
          presentation={fade()}
          timing={linearTiming({ durationInFrames: 15 })}
        />
        <TransitionSeries.Sequence durationInFrames={150}>
          <ProblemScene />
        </TransitionSeries.Sequence>
        <TransitionSeries.Transition
          presentation={slide({ direction: "from-right" })}
          timing={linearTiming({ durationInFrames: 15 })}
        />
        {/* ... more scenes ... */}
      </TransitionSeries>

      {/* Background music with volume envelope */}
      <Audio
        src={staticFile("music/bg.mp3")}
        volume={(f) =>
          f < 30 ? f / 30              // fade in over 1s
          : f > totalFrames - 60 ? (totalFrames - f) / 60  // fade out over 2s
          : 0.3                         // cruise at 30%
        }
      />
    </AbsoluteFill>
  );
};
```

## Step 4: Build Scene Components

Each scene is its own component file in `src/scenes/`. Every scene follows this structure:

```tsx
import { AbsoluteFill, useCurrentFrame, interpolate, spring, Img, staticFile } from "remotion";

export const HookScene: React.FC = () => {
  const frame = useCurrentFrame();

  // ALL animations via useCurrentFrame() — CSS transitions are FORBIDDEN
  const opacity = interpolate(frame, [0, 20], [0, 1], { extrapolateRight: "clamp" });
  const y = interpolate(frame, [0, 25], [40, 0], { extrapolateRight: "clamp" });

  return (
    <AbsoluteFill style={{ backgroundColor: "#0a0a1a" }}>
      {/* Mobile safe zone wrapper */}
      <div style={{
        position: "absolute",
        top: 150, bottom: 170, left: 60, right: 60,
        display: "flex", flexDirection: "column",
        justifyContent: "center", alignItems: "center",
      }}>
        <h1 style={{
          opacity,
          transform: `translateY(${y}px)`,
          color: "#e0e0e0",
          fontSize: 64,
          fontWeight: 700,
          textAlign: "center",
        }}>
          Hook headline here
        </h1>
      </div>
    </AbsoluteFill>
  );
};
```

### Spring Presets

Use these spring configurations consistently across all scenes:

```tsx
// Snappy entrance — titles, icons appearing
const snappy = spring({ frame, fps: 30, config: { damping: 15, stiffness: 200 } });

// Gentle subtitle — secondary text, descriptions
const gentle = spring({ frame: frame - delay, fps: 30, config: { damping: 20, stiffness: 80 } });

// Bouncy pop — badges, stats, callouts
const bouncy = spring({ frame: frame - delay, fps: 30, config: { damping: 8, stiffness: 150 } });
```

### Text Animations

**Typewriter effect** — for terminal commands and code:

```tsx
const text = "npx remotion render";
const charsShown = Math.floor(interpolate(frame, [0, 60], [0, text.length], {
  extrapolateRight: "clamp",
}));
const displayed = text.slice(0, charsShown);
// Add blinking cursor
const cursor = frame % 30 < 20 ? "▌" : " ";
```

**Word-by-word reveal** — for statements and headlines:

```tsx
const words = "Build videos with code".split(" ");
const wordsShown = Math.floor(interpolate(frame, [0, 45], [0, words.length], {
  extrapolateRight: "clamp",
}));
return words.map((word, i) => (
  <span key={i} style={{
    opacity: i < wordsShown ? 1 : 0,
    transform: `translateY(${i < wordsShown ? 0 : 20}px)`,
    transition: "none", // reminder: NO CSS transitions
    display: "inline-block",
    marginRight: 12,
  }}>
    {word}
  </span>
));
```

### Ken Burns Effect on Screenshots

Slow zoom + pan on static images to create movement:

```tsx
const scale = interpolate(frame, [0, 120], [1, 1.3], { extrapolateRight: "clamp" });
const translateX = interpolate(frame, [0, 120], [0, -50], { extrapolateRight: "clamp" });
const translateY = interpolate(frame, [0, 120], [0, -30], { extrapolateRight: "clamp" });

<div style={{ overflow: "hidden", width: "100%", height: "100%" }}>
  <Img
    src={staticFile("assets/screenshot.png")}
    style={{
      width: "100%",
      height: "100%",
      objectFit: "cover",
      transform: `scale(${scale}) translate(${translateX}px, ${translateY}px)`,
    }}
  />
</div>
```

### Images — Always use Remotion's `<Img>`

```tsx
// CORRECT — uses Remotion's <Img> which handles loading
import { Img, staticFile } from "remotion";
<Img src={staticFile("assets/hero.png")} />

// WRONG — native <img> can cause rendering issues
<img src="/assets/hero.png" />
```

## Step 5: File Structure

Organize the Remotion project consistently:

```
sites/videos/
├── src/
│   ├── index.ts              # Entry point
│   ├── Root.tsx               # Composition registration
│   ├── MainVideo.tsx          # Scene assembly + transitions
│   ├── scenes/
│   │   ├── HookScene.tsx
│   │   ├── ProblemScene.tsx
│   │   ├── SolutionScene.tsx
│   │   ├── HeroFeatureScene.tsx
│   │   ├── Feature2Scene.tsx
│   │   └── CTAScene.tsx
│   ├── components/
│   │   ├── TerminalWindow.tsx   # Reusable terminal mockup
│   │   ├── TextReveal.tsx       # Word-by-word text animation
│   │   ├── Typewriter.tsx       # Typewriter text effect
│   │   └── KenBurns.tsx         # Ken Burns image wrapper
│   └── styles/
│       └── colors.ts            # Observatory color constants
├── public/
│   ├── assets/                  # Generated by /video-assets
│   │   ├── assets.json
│   │   └── *.png
│   └── music/                   # Background audio (optional)
├── remotion.config.ts
├── package.json
└── video-script.json            # Generated by /video-script
```

### colors.ts — Observatory Theme

```tsx
export const colors = {
  amber: "#e0af40",
  cyan: "#5bbcd6",
  green: "#7dcea0",
  bgDark: "#0a0a1a",
  bgCard: "#1a1a2e",
  text: "#e0e0e0",
  textMuted: "#6a6a8a",
} as const;
```

## Step 6: Validate

After building all components:

1. **Type check**: `npx tsc --noEmit`
2. **List compositions**: `npx remotion compositions src/index.ts`
3. **Preview still**: `npx remotion still src/index.ts MainVideo out/preview.png --frame=30`
4. **Start studio** (optional): `npx remotion studio` — opens browser preview for manual review

Report any errors and fix before considering the build complete.

## Rules

1. **ALL animations via `useCurrentFrame()`**. CSS transitions, CSS animations, and `requestAnimationFrame` are forbidden — Remotion renders frame-by-frame and CSS timing is meaningless.
2. **Use `staticFile()` for all assets** in `public/`. Never use relative paths or imports for media files.
3. **Use `<Img>` from remotion**, never native `<img>`. Remotion's component handles frame-by-frame loading correctly.
4. **Use `<Audio>` from remotion** with volume callbacks for fade-in/out. Never use native `<audio>`.
5. **Load fonts at module top level** via `@remotion/google-fonts`. Never load fonts inside components or effects.
6. **TransitionSeries, not Sequence** for scene assembly. Every scene-to-scene cut should use an explicit transition (fade, slide, or wipe).
7. **Mobile safe zones**: all critical text within 150px top, 170px bottom, 60px sides at 1920x1080.
8. **One component per scene file** in `src/scenes/`. Reusable animation components go in `src/components/`.
9. **Duration math**: `durationInFrames = seconds * fps`. At 30fps: 1s = 30 frames, 5s = 150 frames, 60s = 1800 frames.

## Licensing

Remotion is free for individuals and companies with 3 or fewer employees. Larger companies need a license from remotion.pro. For the full Remotion API reference, install the official skills: `remotion-dev/skills`.
