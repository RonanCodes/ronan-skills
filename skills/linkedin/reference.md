# LinkedIn skill — reference

## OAuth 2.0 flow (what `auth.py` actually does)

1. Loads `LINKEDIN_CLIENT_ID` + `LINKEDIN_CLIENT_SECRET` from `~/.claude/.env`. Fails if missing.
2. Generates a random `state` token and opens:
   ```
   https://www.linkedin.com/oauth/v2/authorization
     ?response_type=code
     &client_id=<id>
     &redirect_uri=http://localhost:8765/callback
     &scope=openid+profile+email+w_member_social
     &state=<random>
   ```
3. Binds a one-shot HTTP server on `localhost:8765` and waits up to 120s for the redirect.
4. Validates `state`, then POSTs to `https://www.linkedin.com/oauth/v2/accessToken`:
   ```
   grant_type=authorization_code
   code=<received>
   redirect_uri=http://localhost:8765/callback
   client_id=<id>
   client_secret=<secret>
   ```
5. Calls `GET https://api.linkedin.com/v2/userinfo` with the new bearer token to resolve the member `sub` (used to build `urn:li:person:<sub>`).
6. Writes back to `~/.claude/.env` (mode 0600):
   - `LINKEDIN_ACCESS_TOKEN`
   - `LINKEDIN_ACCESS_TOKEN_EXPIRES_AT` (epoch seconds)
   - `LINKEDIN_PERSON_SUB`

LinkedIn access tokens do NOT come with a refresh token for standard OIDC apps. Re-run `auth` when the token expires (~60d).

## Scopes

| Scope | Purpose |
|-------|---------|
| `openid` | OIDC — required to call `/v2/userinfo` |
| `profile` | First name, last name, picture |
| `email` | Email address |
| `w_member_social` | Create posts on the authenticated member's behalf |

Adding company-page posting requires `w_organization_social` and an approved org URN (not wired; see "Extending" below).

## Posts API (`/rest/posts`)

Endpoint: `POST https://api.linkedin.com/rest/posts`

Headers:
- `Authorization: Bearer <token>`
- `LinkedIn-Version: 202411`  (YYYYMM — bump as newer versions stabilize)
- `X-Restli-Protocol-Version: 2.0.0`
- `Content-Type: application/json`

Body:
```json
{
  "author": "urn:li:person:<sub>",
  "commentary": "your post text, UTF-8, newlines fine",
  "visibility": "PUBLIC",
  "distribution": {
    "feedDistribution": "MAIN_FEED",
    "targetEntities": [],
    "thirdPartyDistributionChannels": []
  },
  "lifecycleState": "PUBLISHED",
  "isReshareDisabledByAuthor": false
}
```

Success = `201 Created`. The new post URN is in the `x-restli-id` response header (e.g. `urn:li:share:7123456789`). The skill prints `https://www.linkedin.com/feed/update/<urn>/` as a best-effort browse URL.

Character limit: ~3000 chars of commentary. No client-side truncation in this skill — LinkedIn rejects oversize bodies with 400.

## Errors you'll hit

| Status | Meaning | Fix |
|--------|---------|-----|
| 401 | Token expired or missing scope | Re-run `/ro:linkedin auth`; confirm `w_member_social` is on the app |
| 403 | App missing "Share on LinkedIn" product approval | Request it in app console → Products |
| 422 | Bad body (usually missing `distribution` or wrong `author` URN) | Verify `LINKEDIN_PERSON_SUB` is set and body matches above |
| 429 | Rate limited (per-member quota) | Wait; LinkedIn posts are rate-limited to roughly 100/day per member |

## Profile edits (why `draft` mode only)

LinkedIn's **Profile Edit API** is restricted to enterprise/Talent Solutions partners. The `w_member_social` scope does not include profile-section writes. There is no public endpoint to change:

- Headline, About, Industry, Location
- Experience / Position entries
- Education entries
- Skills, Languages, Certifications

The unofficial `tomquirk/linkedin-api` Python lib reaches these via LinkedIn's internal Voyager API — explicitly violates ToS and risks account ban. This skill refuses to go there.

`draft-edit.sh` is the pragmatic escape hatch:
- Copies the generated text to the clipboard (`pbcopy`).
- Opens the closest stable edit URL for the section.
- You paste + click save.

Section → URL mapping:

| Section | URL | Notes |
|---------|-----|-------|
| `about` | `https://www.linkedin.com/in/me/` | Click pencil on About section |
| `headline` | `https://www.linkedin.com/in/me/` | Click pencil on intro card |
| `experience` | `https://www.linkedin.com/in/me/add-edit/POSITION/` | Add-position form opens directly |
| `education` | `https://www.linkedin.com/in/me/add-edit/EDUCATION/` | Add-education form opens directly |
| `skills` | `https://www.linkedin.com/in/me/` | Scroll to Skills, click pencil |

LinkedIn changes these URLs occasionally. If a deep link 404s, open `https://www.linkedin.com/in/me/` and navigate manually.

## Extending — company page posts

1. Get your company's URN: `urn:li:organization:<id>` (find in LinkedIn admin URL).
2. Add `w_organization_social` to the scope list in `auth.py`.
3. Re-run `/ro:linkedin auth` so LinkedIn re-prompts for the new scope.
4. Add a `--org <id>` flag to `post.sh` that swaps `author` to the org URN.

## Files

```
skills/linkedin/
├── SKILL.md
├── reference.md           # this file
└── scripts/
    ├── common.sh          # env loader + token expiry check, sourced by the .sh scripts
    ├── auth.py            # OAuth flow
    ├── post.sh            # POST /rest/posts
    ├── me.sh              # GET /v2/userinfo
    └── draft-edit.sh      # clipboard + open editor, no API calls
```
