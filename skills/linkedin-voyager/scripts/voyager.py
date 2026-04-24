#!/usr/bin/env python3
"""LinkedIn Voyager API wrapper.

Uses tomquirk/linkedin-api with session cookies extracted via browser_cookie3.
Never accepts or stores a password.

Usage:
    voyager.py profile <slug> [--json] [--browser <name>]
    voyager.py contact <slug> [--json] [--browser <name>]
    voyager.py search <keywords> [--limit 10] [--json] [--browser <name>]
    voyager.py connections [--json] [--browser <name>]
"""
from __future__ import annotations
import argparse
import json
import pathlib
import sys
from typing import Any

DEFAULTS_FILE = pathlib.Path.home() / ".config" / "ro" / "defaults.env"
CHROMIUM = {"brave", "chrome", "arc", "chromium", "edge"}


def read_robrowser() -> str:
    if not DEFAULTS_FILE.exists():
        return "brave"
    for line in DEFAULTS_FILE.read_text().splitlines():
        s = line.strip()
        if s.startswith("ROBROWSER="):
            return s.split("=", 1)[1].strip().strip("'\"") or "brave"
    return "brave"


FALLBACK_BROWSERS = ("brave", "arc", "chrome", "chromium", "edge", "firefox")
REQUIRED_COOKIES = {"li_at", "JSESSIONID"}


def _try_one_browser(browser: str):
    import browser_cookie3 as bc3
    try:
        if browser == "firefox":
            return bc3.firefox(domain_name="linkedin.com")
        fn = getattr(bc3, browser, None)
        if fn is None:
            return None
        return fn(domain_name="linkedin.com")
    except Exception:
        return None


def get_cookies(browser: str):
    """Return a RequestsCookieJar with LinkedIn cookies.

    Tries the requested browser first, then falls back across the Chromium
    family + Firefox. LinkedIn sessions often live in only one browser on a
    machine (e.g., Arc even when Brave is the daily driver), so a silent
    fallback beats making the user guess.

    Important normalization: Chromium stores JSESSIONID/li_at with domain
    `.www.linkedin.com` and quoted values like `"ajax:..."`. requests'
    cookiejar domain-match rejects `.www.linkedin.com` for the host
    `www.linkedin.com`, so those cookies never get sent — which makes
    LinkedIn respond 403 "CSRF check failed". We rebuild the jar using
    domain=.linkedin.com and stripped values.
    """
    try:
        import browser_cookie3 as bc3  # noqa: F401
    except ImportError:
        die("browser_cookie3 not installed. Re-run via `uv run --with browser-cookie3 ...`.")
    try:
        from requests.cookies import RequestsCookieJar
    except ImportError:
        die("requests not installed. Re-run via `uv run --with requests ...`.")

    tried: list[tuple[str, str]] = []
    order = [browser] + [b for b in FALLBACK_BROWSERS if b != browser]
    for b in order:
        src = _try_one_browser(b)
        if src is None:
            tried.append((b, "unreadable"))
            continue
        raw_names = {c.name for c in src}
        missing = REQUIRED_COOKIES - raw_names
        if missing:
            tried.append((b, f"missing {','.join(sorted(missing))}"))
            continue
        jar = RequestsCookieJar()
        for c in src:
            value = c.value or ""
            # JSESSIONID is stored quoted but csrf-token must match unquoted;
            # strip only here, leave other cookies (bcookie, lidc, etc.) intact.
            if c.name == "JSESSIONID" and value.startswith('"') and value.endswith('"'):
                value = value[1:-1]
            # Normalize domain: Chromium stores as `.www.linkedin.com` which
            # requests' cookiejar won't send to host `www.linkedin.com`.
            jar.set(c.name, value, domain=".linkedin.com", path="/")
        if b != browser:
            sys.stderr.write(
                f"[voyager] {browser} lacked LinkedIn session; using {b} instead.\n"
            )
        return jar

    summary = "; ".join(f"{b}: {why}" for b, why in tried)
    die(
        f"No browser on this machine has a live LinkedIn session. Tried: {summary}.\n"
        f"  Log into linkedin.com in your daily browser and retry."
    )


def get_api(browser: str):
    try:
        from linkedin_api import Linkedin
    except ImportError:
        die("linkedin-api not installed. Re-run via `uv run --with 'linkedin-api>=2.3' ...`.")

    jar = get_cookies(browser)
    # linkedin-api: username+password can be empty strings when cookies provided
    return Linkedin("", "", cookies=jar, refresh_cookies=False)


def die(msg: str, code: int = 1):
    sys.stderr.write(f"ERROR: {msg}\n")
    sys.exit(code)


# ------------- pretty printers -------------

def fmt_date(d: dict | None) -> str:
    if not d:
        return ""
    y = d.get("year")
    m = d.get("month")
    if y and m:
        return f"{y}-{m:02d}" if isinstance(m, int) else f"{y}-{m}"
    return str(y or "")


def _as_str(v):
    """Dash responses vary: a field can be a plain string, or a dict with
    `localized.<locale>.value`, or `defaultLocalizedName` with the same shape.
    Walk until we find a str."""
    if isinstance(v, str):
        return v
    if isinstance(v, dict):
        for k in ("value", "defaultLocalizedName", "defaultLocalizedNameWithoutCountryName",
                  "name", "localizedName"):
            if k in v:
                s = _as_str(v[k])
                if s:
                    return s
        loc = v.get("localized")
        if isinstance(loc, dict):
            for lv in loc.values():
                s = _as_str(lv)
                if s:
                    return s
    return ""


