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

CACHE_TTL_SECONDS = 300

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

    color = "#3f3"
    if delay_min >= 15:
        color = "#f33"
    elif delay_min >= 5:
        color = "#fc3"

    if delay_min > 0:
        subtext = "+%d min traffic" % delay_min
    else:
        subtext = "no delay"

    return render.Root(
        child = render.Column(
            main_align = "center",
            cross_align = "center",
            expanded = True,
            children = [
                render.Text("HOME", font = "tom-thumb", color = "#7cf"),
                render.Box(height = 2, child = render.Box()),
                render.Text("%d min" % travel_min, font = "6x13", color = color),
                render.Box(height = 1, child = render.Box()),
                render.Text(subtext, font = "tom-thumb", color = color),
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
        ],
    )
