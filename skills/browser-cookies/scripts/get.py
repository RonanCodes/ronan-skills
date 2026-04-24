#!/usr/bin/env python3
"""Extract cookies for a domain from the user's browser.

Usage:
    get.py <domain> [--browser <name>] [--format header|json|jar]

Browsers supported: brave, chrome, arc, chromium, edge, firefox, auto.
Intended to be run via `uv run --with browser-cookie3` so browser_cookie3
is provisioned on demand. Firefox path uses stdlib only.
"""
from __future__ import annotations
import argparse
import json
import pathlib
import shutil
import sqlite3
import sys
import tempfile
import time
from typing import Iterable

DEFAULTS_FILE = pathlib.Path.home() / ".config" / "ro" / "defaults.env"
CHROMIUM_BROWSERS = {"brave", "chrome", "arc", "chromium", "edge"}


def read_robrowser() -> str | None:
    if not DEFAULTS_FILE.exists():
        return None
    for line in DEFAULTS_FILE.read_text().splitlines():
        s = line.strip()
        if s.startswith("ROBROWSER="):
            return s.split("=", 1)[1].strip().strip("'\"")
    return None


def firefox_cookies(domain: str) -> list[dict]:
    root = pathlib.Path.home() / "Library/Application Support/Firefox/Profiles"
    if not root.exists():
        return []
    profile = None
    for p in sorted(root.iterdir(), key=lambda p: p.stat().st_mtime, reverse=True):
        if (p / "cookies.sqlite").exists():
            profile = p
            break
    if profile is None:
        return []

    with tempfile.TemporaryDirectory() as td:
        tmp = pathlib.Path(td) / "cookies.sqlite"
        shutil.copy2(profile / "cookies.sqlite", tmp)
        wal = profile / "cookies.sqlite-wal"
        if wal.exists():
            shutil.copy2(wal, tmp.with_suffix(".sqlite-wal"))
        con = sqlite3.connect(tmp)
        try:
            rows = con.execute(
                "SELECT name, value, host, expiry FROM moz_cookies "
                "WHERE host LIKE ? AND (expiry > ? OR expiry = 0) "
                "ORDER BY name",
                (f"%{domain}%", int(time.time())),
            ).fetchall()
        finally:
            con.close()
    return [
        {"name": n, "value": v, "domain": h, "expires": e} for n, v, h, e in rows
    ]


def chromium_cookies(browser: str, domain: str) -> list[dict]:
    try:
        import browser_cookie3 as bc3  # type: ignore
    except ImportError:
        sys.stderr.write(
            "ERROR: browser_cookie3 not installed. Run via "
            "`uv run --with browser-cookie3 --with requests python3 get.py ...`\n"
        )
        sys.exit(2)

    fn_name = {"chrome": "chrome", "brave": "brave", "arc": "arc",
               "chromium": "chromium", "edge": "edge"}[browser]
    fn = getattr(bc3, fn_name, None)
    if fn is None:
        sys.stderr.write(f"ERROR: browser_cookie3 has no handler for '{browser}'\n")
        sys.exit(2)

    try:
        jar = fn(domain_name=domain)
    except Exception as e:
        sys.stderr.write(
            f"ERROR: could not read {browser} cookies for {domain}: {e}\n"
            "  → First run prompts macOS Keychain. Click 'Always Allow' when prompted.\n"
            "  → Ensure the browser is installed and you're logged into the domain.\n"
        )
        sys.exit(2)

    out = []
    for c in jar:
        out.append({
            "name": c.name,
            "value": c.value,
            "domain": c.domain,
            "expires": int(c.expires) if c.expires else 0,
        })
    return out


def resolve_browser(arg: str | None) -> str:
    if arg and arg != "auto":
        return arg
    default = read_robrowser()
    if default:
        return default
    return "auto"


def auto_order() -> Iterable[str]:
    # Probe order: most likely to have cookies first on macOS.
    yield from ("brave", "chrome", "arc", "firefox")


def format_output(cookies: list[dict], fmt: str) -> str:
    if fmt == "json":
        return json.dumps(cookies, indent=2)
    if fmt == "jar":
        return "\n".join(f"{c['name']}\t{c['value']}" for c in cookies)
    # header — default
    pairs = "; ".join(f"{c['name']}={c['value']}" for c in cookies)
    return f"Cookie: {pairs}"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("domain", help="e.g. linkedin.com, x.com")
    ap.add_argument("--browser", default=None,
                    help="brave|chrome|arc|chromium|edge|firefox|auto")
    ap.add_argument("--format", default="header",
                    choices=("header", "json", "jar"))
    args = ap.parse_args()

    browser = resolve_browser(args.browser)

    cookies: list[dict] = []
    tried: list[str] = []

    def _fetch(b: str) -> list[dict]:
        if b == "firefox":
            return firefox_cookies(args.domain)
        if b in CHROMIUM_BROWSERS:
            return chromium_cookies(b, args.domain)
        return []

    if browser == "auto":
        for b in auto_order():
            tried.append(b)
            cookies = _fetch(b)
            if cookies:
                browser = b
                break
    elif browser in CHROMIUM_BROWSERS or browser == "firefox":
        tried.append(browser)
        cookies = _fetch(browser)
        # Fallback if the configured browser has nothing for this domain.
        # A given site is often logged-into only one browser on a machine.
        if not cookies:
            for b in auto_order():
                if b == browser:
                    continue
                tried.append(b)
                cookies = _fetch(b)
                if cookies:
                    sys.stderr.write(
                        f"[browser-cookies] {browser} had none for {args.domain}; using {b}.\n"
                    )
                    browser = b
                    break
    else:
        sys.stderr.write(f"ERROR: unknown browser '{browser}'\n")
        sys.exit(2)

    if not cookies:
        sys.stderr.write(
            f"ERROR: no cookies found for {args.domain} (tried: {', '.join(tried)}).\n"
            "  → Log into the domain in the target browser, then re-run.\n"
        )
        sys.exit(1)

    sys.stderr.write(f"[browser-cookies] {browser}: {len(cookies)} cookies\n")
    print(format_output(cookies, args.format))


if __name__ == "__main__":
    main()