def _location_str(el: dict) -> str:
    loc = el.get("location") or {}
    geo = (el.get("geoLocation") or {}).get("geo") or {}
    country = _as_str(geo.get("country"))
    city = _as_str(geo.get("defaultLocalizedName")) or _as_str(
        geo.get("defaultLocalizedNameWithoutCountryName")
    )
    bits = [x for x in (city, country) if x]
    if bits:
        return ", ".join(bits)
    parts = [loc.get(k) for k in ("postalCode", "countryCode")]
    return " ".join(p for p in parts if p)


def render_profile(el: dict) -> str:
    """Render the dash FullProfile-138 top-card: name, headline, about, location."""
    lines: list[str] = []
    name = f"{el.get('firstName', '')} {el.get('lastName', '')}".strip()
    headline = el.get("headline", "") or ""
    summary = el.get("summary", "") or ""
    location = _location_str(el)
    slug = el.get("publicIdentifier") or ""

    lines.append(f"# {name}")
    if headline:
        lines.append(headline)
    if location:
        lines.append(location)
    if slug:
        lines.append(f"linkedin.com/in/{slug}")

    if summary:
        lines += ["", "## About", "", summary.strip()]

    lines += [
        "",
        "_Experience, Education, Skills are on separate dash endpoints — not fetched by the top-card call. See SKILL.md TODO._",
    ]
    return "\n".join(lines)


def render_contact(c: dict) -> str:
    lines = ["# Contact info"]
    for k in ("email_address", "phone_numbers", "twitter", "websites", "birthdate", "ims"):
        v = c.get(k)
        if v:
            lines.append(f"- {k}: {v}")
    return "\n".join(lines)


# ------------- commands -------------

DASH_FULL_PROFILE_DECO = "com.linkedin.voyager.dash.deco.identity.profile.FullProfile-138"


def cmd_profile(args):
    # The library's get_profile() hits /identity/profiles/<slug>/profileView which
    # returned 410 Gone in early 2026. Use the dash endpoint instead. Response
    # shape differs — see render_profile() for field mapping.
    api = get_api(args.browser)
    r = api.client.session.get(
        "https://www.linkedin.com/voyager/api/identity/dash/profiles",
        params={
            "q": "memberIdentity",
            "memberIdentity": args.slug,
            "decorationId": DASH_FULL_PROFILE_DECO,
        },
    )
    if r.status_code != 200:
        die(f"dash profile fetch failed: HTTP {r.status_code}\n  body: {r.text[:400]}")
    data = r.json()
    els = data.get("elements") or []
    if not els:
        die(f"no profile found for slug '{args.slug}' (empty elements)")
    el = els[0]
    if args.json:
        print(json.dumps(el, indent=2, default=str))
        return
    print(render_profile(el))


def cmd_contact(args):
    api = get_api(args.browser)
    c = api.get_profile_contact_info(public_id=args.slug)
    if args.json:
        print(json.dumps(c, indent=2, default=str))
        return
    print(render_contact(c))


def cmd_search(args):
    api = get_api(args.browser)
    results = api.search_people(keywords=" ".join(args.keywords), limit=args.limit)
    if args.json:
        print(json.dumps(results, indent=2, default=str))
        return
    for r in results:
        name = r.get("name") or ""
        occ = r.get("jobtitle") or r.get("location") or ""
        slug = r.get("public_id") or ""
        print(f"- {name} — {occ}  (linkedin.com/in/{slug})")


def cmd_connections(args):
    api = get_api(args.browser)
    # viewer's own slug from /v2/userinfo is not available here; use the Voyager 'me' helper
    me = api.get_user_profile()
    urn_id = me.get("miniProfile", {}).get("entityUrn", "").split(":")[-1]
    if not urn_id:
        die("could not resolve viewer urn_id from get_user_profile()")
    conns = api.get_profile_connections(urn_id)
    if args.json:
        print(json.dumps(conns, indent=2, default=str))
        return
    for c in conns:
        name = f"{c.get('firstName','')} {c.get('lastName','')}".strip()
        occ = c.get("occupation") or ""
        slug = c.get("publicIdentifier") or ""
        print(f"- {name} — {occ}  (linkedin.com/in/{slug})")


# ------------- main -------------

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--browser", default=read_robrowser())
    sub = ap.add_subparsers(dest="cmd", required=True)

    p_profile = sub.add_parser("profile")
    p_profile.add_argument("slug")
    p_profile.add_argument("--json", action="store_true")
    p_profile.set_defaults(func=cmd_profile)

    p_contact = sub.add_parser("contact")
    p_contact.add_argument("slug")
    p_contact.add_argument("--json", action="store_true")
    p_contact.set_defaults(func=cmd_contact)

    p_search = sub.add_parser("search")
    p_search.add_argument("keywords", nargs="+")
    p_search.add_argument("--limit", type=int, default=10)
    p_search.add_argument("--json", action="store_true")
    p_search.set_defaults(func=cmd_search)

    p_conn = sub.add_parser("connections")
    p_conn.add_argument("--json", action="store_true")
    p_conn.set_defaults(func=cmd_connections)

    args = ap.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
