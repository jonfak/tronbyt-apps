#!/usr/bin/env python3
"""
ai_usage helper
================

Small companion service for the `ai_usage` Tronbyt/Pixlet app. It holds the
OAuth login for one or more AI accounts, keeps the access tokens refreshed,
calls each provider's usage endpoint, and serves a single aggregated JSON
document that the Pixlet app renders.

Why this exists: consumer AI plans (Claude subscriptions, ChatGPT/Codex) don't
expose usage over a public API. But the official CLIs (`claude`, `codex`) log
in via OAuth and can read their own "how much have I used" endpoint. This tool
reuses those same OAuth logins so nothing has to be scraped and no password is
ever handled here.

Supported providers:
  - claude  -> GET https://api.anthropic.com/api/oauth/usage
  - codex   -> GET https://chatgpt.com/backend-api/wham/usage  (ChatGPT plan)

Only stdlib is used (Python 3.11+ for tomllib).

Typical flow
------------
  1. Log into an account with its official CLI, e.g. `claude` (or
     `claude setup-token`), or `codex login`.
  2. Snapshot that login into a named slot:
        ./ai_usage_helper.py import claude_personal
     Then log into the *other* account and import it into its own slot:
        ./ai_usage_helper.py import claude_work
     ...and the Codex account:
        ./ai_usage_helper.py import codex_work
  3. Sanity-check one account:
        ./ai_usage_helper.py fetch claude_personal
  4. Run the server the Pixlet app talks to:
        ./ai_usage_helper.py serve

Accounts are declared in accounts.toml (see accounts.example.toml). The
account id you pass to `import` must match an id in that file, and its
`provider` decides which credential file / endpoint is used.

NOTE ON THE REFRESH CONSTANTS: the OAuth client IDs and token endpoints below
are the public values used by the Claude Code / Codex CLIs. They are the one
thing most likely to drift over time; if refresh starts failing with 400/401,
re-check them against the current CLIs. `fetch --raw <id>` dumps the untouched
provider response so you can see exactly what came back.
"""

import argparse
import http.server
import json
import os
import socketserver
import sys
import time
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

try:
    import tomllib
except ModuleNotFoundError:  # pragma: no cover - Python < 3.11
    sys.exit("This tool needs Python 3.11+ (for tomllib).")

# --------------------------------------------------------------------------
# Paths / config
# --------------------------------------------------------------------------

HERE = Path(__file__).resolve().parent
CONFIG_HOME = Path(
    os.environ.get("AI_USAGE_HELPER_HOME", Path.home() / ".config" / "ai-usage-helper")
)
CRED_DIR = CONFIG_HOME / "creds"

CLAUDE_USER_AGENT = "claude-code/1.0.0 (ai-usage-helper)"

# Public OAuth client IDs + token endpoints used by the official CLIs. See the
# module docstring — these are the values to re-verify if refresh breaks.
CLAUDE_CLIENT_ID = "9d1c250a-e61b-44d9-88ed-5944d1962f5e"
CLAUDE_TOKEN_URL = "https://console.anthropic.com/v1/oauth/token"
CODEX_CLIENT_ID = "app_EMoamEEZ73f0CkXaXp7hrann"
CODEX_TOKEN_URL = "https://auth.openai.com/oauth/token"

# Per-account accent colors handed to the display when the config doesn't set one.
DEFAULT_COLORS = {
    "claude": "#d97757",
    "codex": "#19c37d",
}


def load_config():
    path = Path(os.environ.get("AI_USAGE_ACCOUNTS", HERE / "accounts.toml"))
    if not path.exists():
        sys.exit(
            "No accounts config found at %s.\n"
            "Copy accounts.example.toml to accounts.toml and edit it." % path
        )
    with open(path, "rb") as fh:
        cfg = tomllib.load(fh)
    cfg.setdefault("server", {})
    cfg.setdefault("accounts", [])
    by_id = {}
    for acct in cfg["accounts"]:
        if "id" not in acct or "provider" not in acct:
            sys.exit("Every [[accounts]] entry needs an id and a provider.")
        by_id[acct["id"]] = acct
    cfg["_by_id"] = by_id
    return cfg


def account_or_die(cfg, account_id):
    acct = cfg["_by_id"].get(account_id)
    if acct is None:
        ids = ", ".join(cfg["_by_id"]) or "(none)"
        sys.exit("Unknown account '%s'. Known ids: %s" % (account_id, ids))
    return acct


# --------------------------------------------------------------------------
# Credential storage (one JSON blob per account slot)
# --------------------------------------------------------------------------


