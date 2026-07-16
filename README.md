# tronbyt-apps

Custom [Pixlet](https://github.com/tidbyt/pixlet) apps for a Tronbyt device.

## Setup

Install `pixlet` (requires Go, plus libwebp for image handling):

```sh
# Debian/Ubuntu
sudo apt-get install -y libwebp-dev

GOBIN=/usr/local/bin go install tidbyt.dev/pixlet@latest
```

## Apps

An Outlook calendar app was attempted but dropped because the org's
Microsoft 365 tenant locks down both public ICS calendar publishing and
external app logins (OAuth), leaving no viable way to pull calendar data.

### `apps/traffic_home`

Shows live drive time (with current traffic delay) from a starting point to
home, using the [TomTom Routing API](https://developer.tomtom.com).

**Get your API key:**

1. Sign up for a free account at https://developer.tomtom.com (no card
   required).
2. Create an API key from your dashboard.

Treat the key like a credential — don't commit it to this repo.

**Render locally:**

```sh
pixlet render apps/traffic_home/traffic_home.star \
  origin='{"lat":"40.7128","lng":"-74.0060","description":"Work"}' \
  home='{"lat":"40.6892","lng":"-74.0445","description":"Home"}' \
  api_key="your-tomtom-api-key" \
  -o preview.webp
```

**Push to your device:**

```sh
pixlet push <device-id> apps/traffic_home/traffic_home.star \
  origin='{"lat":"40.7128","lng":"-74.0060","description":"Work"}' \
  home='{"lat":"40.6892","lng":"-74.0445","description":"Home"}' \
  api_key="your-tomtom-api-key"
```

**Config fields:**

| field      | description                                       | default            |
|------------|----------------------------------------------------|--------------------|
| `origin`   | Starting location (address search in app config)   | *(required)*       |
| `home`     | Home location (address search in app config)       | *(required)*       |
| `api_key`  | TomTom API key                                      | *(required)*       |
| `timezone` | IANA timezone name, used for the ETA clock          | `America/New_York` |

**Notes / limitations:**

- Route/traffic data is cached for 5 minutes (`ttl_seconds`) to stay well
  within TomTom's free-tier rate limits.
- Display shows drive time, a status dot + delay (green/clear, yellow/+Xm,
  red/+Xm for 15+ min delays), and the estimated arrival clock time.

### `apps/ai_usage`

Shows session usage remaining for several AI accounts (e.g. two Claude accounts
+ a work ChatGPT/Codex account) as compact color-coded bars, each with a
percentage and reset time.

The numbers are fetched automatically, the same way the community menu-bar apps
(ClaudeBar, CodexBar) do it: a small companion **helper** service reuses the
OAuth login from the official `claude` / `codex` CLIs, keeps the tokens
refreshed, calls each provider's private usage endpoint, and serves one
aggregated `usage.json`. This Pixlet app just fetches that JSON and draws it —
no tokens ever touch the display. See
[`apps/ai_usage/helper/`](apps/ai_usage/helper/) for the service and setup.

```
┌──────────────┐   OAuth usage    ┌─────────┐  usage.json   ┌─────────────┐
│ helper       │◀────endpoints───▶│ Anthropic│              │ Tronbyt/    │
│ (this repo)  │                  │ / OpenAI │◀── fetch ─────│ ai_usage app│
└──────────────┘                                             └─────────────┘
```

**Render locally** (against a helper running on this machine):

```sh
apps/ai_usage/helper/ai_usage_helper.py serve &   # serves :8080/usage.json
pixlet render apps/ai_usage/ai_usage.star \
  usage_url="http://127.0.0.1:8080/usage.json" \
  -o preview.webp
```

**Push to your device:**

```sh
pixlet push <device-id> apps/ai_usage/ai_usage.star \
  usage_url="http://<helper-host>:8080/usage.json"
```

**Config fields:**

| field       | description                                    | default                          |
|-------------|------------------------------------------------|----------------------------------|
| `usage_url` | URL of the helper's aggregated JSON endpoint   | `http://localhost:8080/usage.json` |
| `timezone`  | IANA timezone for reset times                  | `America/New_York`               |

**Notes / limitations:**

- Bar fill uses each account's color; it flips to amber below 25% and red
  below 10% remaining.
- The provider usage endpoints are private/undocumented and can change — see
  the helper README for how to re-check them.
- Gemini isn't supported: its consumer app has no comparable usage endpoint.

## Adding a new app

Create a new folder under `apps/<name>/<name>.star` and use `pixlet render`
to iterate locally before pushing to the device.
