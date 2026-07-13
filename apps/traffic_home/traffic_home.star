"""
Traffic Home
Shows live drive time (with current traffic) from a starting point to home,
using the TomTom Routing API.

Setup:
  Get a free API key at https://developer.tomtom.com (no card required),
  then set the origin, home, and api_key config values for this app.
"""

load("http.star", "http")
load("encoding/json.star", "json")
load("render.star", "render")
load("schema.star", "schema")
load("time.star", "time")

DEFAULT_LOCATION = """
{
    "lat": "40.6781784",
    "lng": "-73.9441579",
    "description": "Brooklyn, NY",
    "locality": "Brooklyn",
    "place_id": "",
    "timezone": "America/New_York"
}
"""

DEFAULT_TIMEZONE = "America/New_York"
CACHE_TTL_SECONDS = 300
BG_COLOR = "#111"

def main(config):
    api_key = config.str("api_key", "")

    if api_key == "":
        return error_root("Set api_key in app config")

    origin = config.str("origin", DEFAULT_LOCATION)
    home = config.str("home", DEFAULT_LOCATION)
    origin_loc = json.decode(origin)
    home_loc = json.decode(home)

    if origin_loc["lat"] == home_loc["lat"] and origin_loc["lng"] == home_loc["lng"]:
        return error_root("Set origin and home locations")

    route = get_route(origin_loc, home_loc, api_key)
    if route == None:
        return error_root("Traffic data unavailable")

    travel_min = route["travel_time_s"] // 60
    delay_min = route["delay_s"] // 60

    if delay_min >= 15:
        color = "#f33"
    elif delay_min >= 5:
        color = "#fc3"
    else:
        color = "#3f3"

    status = "+%dm" % delay_min if delay_min > 0 else "clear"

    tz = config.str("timezone", DEFAULT_TIMEZONE)
    eta = time.now().in_location(tz) + time.parse_duration("%ds" % route["travel_time_s"])
    eta_str = eta.format("3:04PM").lower()

    return render.Root(
        delay = 100,
        child = render.Stack(
            children = [
                render.Box(color = BG_COLOR),
                render.Padding(
                    pad = (2, 1, 2, 1),
                    child = render.Column(
                        expanded = True,
                        main_align = "space_between",
                        children = [
                            render.Row(
                                expanded = True,
                                main_align = "space_between",
                                cross_align = "center",
                                children = [
                                    render.Text("HOME", font = "tom-thumb", color = "#7cf"),
                                    render.Circle(color = color, diameter = 5),
                                ],
                            ),
                            render.Box(
                                height = 20,
                                child = render.Text(
                                    "%dm" % travel_min,
                                    font = "10x20",
                                    color = color,
                                ),
                            ),
                            render.Row(
                                expanded = True,
                                main_align = "space_between",
                                cross_align = "center",
                                children = [
                                    render.Text(status, font = "tom-thumb", color = color),
                                    render.Text(eta_str, font = "tom-thumb", color = "#888"),
                                ],
                            ),
                        ],
                    ),
                ),
            ],
        ),
    )

def get_route(origin_loc, home_loc, api_key):
    url = "https://api.tomtom.com/routing/1/calculateRoute/%s,%s:%s,%s/json" % (
        origin_loc["lat"],
        origin_loc["lng"],
        home_loc["lat"],
        home_loc["lng"],
    )

    res = http.get(
        url,
        params = {
            "key": api_key,
            "traffic": "true",
            "computeTravelTimeFor": "all",
        },
        ttl_seconds = CACHE_TTL_SECONDS,
    )
    if res.status_code != 200:
        return None

    body = res.json()
    routes = body.get("routes", [])
    if len(routes) == 0:
        return None

    summary = routes[0]["summary"]
    return {
        "travel_time_s": summary["travelTimeInSeconds"],
        "delay_s": summary.get("trafficDelayInSeconds", 0),
    }

def error_root(msg):
    return render.Root(
        child = render.Box(
            child = render.WrappedText(
                content = msg,
                font = "tom-thumb",
                align = "center",
            ),
        ),
    )

def get_schema():
    return schema.Schema(
        version = "1",
        fields = [
            schema.Location(
                id = "origin",
                name = "Starting Point",
                desc = "Where you're commuting from (e.g. work).",
                icon = "locationDot",
            ),
            schema.Location(
                id = "home",
                name = "Home",
                desc = "Your home address.",
                icon = "house",
            ),
            schema.Text(
                id = "api_key",
                name = "TomTom API Key",
                desc = "Free API key from developer.tomtom.com.",
                icon = "key",
                default = "",
            ),
            schema.Text(
                id = "timezone",
                name = "Timezone",
                desc = "IANA timezone name, e.g. America/New_York",
                icon = "clock",
                default = DEFAULT_TIMEZONE,
            ),
        ],
    )
