"""
Traffic Home
Animates the route from a starting point to home being "driven," colored
green/yellow/red by live traffic, using the TomTom Routing API. ETA and
delay are pinned in the corners.

Setup:
  Get a free API key at https://developer.tomtom.com (no card required),
  then set the origin, home, and api_key config values for this app.
"""

load("http.star", "http")
load("encoding/json.star", "json")
load("math.star", "math")
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

MAP_WIDTH = 64
MAP_HEIGHT = 32
MAX_ROUTE_POINTS = 40
REVEAL_FRAMES = 24
HOLD_FRAMES = 16
FRAME_DELAY_MS = 90

COLOR_GREEN = "#3f3"
COLOR_YELLOW = "#fc3"
COLOR_RED = "#f33"
COLOR_START = "#7cf"
COLOR_HOME = "#fff"

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
        overall_color = COLOR_RED
    elif delay_min >= 5:
        overall_color = COLOR_YELLOW
    else:
        overall_color = COLOR_GREEN

    status = "+%dm" % delay_min if delay_min > 0 else "clear"

    tz = config.str("timezone", DEFAULT_TIMEZONE)
    eta = time.now().in_location(tz) + time.parse_duration("%ds" % route["travel_time_s"])
    eta_str = eta.format("3:04PM").lower()

    points = downsample(route["points"], MAX_ROUTE_POINTS)
    if len(points) < 2:
        return error_root("Route unavailable")

    points_with_color = colorize_points(points, route["sections"])
    x_lim, y_lim = bounding_box(points)

    overlay = render.Padding(
        pad = (1, 1, 1, 1),
        child = render.Column(
            expanded = True,
            main_align = "space_between",
            children = [
                render.Row(
                    expanded = True,
                    main_align = "end",
                    children = [
                        render.Text("%dm" % travel_min, font = "tb-8", color = overall_color),
                    ],
                ),
                render.Row(
                    expanded = True,
                    main_align = "space_between",
                    children = [
                        render.Text(status, font = "tom-thumb", color = overall_color),
                        render.Text(eta_str, font = "tom-thumb", color = "#ccc"),
                    ],
                ),
            ],
        ),
    )

    frames = []
    total = len(points_with_color)
    for f in range(1, REVEAL_FRAMES + 1):
        cutoff = max(2, int(math.round(float(total) * float(f) / float(REVEAL_FRAMES))))
        frames.append(build_frame(points_with_color[:cutoff], x_lim, y_lim, overlay, cutoff == total))

    full_frame = build_frame(points_with_color, x_lim, y_lim, overlay, True)
    for _ in range(HOLD_FRAMES):
        frames.append(full_frame)

    return render.Root(
        delay = FRAME_DELAY_MS,
        child = render.Animation(children = frames),
    )

def build_frame(points_with_color, x_lim, y_lim, overlay, show_home_marker):
    layers = plot_layers(points_with_color, x_lim, y_lim)

    start_lon, start_lat, _ = points_with_color[0]
    start_px, start_py = project(start_lon, start_lat, x_lim, y_lim, MAP_WIDTH, MAP_HEIGHT)

    children = [render.Box(color = BG_COLOR)] + layers + [
        render.Padding(
            pad = (max(0, start_px - 1), max(0, start_py - 1), 0, 0),
            child = render.Circle(color = COLOR_START, diameter = 3),
        ),
    ]

    if show_home_marker:
        end_lon, end_lat, _ = points_with_color[-1]
        end_px, end_py = project(end_lon, end_lat, x_lim, y_lim, MAP_WIDTH, MAP_HEIGHT)
        children.append(
            render.Padding(
                pad = (max(0, end_px - 1), max(0, end_py - 1), 0, 0),
                child = render.Circle(color = COLOR_HOME, diameter = 3),
            ),
        )

    children.append(overlay)

    return render.Stack(children = children)

def plot_layers(points_with_color, x_lim, y_lim):
    """Groups consecutive same-colored points into Plot line segments,
    sharing a boundary point between runs so the polyline stays connected."""
    layers = []
    current_color = None
    current_pts = []

    for lon, lat, color in points_with_color:
        if color != current_color and len(current_pts) > 0:
            current_pts.append((lon, lat))
            layers.append(make_plot(current_pts, current_color, x_lim, y_lim))
            current_pts = [(lon, lat)]
        else:
            current_pts.append((lon, lat))
        current_color = color

    if len(current_pts) > 1:
        layers.append(make_plot(current_pts, current_color, x_lim, y_lim))
    elif len(current_pts) == 1:
        layers.append(render.Plot(
            data = current_pts * 2,
            width = MAP_WIDTH,
            height = MAP_HEIGHT,
            color = current_color,
            x_lim = x_lim,
            y_lim = y_lim,
            chart_type = "scatter",
        ))

    return layers

def make_plot(pts, color, x_lim, y_lim):
    return render.Plot(
        data = pts,
        width = MAP_WIDTH,
        height = MAP_HEIGHT,
        color = color,
        x_lim = x_lim,
        y_lim = y_lim,
        chart_type = "line",
    )

def project(lon, lat, x_lim, y_lim, w, h):
    nx = (lon - x_lim[0]) / (x_lim[1] - x_lim[0])
    ny = (lat - y_lim[0]) / (y_lim[1] - y_lim[0])
    px = int(math.round(nx * (w - 1)))
    py = h - 1 - int(math.round(ny * (h - 1)))
    return px, py

def bounding_box(points):
    lons = [p[0] for p in points]
    lats = [p[1] for p in points]
    min_lon, max_lon = min(lons), max(lons)
    min_lat, max_lat = min(lats), max(lats)

    lon_pad = max((max_lon - min_lon) * 0.1, 0.001)
    lat_pad = max((max_lat - min_lat) * 0.1, 0.001)

    return (min_lon - lon_pad, max_lon + lon_pad), (min_lat - lat_pad, max_lat + lat_pad)

def downsample(points, max_points):
    n = len(points)
    if n <= max_points:
        return points

    stride = n / max_points
    out = []
    i = 0.0
    while int(i) < n and len(out) < max_points - 1:
        out.append(points[int(i)])
        i += stride
    out.append(points[-1])
    return out

def colorize_points(points, sections):
    n = len(points)
    colors = [COLOR_GREEN] * n

    for s in sections:
        if s.get("sectionType") != "TRAFFIC":
            continue
        mag = s.get("magnitudeOfDelay", 0)
        if mag >= 3:
            color = COLOR_RED
        elif mag == 2:
            color = COLOR_YELLOW
        else:
            continue

        start = s.get("startPointIndex", 0)
        end = s.get("endPointIndex", 0)
        for i in range(start, end + 1):
            if i < n:
                colors[i] = color

    return [(points[i][0], points[i][1], colors[i]) for i in range(n)]

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
            "sectionType": "traffic",
        },
        ttl_seconds = CACHE_TTL_SECONDS,
    )
    if res.status_code != 200:
        return None

    body = res.json()
    routes = body.get("routes", [])
    if len(routes) == 0:
        return None

    r = routes[0]
    summary = r["summary"]

    points = []
    for leg in r.get("legs", []):
        for p in leg.get("points", []):
            points.append((p["longitude"], p["latitude"]))

    return {
        "travel_time_s": summary["travelTimeInSeconds"],
        "delay_s": summary.get("trafficDelayInSeconds", 0),
        "points": points,
        "sections": r.get("sections", []),
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