def cred_path(account_id):
    return CRED_DIR / ("%s.json" % account_id)


def read_creds(account_id):
    path = cred_path(account_id)
    if not path.exists():
        return None
    with open(path) as fh:
        return json.load(fh)


def write_creds(account_id, creds):
    CRED_DIR.mkdir(parents=True, exist_ok=True)
    path = cred_path(account_id)
    tmp = path.with_suffix(".tmp")
    with open(tmp, "w") as fh:
        json.dump(creds, fh, indent=2)
    os.chmod(tmp, 0o600)
    tmp.replace(path)


# --------------------------------------------------------------------------
# HTTP helpers
# --------------------------------------------------------------------------


def http_json(method, url, headers=None, body=None, timeout=20):
    data = None
    headers = dict(headers or {})
    if body is not None:
        data = json.dumps(body).encode()
        headers.setdefault("Content-Type", "application/json")
    req = urllib.request.Request(url, data=data, method=method, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            raw = resp.read().decode()
    except urllib.error.HTTPError as exc:
        raw = exc.read().decode(errors="replace")
        raise ProviderError("HTTP %s from %s: %s" % (exc.code, url, raw[:300]))
    except urllib.error.URLError as exc:
        raise ProviderError("Could not reach %s: %s" % (url, exc.reason))
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        raise ProviderError("Non-JSON response from %s: %s" % (url, raw[:300]))


class ProviderError(Exception):
    pass


def now_ms():
    return int(time.time() * 1000)


def iso_from_epoch(seconds):
    return datetime.fromtimestamp(seconds, tz=timezone.utc).strftime(
        "%Y-%m-%dT%H:%M:%SZ"
    )


def pct_remaining_from_used(used):
    try:
        used = float(used)
    except (TypeError, ValueError):
        return None
    return max(0, min(100, round(100 - used)))


# --------------------------------------------------------------------------
# Claude provider
# --------------------------------------------------------------------------


class ClaudeProvider:
    name = "claude"
    # Where the `claude` CLI stores its OAuth login.
    default_cred_files = [
        Path.home() / ".claude" / ".credentials.json",
        Path.home() / ".config" / "claude" / ".credentials.json",
    ]

    @staticmethod
    def snapshot_from_cli():
        for path in ClaudeProvider.default_cred_files:
            if path.exists():
                with open(path) as fh:
                    blob = json.load(fh)
                oauth = blob.get("claudeAiOauth") or blob
                if not oauth.get("accessToken"):
                    continue
                return {
                    "access_token": oauth.get("accessToken"),
                    "refresh_token": oauth.get("refreshToken"),
                    "expires_at_ms": oauth.get("expiresAt"),
                    "subscription": oauth.get("subscriptionType"),
                    "source": str(path),
                }
        raise ProviderError(
            "No Claude login found. Run `claude` (or `claude setup-token`) and "
            "sign in first, then re-run import."
        )

    @staticmethod
    def ensure_fresh(creds):
        exp = creds.get("expires_at_ms")
        if exp and now_ms() < exp - 120_000:
            return creds, False
        refresh = creds.get("refresh_token")
        if not refresh:
            return creds, False  # Nothing we can do; let the usage call try.
        data = http_json(
            "POST",
            CLAUDE_TOKEN_URL,
            body={
                "grant_type": "refresh_token",
                "refresh_token": refresh,
                "client_id": CLAUDE_CLIENT_ID,
            },
        )
        creds = dict(creds)
        creds["access_token"] = data.get("access_token", creds["access_token"])
        if data.get("refresh_token"):
            creds["refresh_token"] = data["refresh_token"]
        if data.get("expires_in"):
            creds["expires_at_ms"] = now_ms() + int(data["expires_in"]) * 1000
        return creds, True

    @staticmethod
    def fetch_raw(creds):
        return http_json(
            "GET",
            "https://api.anthropic.com/api/oauth/usage",
            headers={
                "Authorization": "Bearer %s" % creds["access_token"],
                "anthropic-beta": "oauth-2025-04-20",
                "User-Agent": CLAUDE_USER_AGENT,
            },
        )

    @staticmethod
    def normalize(raw):
        windows = []
        for key, name in (("five_hour", "session"), ("seven_day", "weekly")):
            block = raw.get(key)
            if not isinstance(block, dict):
                continue
            windows.append(
                {
                    "name": name,
                    "pct_remaining": _claude_pct(block),
                    "resets_at": _claude_reset(block),
                }
            )
        return windows


def _claude_pct(block):
    for key in ("utilization", "used_percent", "usage_percent", "percent_used"):
        if key in block and block[key] is not None:
            return pct_remaining_from_used(block[key])
    for key in ("remaining_percent", "percent_remaining"):
        if key in block and block[key] is not None:
            try:
                return max(0, min(100, round(float(block[key]))))
            except (TypeError, ValueError):
                pass
    return None


def _claude_reset(block):
    for key in ("resets_at", "reset_at", "resetsAt"):
        if block.get(key):
            return _to_iso(block[key])
    for key in ("resets_in_seconds", "seconds_until_reset"):
        if block.get(key) is not None:
            return iso_from_epoch(time.time() + float(block[key]))
    return ""


# --------------------------------------------------------------------------
# Codex (ChatGPT plan) provider
# --------------------------------------------------------------------------


class CodexProvider:
    name = "codex"
    default_cred_files = [
        Path(os.environ.get("CODEX_HOME", Path.home() / ".codex")) / "auth.json",
    ]

    @staticmethod
    def snapshot_from_cli():
        for path in CodexProvider.default_cred_files:
            if path.exists():
                with open(path) as fh:
                    blob = json.load(fh)
                tokens = blob.get("tokens") or {}
                if not tokens.get("access_token"):
                    continue
                return {
                    "access_token": tokens.get("access_token"),
                    "refresh_token": tokens.get("refresh_token"),
                    "account_id": tokens.get("account_id"),
                    "last_refresh": blob.get("last_refresh"),
                    "source": str(path),
                }
        raise ProviderError(
            "No Codex login found. Run `codex login` first, then re-run import."
        )

    @staticmethod
    def ensure_fresh(creds):
        last = creds.get("last_refresh")
        stale = True
        if last:
            try:
                dt = datetime.fromisoformat(last.replace("Z", "+00:00"))
                stale = (datetime.now(timezone.utc) - dt).days >= 7
            except ValueError:
                stale = True
        if not stale:
            return creds, False
        refresh = creds.get("refresh_token")
        if not refresh:
            return creds, False
        data = http_json(
            "POST",
            CODEX_TOKEN_URL,
            body={
                "grant_type": "refresh_token",
                "refresh_token": refresh,
                "client_id": CODEX_CLIENT_ID,
            },
        )
        creds = dict(creds)
        creds["access_token"] = data.get("access_token", creds["access_token"])
        if data.get("refresh_token"):
            creds["refresh_token"] = data["refresh_token"]
        creds["last_refresh"] = datetime.now(timezone.utc).isoformat()
        return creds, True

    @staticmethod
    def fetch_raw(creds):
        return http_json(
            "GET",
            "https://chatgpt.com/backend-api/wham/usage",
            headers={"Authorization": "Bearer %s" % creds["access_token"]},
        )

    @staticmethod
    def normalize(raw):
        rate = raw.get("rate_limit", raw)
        windows = []
        for key, name in (("primary_window", "session"), ("secondary_window", "weekly")):
            block = rate.get(key)
            if not isinstance(block, dict):
                continue
            windows.append(
                {
                    "name": name,
                    "pct_remaining": _codex_pct(block),
                    "resets_at": _codex_reset(block),
                }
            )
        return windows


def _codex_pct(block):
    for key in ("used_percent", "usage_percent", "utilization", "percent_used"):
        if key in block and block[key] is not None:
            return pct_remaining_from_used(block[key])
    return None


def _codex_reset(block):
    for key in ("resets_at", "reset_at"):
        if block.get(key):
            return _to_iso(block[key])
    for key in ("resets_in_seconds", "reset_after_seconds", "seconds_until_reset"):
        if block.get(key) is not None:
            return iso_from_epoch(time.time() + float(block[key]))
    return ""


PROVIDERS = {p.name: p for p in (ClaudeProvider, CodexProvider)}


def provider_for(acct):
    prov = PROVIDERS.get(acct["provider"])
    if prov is None:
        sys.exit("Account '%s' has unknown provider '%s'." % (acct["id"], acct["provider"]))
    return prov


def _to_iso(value):
    """Coerce a reset value (ISO string or epoch seconds/ms) to ISO-8601 Z."""
    if isinstance(value, (int, float)):
        seconds = value / 1000.0 if value > 1e12 else float(value)
        return iso_from_epoch(seconds)
    if isinstance(value, str):
        try:
            dt = datetime.fromisoformat(value.replace("Z", "+00:00"))
            return dt.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
        except ValueError:
            return value
    return ""


# --------------------------------------------------------------------------
# Core: turn an account into a normalized display record
# --------------------------------------------------------------------------


def build_account_record(cfg, acct):
    provider = provider_for(acct)
    record = {
        "id": acct["id"],
        "label": acct.get("label", acct["id"]),
        "provider": acct["provider"],
        "color": acct.get("color", DEFAULT_COLORS.get(acct["provider"], "#8a8a90")),
        "ok": False,
        "windows": [],
    }
    creds = read_creds(acct["id"])
    if creds is None:
        record["error"] = "not imported — run `import %s`" % acct["id"]
        return record, None
    try:
        creds, changed = provider.ensure_fresh(creds)
        if changed:
            write_creds(acct["id"], creds)
        raw = provider.fetch_raw(creds)
        record["windows"] = [w for w in provider.normalize(raw) if w["pct_remaining"] is not None]
        record["ok"] = len(record["windows"]) > 0
        if not record["ok"]:
            record["error"] = "no usable windows in provider response"
        return record, raw
    except ProviderError as exc:
        record["error"] = str(exc)
        return record, None


def build_payload(cfg):
    accounts = []
    for acct in cfg["accounts"]:
        rec, _ = build_account_record(cfg, acct)
        accounts.append(rec)
    return {
        "generated_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "accounts": accounts,
    }


# --------------------------------------------------------------------------
# Commands
# --------------------------------------------------------------------------


def cmd_import(cfg, args):
    acct = account_or_die(cfg, args.account_id)
    provider = provider_for(acct)
    creds = provider.snapshot_from_cli()
    write_creds(acct["id"], creds)
    print(
        "Imported %s login for '%s' from %s\nStored at %s"
        % (acct["provider"], acct["id"], creds.get("source"), cred_path(acct["id"]))
    )


def cmd_fetch(cfg, args):
    acct = account_or_die(cfg, args.account_id)
    rec, raw = build_account_record(cfg, acct)
    if args.raw:
        print(json.dumps(raw, indent=2) if raw is not None else "(no response)")
    else:
        print(json.dumps(rec, indent=2))
    if not rec["ok"]:
        sys.exit(1)


def cmd_list(cfg, args):
    for acct in cfg["accounts"]:
        have = "yes" if read_creds(acct["id"]) else "NO"
        print("%-16s provider=%-7s imported=%s" % (acct["id"], acct["provider"], have))


def cmd_serve(cfg, args):
    host = args.host or cfg["server"].get("host", "127.0.0.1")
    port = args.port or int(cfg["server"].get("port", 8080))
    ttl = int(cfg["server"].get("cache_seconds", 60))
    cache = {"at": 0.0, "payload": None}

    class Handler(http.server.BaseHTTPRequestHandler):
        def log_message(self, *a):
            pass

        def do_GET(self):
            if self.path.split("?")[0] not in ("/", "/usage.json"):
                self.send_error(404)
                return
            age = time.time() - cache["at"]
            if cache["payload"] is None or age > ttl:
                try:
                    cache["payload"] = build_payload(cfg)
                    cache["at"] = time.time()
                except Exception as exc:  # keep the server up no matter what
                    self.send_error(500, str(exc))
                    return
            body = json.dumps(cache["payload"]).encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

    class Server(socketserver.ThreadingMixIn, http.server.HTTPServer):
        daemon_threads = True
        allow_reuse_address = True

    print("Serving usage JSON on http://%s:%d/usage.json (cache %ss)" % (host, port, ttl))
    Server((host, port), Handler).serve_forever()


def main(argv=None):
    parser = argparse.ArgumentParser(description="ai_usage helper service")
    sub = parser.add_subparsers(dest="cmd", required=True)

    p = sub.add_parser("import", help="snapshot the current CLI login into an account slot")
    p.add_argument("account_id")
    p.set_defaults(func=cmd_import)

    p = sub.add_parser("fetch", help="fetch + normalize usage for one account")
    p.add_argument("account_id")
    p.add_argument("--raw", action="store_true", help="dump the raw provider response")
    p.set_defaults(func=cmd_fetch)

    p = sub.add_parser("list", help="list configured accounts and import status")
    p.set_defaults(func=cmd_list)

    p = sub.add_parser("serve", help="serve aggregated usage.json for the Pixlet app")
    p.add_argument("--host")
    p.add_argument("--port", type=int)
    p.set_defaults(func=cmd_serve)

    args = parser.parse_args(argv)
    cfg = load_config()
    args.func(cfg, args)


if __name__ == "__main__":
    main()
