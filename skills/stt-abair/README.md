# stt-abair kit

Wraps the Irish speech-to-text endpoint at `https://recognition.abair.ie/v3-5/transcribe` (Trinity College Dublin's ABAIR-ÉIST + Fotheidil models, used by the abair.ie web demo at <https://abair.ie/recognition>).

Whisper does not support Irish (`ga` is missing from the tokenizer, confirmed by maintainer reply). ABAIR is the only viable Irish STT option in 2026.

## What's in here

| File | Purpose |
|---|---|
| `SKILL.md` | The Claude Code slash-command interface (`/ro:stt-abair`). Thin wrapper around the curl call below. |
| `openapi.yaml` | OpenAPI 3.1 spec for the transcribe endpoint. The only formal description that exists; the publisher has none. |
| `scalar.html` | Open in a browser for interactive docs (loads `openapi.yaml`). |
| `bruno/` | [Bruno](https://www.usebruno.com/) collection for manual testing. Open the folder in Bruno, drop a sample WAV into `bruno/samples/`, hit `transcribe.bru`. |

## How the four pieces fit together

```
You (in Claude Code)        ──/ro:stt-abair──▶ SKILL.md (curl POST)
You (in browser)            ──open scalar.html──▶ interactive contract docs
You (in Bruno)              ──Send button──▶ same endpoint, manual smoke test
Future you / future LLM     ──read openapi.yaml──▶ understand the surface
```

The OpenAPI spec is the single source of truth for the endpoint shape. SKILL.md, Scalar, and Bruno are three different lenses on it.

## Quick start

```bash
# Round-trip test using the sister skill
/ro:tts-abair "Failte go hInis Sligigh, a chara!" --output /tmp/test.wav
/ro:stt-abair --audio /tmp/test.wav
# expected: "fáilte go hinis sligigh a chara" (close)
```

## License

Non-commercial / research / educational by default. Identifies itself in `User-Agent`. For commercial use, contact ABAIR via <https://abair.ie/contact>.

## Sister skill

`/ro:tts-abair` is the speech synthesis side (Connacht / Munster / Ulster voices, Piper neural model).
