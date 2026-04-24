#!/usr/bin/env python3
"""LinkedIn OAuth 2.0 authorization code flow.

Opens the LinkedIn auth page, catches the redirect on localhost:8765,
exchanges the code for an access token, resolves the member URN via
/v2/userinfo, and writes the result back to ~/.claude/.env.
"""
from __future__ import annotations
import http.server
import json
import os
import pathlib
import secrets
import socketserver
import sys
import time
import urllib.parse
import urllib.request
import webbrowser

ENV = pathlib.Path.home() / ".claude" / ".env"
PORT = 8765
REDIRECT = f"http://localhost:{PORT}/callback"
SCOPES = ["openid", "profile", "email", "w_member_social"]
TIMEOUT_SEC = 120


def load_env() -> dict[str, str]:
    data: dict[str, str] = {}
    if not ENV.exists():
        return data
    for raw in ENV.read_text().splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, v = line.split("=", 1)
        data[k.strip()] = v.strip().strip("'\"")
    return data


def save_env(updates: dict[str, str]) -> None:
    """Upsert keys in ~/.claude/.env, preserving order and comments."""
    ENV.parent.mkdir(parents=True, exist_ok=True)
    lines: list[str] = []
    seen: set[str] = set()
    if ENV.exists():
        for raw in ENV.read_text().splitlines():
            stripped = raw.strip()
            if stripped and not stripped.startswith("#") and "=" in stripped:
                key = stripped.split("=", 1)[0].strip()
                if key in updates:
                    lines.append(f"{key}={updates[key]}")
                    seen.add(key)
                    continue
            lines.append(raw)
    for k, v in updates.items():
        if k not in seen:
            lines.append(f"{k}={v}")
    ENV.write_text("\n".join(lines).rstrip() + "\n")
    os.chmod(ENV, 0o600)


def die(msg: str, code: int = 1) -> None:
    print(f"ERROR: {msg}", file=sys.stderr)
    sys.exit(code)


def main() -> None:
    env = load_env()
    client_id = env.get("LINKEDIN_CLIENT_ID")
    client_secret = env.get("LINKEDIN_CLIENT_SECRET")
    if not client_id or not client_secret:
        die(
            "LINKEDIN_CLIENT_ID and LINKEDIN_CLIENT_SECRET must be set in "
            f"{ENV}. See skills/linkedin/SKILL.md 'First-time setup'."
        )

    state = secrets.token_urlsafe(24)
    auth_url = "https://www.linkedin.com/oauth/v2/authorization?" + urllib.parse.urlencode(
        {
            "response_type": "code",
            "client_id": client_id,
            "redirect_uri": REDIRECT,
            "scope": " ".join(SCOPES),
            "state": state,
        }
    )

    result: dict[str, str] = {}

    class Handler(http.server.BaseHTTPRequestHandler):
        def log_message(self, *args, **kwargs):
            pass

        def do_GET(self):  # noqa: N802
            parsed = urllib.parse.urlparse(self.path)
            if parsed.path != "/callback":
                self.send_response(404)
                self.end_headers()
                return
            qs = urllib.parse.parse_qs(parsed.query)
            if qs.get("state", [""])[0] != state:
                self.send_response(400)
                self.end_headers()
                self.wfile.write(b"state mismatch")
                result["error"] = "state-mismatch"
                return
            if "error" in qs:
                self.send_response(400)
                self.end_headers()
                msg = f"{qs['error'][0]}: {qs.get('error_description', [''])[0]}"
                self.wfile.write(msg.encode())
                result["error"] = msg
                return
            result["code"] = qs.get("code", [""])[0]
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.end_headers()
            self.wfile.write(
                b"<!doctype html><meta charset=utf-8>"
                b"<h1>LinkedIn auth OK</h1>"
                b"<p>You can close this tab and return to your terminal.</p>"
            )

    print(f"Opening browser to LinkedIn auth...\n  {auth_url}\n")
    try:
        webbrowser.open(auth_url)
    except Exception:
        print("(could not auto-open; paste the URL into your browser)")

    try:
        server = socketserver.TCPServer(("localhost", PORT), Handler)
    except OSError as e:
        die(f"could not bind localhost:{PORT}: {e}. Is another process using it?")

    server.timeout = 1
    deadline = time.time() + TIMEOUT_SEC
    with server:
        while time.time() < deadline and not result:
            server.handle_request()

    if "error" in result:
        die(f"auth failed: {result['error']}")
    if "code" not in result:
        die(f"auth timed out after {TIMEOUT_SEC}s with no redirect received.")

    print("Got authorization code. Exchanging for access token...")
    body = urllib.parse.urlencode(
        {
            "grant_type": "authorization_code",
            "code": result["code"],
            "redirect_uri": REDIRECT,
            "client_id": client_id,
            "client_secret": client_secret,
        }
    ).encode()
    req = urllib.request.Request(
        "https://www.linkedin.com/oauth/v2/accessToken",
        data=body,
        headers={"Content-Type": "application/x-www-form-urlencoded"},
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            tok = json.loads(r.read())
    except urllib.error.HTTPError as e:
        die(f"token exchange failed: {e.code} {e.read().decode(errors='replace')}")

    access_token = tok.get("access_token")
    if not access_token:
        die(f"no access_token in response: {tok}")
    expires_in = int(tok.get("expires_in", 5184000))
    expires_at = int(time.time()) + expires_in

    print("Resolving member URN via /v2/userinfo...")
    req = urllib.request.Request(
        "https://api.linkedin.com/v2/userinfo",
        headers={"Authorization": f"Bearer {access_token}"},
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            me = json.loads(r.read())
    except urllib.error.HTTPError as e:
        die(f"/v2/userinfo failed: {e.code} {e.read().decode(errors='replace')}")
    sub = me.get("sub", "")
    name = me.get("name", "")

    save_env(
        {
            "LINKEDIN_ACCESS_TOKEN": access_token,
            "LINKEDIN_ACCESS_TOKEN_EXPIRES_AT": str(expires_at),
            "LINKEDIN_PERSON_SUB": sub,
        }
    )

    days = max(0, (expires_at - int(time.time())) // 86400)
    tail = access_token[-4:] if access_token else "?"
    print(
        f"\n✓ Auth complete for {name} (sub={sub}).\n"
        f"  Token …{tail} valid for ~{days} days.\n"
        f"  Written to {ENV}."
    )


if __name__ == "__main__":
    main()
