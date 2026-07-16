"""
AI Usage
Shows session usage remaining for several AI accounts (e.g. two Claude
accounts + a ChatGPT/Codex account) as compact bars with a reset time.

Data comes from a small companion "helper" service that holds each account's
OAuth login (obtained from the official claude / codex CLIs), keeps the tokens
refreshed, calls each provider's usage endpoint, and serves one aggregated
JSON document. This app just fetches that JSON and draws it — no tokens ever
live in the app or on the device. See apps/ai_usage/helper/ for the service.
"""

load("http.star", "http")
load("render.star", "render")
load("schema.star", "schema")
load("time.star", "time")

DEFAULT_URL = "http://localhost:8080/usage.json"
DEFAULT_TIMEZONE = "America/New_York"
CACHE_TTL_SECONDS = 60

BG_COLOR = "#0d0d0f"
TRACK_COLOR = "#26262b"
TEXT_COLOR = "#e8e8ea"
DIM_TEXT_COLOR = "#7a7a80"

WIDTH = 64
ROW_H = 10
BAR_H = 3

def main(config):
    url = config.str("usage_url", DEFAULT_URL)
    tz = config.str("timezone", DEFAULT_TIMEZONE)

    accounts = fetch_accounts(url)
    if accounts == None:
        return error_root("Helper offline")
    if len(accounts) == 0:
        return error_root("No accounts")

    rows = [account_row(acct, tz) for acct in accounts[:3]]

    return render.Root(
        child = render.Stack(
            children = [
                render.Box(color = BG_COLOR),
                render.Padding(
                    pad = (2, 1, 2, 1),
                    child = render.Column(
                        expanded = True,
                        main_align = "space_between",
                        children = rows,
                    ),
                ),
            ],
        ),
    )

def account_row(acct, tz):
    label = acct.get("label", "?")
    accent = acct.get("color", "#8a8a90")
    window = primary_window(acct)

    if window == None:
        # Account errored or returned nothing usable.
        return render.Column(
            children = [
                text_line(label, "err", DIM_TEXT_COLOR),
                bar(0, TRACK_COLOR),
            ],
        )

    pct = clamp_pct(window.get("pct_remaining", 0))
    reset_str = format_reset(window.get("resets_at", ""), tz)
    fill = low_color(accent, pct)

    return render.Column(
        children = [
            render.Row(
                expanded = True,
                main_align = "space_between",
                cross_align = "center",
                children = [
                    render.Row(
                        cross_align = "center",
                        children = [
                            render.Text(label, font = "tom-thumb", color = accent),
                            render.Text(" %d%%" % pct, font = "tom-thumb", color = TEXT_COLOR),
                        ],
                    ),
                    render.Text(reset_str, font = "tom-thumb", color = DIM_TEXT_COLOR),
                ],
            ),
            bar(pct, fill),
        ],
    )

def bar(pct, fill_color):
    inner = WIDTH - 4  # account for outer padding
    fill_w = inner * clamp_pct(pct) // 100
    children = [render.Box(width = inner, height = BAR_H, color = TRACK_COLOR)]
    if fill_w > 0:
        children.append(render.Box(width = fill_w, height = BAR_H, color = fill_color))
    return render.Stack(children = children)

def text_line(left, right, color):
    return render.Row(
        expanded = True,
        main_align = "space_between",
        children = [
            render.Text(left, font = "tom-thumb", color = TEXT_COLOR),
            render.Text(right, font = "tom-thumb", color = color),
        ],
    )

def primary_window(acct):
    windows = acct.get("windows", [])
    if len(windows) == 0:
        return None

    # Prefer the session (5h) window — it's the one you actually bump into.
    for w in windows:
        if w.get("name", "") == "session":
            return w
    return windows[0]

def low_color(accent, pct):
    if pct <= 10:
        return "#ff4d4d"
    if pct <= 25:
        return "#ffb23e"
    return accent

def clamp_pct(v):
    n = int(v) if type(v) == "int" else int(float(v)) if is_number(v) else 0
    if n < 0:
        return 0
    if n > 100:
        return 100
    return n

def is_number(v):
    return type(v) in ("int", "float")

def format_reset(iso, tz):
    if iso == "":
        return ""
    parsed = time.parse_time(iso, format = "2006-01-02T15:04:05Z07:00")
    if parsed == None:
        return ""
    local = parsed.in_location(tz)
    return local.format("3:04pm")

def fetch_accounts(url):
    res = http.get(url, ttl_seconds = CACHE_TTL_SECONDS)
    if res.status_code != 200:
        return None
    body = res.json()
    if type(body) == "dict":
        return body.get("accounts", [])
    if type(body) == "list":
        return body
    return None

def error_root(msg):
    return render.Root(
        child = render.Box(
            color = BG_COLOR,
            child = render.WrappedText(
                content = msg,
                font = "tom-thumb",
                align = "center",
                color = TEXT_COLOR,
            ),
        ),
    )

def get_schema():
    return schema.Schema(
        version = "1",
        fields = [
            schema.Text(
                id = "usage_url",
                name = "Helper URL",
                desc = "URL of the ai_usage helper's JSON endpoint.",
                icon = "link",
                default = DEFAULT_URL,
            ),
            schema.Text(
                id = "timezone",
                name = "Timezone",
                desc = "IANA timezone for reset times, e.g. America/New_York",
                icon = "clock",
                default = DEFAULT_TIMEZONE,
            ),
        ],
    )
