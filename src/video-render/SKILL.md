---
name: video-render
description: Render Remotion video compositions with optimal settings and post-process for size and quality. Use when user wants to render a video, export video, encode, compress, create social cuts, or finalize video output.
argument-hint: <composition-id> [--quality high|draft] [--social]
allowed-tools: Bash(*) Read Write Edit Glob Grep
---

# Video Render & Post-Process

Render Remotion compositions with optimal settings, compress with FFmpeg, and optionally create social media cuts. Handles the full path from composition to deliverable MP4.

## Usage

```
/video-render MainVideo                     # Render with default (draft) settings
/video-render MainVideo --quality high      # Benchmark first, then render at optimal settings
/video-render MainVideo --quality draft     # Fast render for preview
/video-render MainVideo --social            # Also render 15s and 30s vertical cuts
/video-render MainVideo --quality high --social  # Full production render with social cuts
```

## Step 1: Pre-flight Checks

Before rendering, verify:

1. **Remotion project exists** — look for `remotion.config.ts` or `src/index.ts` in `sites/videos/`, `videos/`, or current directory
2. **Composition exists** — run `npx remotion compositions src/index.ts` and verify the requested composition ID is listed
3. **Dependencies installed** — check `node_modules/` exists, run `npm install` if needed
4. **Assets present** — if `public/assets/assets.json` exists, verify all listed files are present

## Step 2: Quick Preview (always)

Before committing to a full render, generate a still frame to validate:

```bash
npx remotion still src/index.ts <composition-id> out/preview.png \
  --frame=30 --scale=0.5
```

Show the preview to the user. Ask: "Preview frame looks good? Proceed with full render?"

If the user spots issues, stop and let them fix before rendering.

## Step 3: Render

### Draft Mode (default)

Optimized for speed — good for iteration and review.

```bash
npx remotion render src/index.ts <composition-id> out/<composition-id>-draft.mp4 \
  --codec h264 \
  --concurrency 75% \
  --log=error
```

### High Quality Mode

First, benchmark to find optimal concurrency for this machine:

```bash
npx remotion benchmark src/index.ts <composition-id> \
  --concurrency 25%,50%,75%,100%
```

Use the concurrency value that produced the fastest render, then:

```bash
npx remotion render src/index.ts <composition-id> out/<composition-id>.mp4 \
  --codec h264 \
  --concurrency <optimal>% \
  --log=error
```

## Step 4: Post-Process with FFmpeg

### Production Compression (--quality high)

Reduce file size by ~80% with minimal visual quality loss:

```bash
ffmpeg -i out/<composition-id>.mp4 \
  -c:v libx264 -crf 28 -preset slow \
  -c:a aac -b:a 128k \
  -movflags +faststart \
  out/<composition-id>-final.mp4
```

### Draft Compression (--quality draft)

Fast compression for previews:

```bash
ffmpeg -i out/<composition-id>-draft.mp4 \
  -c:v libx264 -crf 23 -preset ultrafast \
  -c:a aac -b:a 128k \
  -movflags +faststart \
  out/<composition-id>-preview.mp4
```

The `-movflags +faststart` flag enables progressive playback (important for web).

## Step 5: Social Media Cuts (--social)

When `--social` is specified, render additional versions for social platforms.

### Identify Cut Points

Read `video-script.json` to determine which scenes to include in short cuts:

- **15s cut**: Hook + Hero Feature + CTA (skip problem/supporting features)
- **30s cut**: Hook + Problem + Solution + Hero Feature + CTA

### Render Vertical Versions (1080x1920)

For each cut, the Remotion project should have vertical compositions (e.g., `MainVideo-Vertical-15s`, `MainVideo-Vertical-30s`). If they don't exist, render horizontal and crop:

```bash
# Crop horizontal 1920x1080 to vertical 1080x1920 (center crop)
ffmpeg -i out/<composition-id>-final.mp4 \
  -vf "crop=608:1080:656:0,scale=1080:1920" \
  -c:v libx264 -crf 28 -preset slow \
  -t 15 \
  out/<composition-id>-vertical-15s.mp4
```

Note: center-crop is a fallback. For best results, the Remotion project should have dedicated vertical compositions that respect mobile safe zones (150px top, 170px bottom, 60px sides at 1080x1920 resolution).

### Platform-Specific Specs

| Platform | Aspect | Max Duration | Resolution | Notes |
|----------|--------|-------------|------------|-------|
| Twitter/X | 16:9 or 1:1 | 2:20 | 1920x1080 | Auto-plays muted |
| Instagram Reels | 9:16 | 90s | 1080x1920 | Text in safe zone |
| TikTok | 9:16 | 10min | 1080x1920 | First 3s critical |
| LinkedIn | 16:9 or 1:1 | 10min | 1920x1080 | Subtitles essential |
| YouTube Shorts | 9:16 | 60s | 1080x1920 | Vertical only |

## Step 6: Report

Display a summary of all rendered files:

```
File                              | Resolution | Duration | Size    | Quality
----------------------------------|------------|----------|---------|--------
MainVideo-final.mp4               | 1920x1080  | 75s      | 4.2 MB  | high
MainVideo-vertical-15s.mp4        | 1080x1920  | 15s      | 0.8 MB  | high
MainVideo-vertical-30s.mp4        | 1080x1920  | 30s      | 1.5 MB  | high

Render time: 2m 34s
Compression savings: 78% (19.1 MB -> 4.2 MB)
```

Get file sizes and duration with:

```bash
ffprobe -v error -show_entries format=duration,size -of csv=p=0 out/file.mp4
```

## Step 7: Open Output

Open the final rendered file for the user:

```bash
open out/<composition-id>-final.mp4    # macOS
xdg-open out/<composition-id>-final.mp4  # Linux
```

## Rules

1. **Always preview before full render.** A single still frame takes seconds and catches layout issues before a multi-minute render.
2. **Never render without checking the composition exists.** Fail fast with a clear error message.
3. **FFmpeg post-processing is not optional** for high quality. Raw Remotion output is significantly larger than needed.
4. **Report file sizes.** Users need to know if their video is too large for target platforms (Twitter: 512MB, LinkedIn: 5GB).
5. **Draft is the default.** Only render high quality when explicitly requested — saves minutes of render time during iteration.
6. **Social cuts require video-script.json** to know which scenes to include. Without it, fall back to first-15s / first-30s trimming.
