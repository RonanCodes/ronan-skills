#!/usr/bin/env bash
# GET /users/me — smoke-test auth, print profile.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"
require_key

RESP=$(curl -sS -H "api-key: $DEVTO_API_KEY" "$API_BASE/users/me")

RESP_RAW="$RESP" python3 <<'PY'
import os, json
d = json.loads(os.environ['RESP_RAW'])
print(f"username: {d.get('username')}")
print(f"id:       {d.get('id')}")
print(f"name:     {d.get('name')}")
print(f"location: {d.get('location','')}")
print(f"website:  {d.get('website_url','')}")
print()
print("summary:")
print(d.get('summary',''))
PY
