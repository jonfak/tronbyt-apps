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

### `apps/outlook_calendar`

Shows today's meetings (time + title) from a published Outlook / Office 365
calendar feed.

**Get your ICS feed URL:**

1. In Outlook (outlook.office.com or outlook.com), go to **Settings → Calendar
   → Shared calendars**.
2. Under **Publish a calendar**, pick the calendar and permission level
   (*Can view all details*), click **Publish**.
3. Copy the **ICS** link (not the HTML link).

This URL is effectively a bearer secret (anyone with it can read your
calendar), so treat it like a credential — don't commit it to this repo.

**Render locally:**

```sh
pixlet render apps/outlook_calendar/outlook_calendar.star \
  ics_url="https://outlook.office365.com/owa/calendar/.../calendar.ics" \
  timezone="America/New_York" \
  -o preview.webp
```

**Push to your device:**

```sh
pixlet push <device-id> apps/outlook_calendar/outlook_calendar.star \
  ics_url="https://outlook.office365.com/owa/calendar/.../calendar.ics" \
  timezone="America/New_York"
```

(For a self-hosted Tronbyt server, push via its API/UI per its own docs — the
`.star` file and config values above are what it needs.)

**Config fields:**

| field      | description                                             | default            |
|------------|----------------------------------------------------------|--------------------|
| `ics_url`  | Published Outlook calendar ICS URL                       | *(required)*       |
| `timezone` | IANA timezone name, e.g. `America/New_York`              | `America/New_York` |

**Notes / limitations:**

- Only events for "today" (in the configured timezone) are shown, sorted by
  start time. All-day events show as "all day" first.
- Reliable for events published in UTC (`...Z` timestamps) and all-day events,
  which is how Outlook's published ICS feed normally emits them. Events with a
  Windows `TZID` (e.g. `TZID=Eastern Standard Time`) are assumed to already be
  in the configured timezone rather than converted, since Go's tz database
  doesn't recognize Windows zone names.
- The feed is cached for 15 minutes (`ttl_seconds`) to avoid hammering
  Outlook's servers.
- Long meeting titles scroll horizontally in place; the time column and other
  rows stay fixed.

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

## Adding a new app

Create a new folder under `apps/<name>/<name>.star` and use `pixlet render`
to iterate locally before pushing to the device.
