# ai_usage helper

Companion service for the `ai_usage` Tronbyt app. It holds each account's
OAuth login, keeps the tokens refreshed, calls each provider's usage endpoint,
and serves one aggregated `usage.json` that the Pixlet app renders.

**Nothing here handles a password.** It reuses the OAuth login that the
official `claude` / `codex` CLIs already created. Tokens are stored locally
(default `~/.config/ai-usage-helper/creds/`, mode `0600`) and only ever sent
back to Anthropic / OpenAI.

## Why a helper instead of doing it in the Pixlet app

Consumer AI plans don't expose usage over a public API — the only usage
endpoints are the private ones the CLIs call, and their access tokens expire
roughly hourly and must be refreshed with a rotating refresh token. A Pixlet
app is a stateless render, so it can't hold or refresh a token. The helper owns
that lifecycle; the display just reads the resulting JSON.

## Providers

| provider | login with        | usage endpoint                                  |
|----------|-------------------|-------------------------------------------------|
| `claude` | `claude` CLI      | `api.anthropic.com/api/oauth/usage`             |
| `codex`  | `codex login`     | `chatgpt.com/backend-api/wham/usage` (ChatGPT)  |

Each returns a **session** (5-hour rolling) window and a **weekly** window with
a percent and a reset time. The display shows the session window.

## Requirements

- Python 3.11+ (uses `tomllib`; stdlib only, no `pip install`).
- The official CLI for each provider you track, logged in.

## Setup

```sh
cd apps/ai_usage/helper
cp accounts.example.toml accounts.toml   # edit ids / labels / colors
```

Import each account. Because each CLI only holds one login at a time, do them
one at a time — log in, import, then switch accounts:

```sh
# 1) Personal Claude
claude            # sign in as your personal account (or: claude setup-token)
./ai_usage_helper.py import claude_personal

# 2) Work Claude — sign out / sign in as work, then:
claude
./ai_usage_helper.py import claude_work

# 3) Work ChatGPT/Codex
codex login
./ai_usage_helper.py import codex_work
```

Check it works:

```sh
./ai_usage_helper.py list                 # which accounts are imported
./ai_usage_helper.py fetch claude_personal # normalized usage for one account
./ai_usage_helper.py fetch codex_work --raw # the untouched provider response
```

Run the server the Pixlet app talks to:

```sh
./ai_usage_helper.py serve                # http://127.0.0.1:8080/usage.json
```

Then point the app's **Helper URL** config at that endpoint. If the Tronbyt
server runs on a different machine than the helper, set `host = "0.0.0.0"` in
`accounts.toml` and use the helper machine's LAN address in the app config.

## Running it alongside the Tronbyt server

systemd unit (adjust paths / user):

```ini
# /etc/systemd/system/ai-usage-helper.service
[Unit]
Description=ai_usage helper
After=network-online.target

[Service]
ExecStart=/usr/bin/python3 /path/to/apps/ai_usage/helper/ai_usage_helper.py serve
WorkingDirectory=/path/to/apps/ai_usage/helper
Restart=always
User=youruser

[Install]
WantedBy=multi-user.target
```

```sh
sudo systemctl enable --now ai-usage-helper
```

## Config / env

- `accounts.toml` next to the script (override with `AI_USAGE_ACCOUNTS`).
- Credential + state dir: `~/.config/ai-usage-helper` (override with
  `AI_USAGE_HELPER_HOME`).

## When something breaks

- **`fetch` shows an HTTP 401/400 on the token URL** — the OAuth client IDs /
  token endpoints at the top of `ai_usage_helper.py` are the public CLI values
  and are the most likely thing to have drifted. Re-check them against the
  current CLIs.
- **`no usable windows in provider response`** — the provider changed its JSON
  shape. Run `fetch <id> --raw` to see the real response and adjust the
  `normalize` / `_*_pct` / `_*_reset` helpers for that provider.
- **429s from the Claude endpoint** — it rate-limits polling. Keep
  `cache_seconds` at 60+ so the display's refreshes don't hammer it.

## Limitations

- The usage endpoints are private/undocumented; they can change without notice.
  This mirrors how the community menu-bar apps (ClaudeBar, CodexBar, …) work.
- Gemini isn't supported — its consumer app has no comparable usage endpoint.
