"""
AI Usage
Shows session usage remaining for three AI accounts (e.g. Claude personal,
Claude work, Gemini personal) as bars, along with each session's reset time.

There's no official API for consumer chat quotas (claude.ai / gemini.google.com
session limits), so the numbers are entered manually: check each account's
usage indicator occasionally and update this app's config with the percentage
remaining and reset time.
"""

load("render.star", "render")
load("schema.star", "schema")

BG_COLOR = "#111"
BAR_BG_COLOR = "#333"
ROW_HEIGHT = 10
BAR_WIDTH = 64

ACCOUNTS = [
    {"label": "P", "pct_id": "claude_personal_pct", "reset_id": "claude_personal_reset"},
    {"label": "W", "pct_id": "claude_work_pct", "reset_id": "claude_work_reset"},
    {"label": "G", "pct_id": "gemini_pct", "reset_id": "gemini_reset"},
]

def main(config):
    rows = [account_row(config, acct) for acct in ACCOUNTS]

    return render.Root(
        child = render.Stack(
            children = [
                render.Box(color = BG_COLOR),
                render.Column(children = rows),
            ],
        ),
    )

def account_row(config, acct):
    pct = parse_pct(config.str(acct["pct_id"], "100"))
    reset = config.str(acct["reset_id"], "--:--")
    bar_color = pct_color(pct)
    fill_width = max(1, BAR_WIDTH * pct // 100) if pct > 0 else 0

    bg_children = [render.Box(width = BAR_WIDTH, height = ROW_HEIGHT - 1, color = BAR_BG_COLOR)]
    if fill_width > 0:
        bg_children.append(render.Box(width = fill_width, height = ROW_HEIGHT - 1, color = bar_color))
    bg_children.append(
        render.Padding(
            pad = (1, 1, 0, 0),
            child = render.Text(
                "%s %d%% %s" % (acct["label"], pct, reset),
                font = "tom-thumb",
                color = "#fff",
            ),
        ),
    )

    return render.Box(
        width = BAR_WIDTH,
        height = ROW_HEIGHT,
        child = render.Stack(children = bg_children),
    )

def parse_pct(raw):
    pct = int(raw) if raw.isdigit() else 100
    if pct < 0:
        return 0
    if pct > 100:
        return 100
    return pct

def pct_color(pct):
    if pct <= 20:
        return "#f33"
    if pct <= 50:
        return "#fc3"
    return "#3f3"

def get_schema():
    return schema.Schema(
        version = "1",
        fields = [
            schema.Text(
                id = "claude_personal_pct",
                name = "Claude (Personal) % Remaining",
                desc = "From claude.ai Settings > Usage.",
                icon = "percent",
                default = "100",
            ),
            schema.Text(
                id = "claude_personal_reset",
                name = "Claude (Personal) Reset Time",
                desc = "e.g. 15:15",
                icon = "clock",
                default = "--:--",
            ),
            schema.Text(
                id = "claude_work_pct",
                name = "Claude (Work) % Remaining",
                desc = "From claude.ai Settings > Usage.",
                icon = "percent",
                default = "100",
            ),
            schema.Text(
                id = "claude_work_reset",
                name = "Claude (Work) Reset Time",
                desc = "e.g. 15:15",
                icon = "clock",
                default = "--:--",
            ),
            schema.Text(
                id = "gemini_pct",
                name = "Gemini % Remaining",
                desc = "From the Gemini app's usage indicator.",
                icon = "percent",
                default = "100",
            ),
            schema.Text(
                id = "gemini_reset",
                name = "Gemini Reset Time",
                desc = "e.g. 15:15",
                icon = "clock",
                default = "--:--",
            ),
        ],
    )
