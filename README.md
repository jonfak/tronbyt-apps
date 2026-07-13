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

Shows session usage remaining for three AI accounts (Claude personal, Claude
work, Gemini) as three colored bars, each with a percentage and reset time.

There's no official API for consumer chat quotas (the claude.ai / Gemini app
"messages remaining, resets at X:XX" indicator) — only API billing usage is
exposed via official APIs, and that's a separate thing from the chat app's
session limit. So the values are entered manually: check each account's
usage indicator occasionally (claude.ai: Settings > Usage) and update this
app's config.

**Render locally:**

```sh
pixlet render apps/ai_usage/ai_usage.star \
  claude_personal_pct="72" claude_personal_reset="15:15" \
  claude_work_pct="40" claude_work_reset="18:00" \
  gemini_pct="12" gemini_reset="20:30" \
  -o preview.webp
```

**Push to your device:**

```sh
pixlet push <device-id> apps/ai_usage/ai_usage.star \
  claude_personal_pct="72" claude_personal_reset="15:15" \
  claude_work_pct="40" claude_work_reset="18:00" \
  gemini_pct="12" gemini_reset="20:30"
```

**Config fields:**

| field                    | description                              | default |
|--------------------------|-------------------------------------------|---------|
| `claude_personal_pct`    | % remaining, Claude personal account       | `100`   |
| `claude_personal_reset`  | Reset time, e.g. `15:15`                   | `--:--` |
| `claude_work_pct`        | % remaining, Claude work account           | `100`   |
| `claude_work_reset`      | Reset time, e.g. `15:15`                   | `--:--` |
| `gemini_pct`             | % remaining, Gemini account                | `100`   |
| `gemini_reset`           | Reset time, e.g. `15:15`                   | `--:--` |

**Notes / limitations:**

- Values are manual — there's no automated refresh.
- Bar color: green (>50%), yellow (21-50%), red (<=20%).

## Adding a new app

Create a new folder under `apps/<name>/<name>.star` and use `pixlet render`
to iterate locally before pushing to the device.
