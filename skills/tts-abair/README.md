# tts-abair kit

Wraps the Irish text-to-speech endpoint at `https://synthesis.abair.ie/api/synthesise` (Trinity College Dublin's ABAIR synthesis service, used by the abair.ie web demo at <https://abair.ie/synthesis>).

ElevenLabs has limited Irish coverage in their multilingual models; ABAIR's TCD-trained voices are noticeably better for Irish phonology. Three dialects (Connacht / Munster / Ulster) and two engine families (Piper neural, HTS statistical) are exposed.

## What's in here

| File | Purpose |
|---|---|
| `SKILL.md` | The Claude Code slash-command interface (`/ro:tts-abair`). Thin wrapper around the curl call. |
| `openapi.yaml` | OpenAPI 3.1 spec for the synthesise endpoint. The only formal description that exists; the publisher has none. |
| `scalar.html` | Open in a browser for interactive docs (loads `openapi.yaml`). |
| `bruno/` | [Bruno](https://www.usebruno.com/) collection for manual testing. Open the folder in Bruno, hit `synthesise.bru`. |

## How the four pieces fit together

```
You (in Claude Code)        ──/ro:tts-abair──▶ SKILL.md (curl GET)
You (in browser)            ──open scalar.html──▶ interactive contract docs
You (in Bruno)              ──Send button──▶ same endpoint, manual smoke test
Future you / future LLM     ──read openapi.yaml──▶ understand the surface
```

The OpenAPI spec is the single source of truth for the endpoint shape. SKILL.md, Scalar, and Bruno are three different lenses on it.

## Quick start

```bash
# Default voice (Connacht / Sibéal / Piper)
/ro:tts-abair "Failte go hInis Sligigh!"

# Specific voice + MP3 conversion
/ro:tts-abair "Conas atá tú?" --voice ulster-female --mp3 --output ./greeting.mp3

# Batch from a dialogue file
/ro:tts-abair --file dialogue/cailleach-ban.txt --out-dir assets/audio/ga --mp3
```

## License

Non-commercial / research / educational by default. Identifies itself in `User-Agent`. For commercial use, contact ABAIR via <https://abair.ie/contact>.

## Sister skill

`/ro:stt-abair` is the speech-to-text side (transcribes Irish audio back to text via the recognition endpoint).
