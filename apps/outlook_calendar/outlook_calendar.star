"""
Outlook Calendar
Shows today's meetings (time + title) from a published Outlook/Office 365
calendar ICS feed.

Setup:
  Outlook.com / Office 365 -> Settings -> Calendar -> Shared calendars ->
  "Publish a calendar" -> copy the ICS link -> paste it as the ics_url
  config value for this app.
"""

load("http.star", "http")
load("render.star", "render")
load("schema.star", "schema")
load("time.star", "time")

DEFAULT_TIMEZONE = "America/New_York"
CACHE_TTL_SECONDS = 900
TIME_COL_WIDTH = 28
ROW_HEIGHT = 6

def main(config):
    ics_url = config.str("ics_url", "")
    tz = config.str("timezone", DEFAULT_TIMEZONE)

    if ics_url == "":
        return render.Root(
            child = render.Box(
                child = render.WrappedText(
                    content = "Set ics_url in app config",
                    font = "tom-thumb",
                    align = "center",
                ),
            ),
        )

    now_local = time.now().in_location(tz)
    events = get_todays_events(ics_url, tz, now_local)

    header = now_local.format("Mon Jan 2")

    if len(events) == 0:
        body = render.Box(
            child = render.WrappedText(
                content = "No meetings today",
                font = "tom-thumb",
                align = "center",
            ),
        )
    else:
        rows = []
        for e in events:
            rows.append(
                render.Row(
                    cross_align = "center",
                    children = [
                        render.Box(
                            width = TIME_COL_WIDTH,
                            height = ROW_HEIGHT,
                            child = render.Text(e["time_str"], font = "tom-thumb", color = "#7cf"),
                        ),
                        render.Marquee(
                            width = 64 - TIME_COL_WIDTH,
                            height = ROW_HEIGHT,
                            child = render.Text(e["summary"], font = "tom-thumb"),
                        ),
                    ],
                ),
            )
        body = render.Column(children = rows)

    return render.Root(
        delay = 32,
        child = render.Column(
            children = [
                render.Box(
                    height = 6,
                    child = render.Text(header, font = "tom-thumb", color = "#f80"),
                ),
                body,
            ],
        ),
    )

def get_todays_events(ics_url, tz, now_local):
    res = http.get(ics_url, ttl_seconds = CACHE_TTL_SECONDS)
    if res.status_code != 200:
        return []

    lines = unfold_ics(res.body())
    raw_events = parse_events(lines)

    out = []
    for ev in raw_events:
        if "dtstart" not in ev:
            continue

        start, all_day = parse_ics_time(ev["dtstart"], ev.get("dtstart_params", {}), tz)
        if start == None:
            continue

        if start.year != now_local.year or start.month != now_local.month or start.day != now_local.day:
            continue

        time_str = "all day" if all_day else start.format("3:04PM").lower()
        out.append({
            "start": start,
            "time_str": time_str,
            "summary": ev.get("summary", "(no title)"),
        })

    return sorted(out, key = lambda e: e["start"])

def unfold_ics(text):
    """RFC5545 line unfolding: lines starting with a space/tab continue the previous line."""
    text = text.replace("\r\n", "\n")
    lines = text.split("\n")
    unfolded = []
    for line in lines:
        if (line.startswith(" ") or line.startswith("\t")) and len(unfolded) > 0:
            unfolded[-1] = unfolded[-1] + line[1:]
        else:
            unfolded.append(line)
    return unfolded

def parse_events(lines):
    events = []
    current = None
    for line in lines:
        if line == "BEGIN:VEVENT":
            current = {}
        elif line == "END:VEVENT":
            if current != None:
                events.append(current)
            current = None
        elif current != None and ":" in line:
            idx = line.find(":")
            key_part = line[:idx]
            value = line[idx + 1:]
            parts = key_part.split(";")
            key = parts[0]

            params = {}
            for p in parts[1:]:
                if "=" in p:
                    pk, pv = p.split("=", 1)
                    params[pk] = pv

            if key == "SUMMARY":
                current["summary"] = value
            elif key == "DTSTART":
                current["dtstart"] = value
                current["dtstart_params"] = params
            elif key == "DTEND":
                current["dtend"] = value
                current["dtend_params"] = params

    return events

def parse_ics_time(value, params, tz):
    """Best-effort ICS datetime parsing. Handles UTC ('...Z') and all-day
    (VALUE=DATE) forms reliably. Floating/TZID timestamps are assumed to
    already be in the configured timezone."""
    value = value.strip()

    if params.get("VALUE") == "DATE" or len(value) == 8:
        t = time.parse_time(value, format = "20060102", location = tz)
        return t, True

    if value.endswith("Z"):
        t = time.parse_time(value, format = "20060102T150405Z", location = "UTC")
        return t.in_location(tz), False

    t = time.parse_time(value, format = "20060102T150405", location = tz)
    return t, False

def get_schema():
    return schema.Schema(
        version = "1",
        fields = [
            schema.Text(
                id = "ics_url",
                name = "Outlook ICS Feed URL",
                desc = "Published calendar link from Outlook/Office 365 (Settings > Calendar > Shared calendars > Publish a calendar).",
                icon = "calendar",
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
