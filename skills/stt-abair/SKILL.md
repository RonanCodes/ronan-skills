---
name: stt-abair
description: Speech-to-text for Irish (Gaeilge) via abair.ie's recognition API (ABAIR-ÉIST / Fotheidil). Accepts an audio file (WAV/WebM/MP3/Opus) and returns transcribed text. Use when transcribing Irish audio, evaluating pronunciation, or wiring "speak Irish to the game" loops. Sibling to /ro:tts-abair (the synthesis side) and /ro:transcribe (Whisper, which has no Irish support).
user-invocable: true
allowed-tools: Bash(curl *) Bash(jq *) Bash(file *) Bash(ffmpeg *) Bash(which *) Bash(mkdir *) Bash(date *) Bash(cat *) Bash(stat *) Read Write Glob
content-pipeline:
  - pipeline:audio
  - platform:agnostic
  - role:primitive
---

# STT — abair.ie (Irish / Gaeilge)

Transcribe Irish speech to text using Trinity College Dublin's [abair.ie](https://abair.ie) recognition service (ABAIR-ÉIST and the newer Fotheidil end-to-end model). Accepts an audio file in any browser-recordable format (WAV, WebM/Opus, MP3) and returns the transcribed text plus a flag for whether capitalisation and punctuation were applied.

This is the **only** option for Irish STT today: OpenAI Whisper does not include `ga` in its tokenizer, ElevenLabs has no Irish, and Web Speech API does not work in installed iOS PWAs. ABAIR is it.

## License and ethics

Same posture as `/ro:tts-abair`. The endpoint is undocumented but stable (versioned URL, FastAPI backend). License is **non-commercial / research / educational** by default. For commercial use, contact ABAIR via <https://abair.ie/contact>. This skill identifies itself in the User-Agent and rate-limits batched calls.

## Usage

```
/ro:stt-abair --audio <path> [--mp3] [--no-punctuation]
/ro:stt-abair --file lines.json [--out <path>]   # batch from a JSON manifest
```

Flags:
- `--audio <path>` — path to a single audio file. WAV / WebM / MP3 / Opus all work.
- `--file <path>` — JSON manifest for batch transcription. Each entry is `{audio: "<path>", expected?: "<text>", id?: "<key>"}`. Output is per-file under `--out` directory.
- `--out <path>` — output JSON path (single mode) or directory (batch). Default `/tmp/stt-abair-<timestamp>.json`.
- `--mp3` — input is MP3 and the API rejects it (rare); transcode via ffmpeg to WAV first. Most browsers send WebM/Opus which the API accepts directly.
- `--no-punctuation` — request the raw transcript without ABAIR's punctuation/capitalisation pass. Off by default (server returns `captpunct_applied: true` whenever it could apply it).

## How it works

A single endpoint, multipart upload:

```
POST https://recognition.abair.ie/v3-5/transcribe
Content-Type: multipart/form-data
file: <audio bytes>

Response (200, application/json):
{
  "text": "fáilte go hinis sligigh a chara",
  "captpunct_applied": true|false
}
```

Discovered shape: the API is FastAPI + Pydantic on the server side. Wrong field name returns `422` with a useful Pydantic error (`{detail: [{type: "missing", loc: ["body","file"], msg: "Field required"}]}`). The version path (`/v3-5/`) suggests the team versions and ships multiple model generations.

## Step 1: Parse args + check input

```bash
INPUT_AUDIO="${INPUT_AUDIO:-}"
OUTPUT="${OUTPUT:-/tmp/stt-abair-$(date +%s).json}"

if [ -z "$INPUT_AUDIO" ] && [ -z "$BATCH_FILE" ]; then
  echo "Usage: /ro:stt-abair --audio <path>  OR  --file <manifest.json>" >&2
  exit 1
fi

if [ -n "$INPUT_AUDIO" ] && [ ! -f "$INPUT_AUDIO" ]; then
  echo "Audio not found: $INPUT_AUDIO" >&2
  exit 1
fi
```

## Step 2: Call the transcribe endpoint

```bash
MIME=$(file -b --mime-type "$INPUT_AUDIO")
curl -sS -o /tmp/stt-abair-resp.json -w "%{http_code}" \
  -H 'Accept: */*' \
  -H 'Origin: https://abair.ie' \
  -H 'Referer: https://abair.ie/' \
  -H 'User-Agent: stt-abair-skill/1.0 (+https://abair.ie; non-commercial; via /ro:stt-abair)' \
  -F "file=@${INPUT_AUDIO};type=${MIME}" \
  https://recognition.abair.ie/v3-5/transcribe > /tmp/stt-abair-status

STATUS=$(cat /tmp/stt-abair-status)
if [ "$STATUS" != "200" ]; then
  echo "abair.ie returned HTTP $STATUS" >&2
  cat /tmp/stt-abair-resp.json >&2
  exit 1
fi
```

