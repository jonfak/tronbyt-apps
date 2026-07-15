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

No apps yet — an Outlook calendar app was attempted but dropped because the
org's Microsoft 365 tenant locks down both public ICS calendar publishing and
external app logins (OAuth), leaving no viable way to pull calendar data.

### `apps/weather_forecast`

Shows today's weather full-screen (current temp, icon, high/low), then
slides into a 3-up view with today plus the next two days side by side,
using the free [Open-Meteo API](https://open-meteo.com/en/docs) — no API
key required.

**Render locally:**

```sh
pixlet render apps/weather_forecast/weather_forecast.star \
  location='{"lat":"40.7128","lng":"-74.0060","description":"New York, NY"}' \
  -o preview.webp
```

**Push to your device:**

```sh
pixlet push <device-id> apps/weather_forecast/weather_forecast.star \
  location='{"lat":"40.7128","lng":"-74.0060","description":"New York, NY"}'
```

**Config fields:**

| field      | description                                  | default        |
|------------|-----------------------------------------------|----------------|
| `location` | Where to fetch the forecast for (address search) | *(required)* |
| `units`    | `fahrenheit` or `celsius`                      | `fahrenheit`   |

**Notes / limitations:**

- Forecast data is cached for 30 minutes (`ttl_seconds`).
- Weather icons are small pre-rendered PNGs embedded as base64 in the app,
  covering the WMO weather code groups Open-Meteo returns (clear, partly
  cloudy, cloudy, fog, rain, snow, thunderstorm).

### `apps/traffic_home`

Animates the route from a starting point to home being "driven," colored
green/yellow/red by live traffic along each stretch of road, using the
[TomTom Routing API](https://developer.tomtom.com). ETA, delay, and
estimated arrival time stay pinned in the corners.

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
- The route "draws" itself over ~2 seconds, then holds the full map for a
  few seconds before looping. Each stretch of road is colored by TomTom's
  live traffic magnitude for that segment (green/yellow/red), with a start
  marker and a home marker. ETA, delay, and estimated arrival clock time are
  pinned in the corners throughout.
- The map is a rough shape at this resolution — useful for "is my route
  mostly clear," not turn-by-turn detail.

## Adding a new app

Create a new folder under `apps/<name>/<name>.star` and use `pixlet render`
to iterate locally before pushing to the device.