## Step 3: Persist + report

```bash
cp /tmp/stt-abair-resp.json "$OUTPUT"
TEXT=$(jq -r '.text' "$OUTPUT")
APPLIED=$(jq -r '.captpunct_applied' "$OUTPUT")
echo "$TEXT"
echo "(captpunct_applied: $APPLIED, written to $OUTPUT)"
```

## Step 4: Batch mode

When `--file manifest.json` is passed, iterate. Manifest shape:

```json
[
  { "id": "cailleach-greeting", "audio": "assets/audio/ga/cailleach-greeting.wav", "expected": "fáilte go hinis sligigh" },
  { "id": "iasc-win",            "audio": "assets/audio/ga/iasc-win.wav",         "expected": "tá an t-ádh leat" }
]
```

For each entry, transcribe, write `${OUT_DIR}/${id}.json`, and if `expected` is present, compute a Levenshtein similarity score for cheap pronunciation grading. Sleep 1 second between requests.

```bash
mkdir -p "$OUT_DIR"
jq -c '.[]' "$BATCH_FILE" | while read -r entry; do
  ID=$(echo "$entry" | jq -r '.id')
  AUDIO=$(echo "$entry" | jq -r '.audio')
  EXPECTED=$(echo "$entry" | jq -r '.expected // empty')
  OUTPUT="${OUT_DIR}/${ID}.json"
  # ...call transcribe as in step 2...
  # if EXPECTED is set, post-process the response to add a similarity score
  sleep 1
done
```

## Example: round-trip via tts-abair

The fastest sanity check is to synthesise a phrase, then transcribe it back:

```bash
/ro:tts-abair "Failte go hInis Sligigh, a chara!" --output /tmp/test.wav
/ro:stt-abair --audio /tmp/test.wav
# expected: "fáilte go hinis sligigh a chara" (or close)
```

## When to use this vs other STT

- **Use `/ro:stt-abair`** for any Irish (Gaeilge) speech. It is the only viable production option in 2026.
- **Use `/ro:transcribe`** (Whisper) for English, Dutch, and ~98 other languages. Whisper has no Irish support; do not point it at Irish audio.
- **Web Speech API** in the browser is fine for desktop tabs in Chrome but does not work in installed iOS PWAs. Skip for tablet-first apps.

## Pronunciation scoring (cheap version)

Raw Whisper-style transcription does not give phoneme-level scores. The cheap "good enough" pattern that the [voice-stt comparison page](https://github.com/RonanCodes/llm-wiki/blob/main/vaults/llm-wiki-research/wiki/comparisons/voice-stt-for-language-learning-games.md) recommends:

```
score = 1 - (levenshtein(normalize(heard), normalize(expected)) / max(len(heard), len(expected)))
```

Threshold of `0.75` works as a "close enough" gate for a kid reading a phrase aloud. For real phoneme-level scoring, only Azure Speech Pronunciation Assessment ships it out of the box (and it has no Irish support either). For a love-project, the cheap method is enough.

## Caveats

- The endpoint is undocumented. Trinity College may change it. If the skill stops working, check `https://abair.ie/recognition` in a browser, look at the network tab, see if the URL pattern still matches `POST /v3-5/transcribe` with multipart `file`.
- ABAIR's chat / speech-to-speech endpoint (`abair.ie/api/s2s`) is **WAA-protected** (Google Web App Attestation) and not callable server-side without a browser-issued attestation token. Do not try to wrap it; use this STT skill plus your own LLM (Claude / Gemini / etc.) plus `/ro:tts-abair` if you need a chat loop.
- Maximum audio length: untested, but the page handles dictation of paragraphs comfortably. For very long audio, split client-side and concat transcripts.
- Capitalisation and punctuation are added when ABAIR can determine them. For raw transcript, you can post-process to lowercase + strip punctuation if needed.

## Sister files in this kit

- `openapi.yaml` — OpenAPI 3.1 spec for the transcribe endpoint (the only authoritative description anywhere).
- `scalar.html` — open in a browser for an interactive view of the spec, including a "try it" panel.
- `bruno/` — Bruno collection for manual testing. Open in [Bruno](https://www.usebruno.com/) and hit the request.
- `README.md` — explains how the four pieces fit together.

## Sources

- [ABAIR initiative homepage](https://abair.ie/)
- [Recognition tool](https://abair.ie/recognition) (the web demo this skill mirrors)
- ABAIR-ÉIST paper (2022): <https://aclanthology.org/2022.cltw-1.7/>
- Fotheidil paper (2025): <https://arxiv.org/html/2501.00509v1>
- Sister skill: `/ro:tts-abair` (synthesis side)
