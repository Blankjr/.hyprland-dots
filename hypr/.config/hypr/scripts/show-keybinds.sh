#!/bin/sh
# Show Hyprland keybindings in a floating kitty terminal as a two-column grid.
# When called without args: toggles the floating kitty window.
# When called with --display: renders the grid (called by kitty).

if [ "$1" != "--display" ]; then
    address=$(hyprctl clients -j | jq -r '
        [.[] | select(
            .class == "keybind-helper" or
            .initialClass == "keybind-helper"
        ) | .address][0] // empty
    ')

    if [ -n "$address" ]; then
        hyprctl dispatch \
            "hl.dsp.window.close({ window = \"address:$address\" })" \
            >/dev/null
        exit 0
    fi

    exec kitty \
        --class keybind-helper \
        --override confirm_os_window_close=0 \
        -e "$0" --display
fi

python3 << 'PYEOF'
import json
import os
import shutil
import subprocess

GROUPED = {
    "Switch workspace": ("Super + 1–0", "Workspaces 1–10"),
    "Move window to workspace": ("Super + Shift + 1–0", "Move window to workspace"),
    "Move focus": ("Super + Arrows", "Move focus"),
    "Cycle workspaces": ("Super + Scroll", "Cycle workspaces"),
}

MODIFIERS = (
    (64, "Super"),
    (4, "Ctrl"),
    (8, "Alt"),
    (1, "Shift"),
)

KEY_NAMES = {
    "RETURN": "Return",
    "SPACE": "Space",
    "TAB": "Tab",
    "left": "Left",
    "right": "Right",
    "up": "Up",
    "down": "Down",
}

def parse():
    result = subprocess.run(
        ["hyprctl", "binds", "-j"],
        check=True,
        capture_output=True,
        text=True,
    )
    binds = json.loads(result.stdout)
    entries = []
    grouped_seen = set()

    for item in binds:
        description = item.get("description", "")
        key = item.get("key", "")
        if not description or key.startswith("XF86") or "mouse" in key.lower():
            continue

        if description in GROUPED:
            if description not in grouped_seen:
                entries.append(GROUPED[description])
                grouped_seen.add(description)
            continue

        keys = [name for mask, name in MODIFIERS if item.get("modmask", 0) & mask]
        keys.append(KEY_NAMES.get(key, key))
        entries.append((" + ".join(keys), description))

    return entries

def display(entries):
    C  = "\033[36m"
    B  = "\033[1m"
    D  = "\033[2m"
    Y  = "\033[33m"
    R  = "\033[0m"

    w = shutil.get_terminal_size((100, 40)).columns

    print()
    title = " HYPRLAND KEYBINDINGS "
    bar = "━"
    pad = (w - len(title) - 4) // 2
    print(f"  {D}{bar * pad}{R}{B}{Y}{title}{R}{D}{bar * (w - 4 - pad - len(title))}{R}")
    print()

    half = (len(entries) + 1) // 2
    left  = entries[:half]
    right = entries[half:]

    col_w  = (w - 7) // 2
    key_w  = min(26, col_w // 2)
    desc_w = col_w - key_w

    for i in range(half):
        lk, ld = left[i]
        if len(ld) > desc_w - 1:
            ld = ld[:desc_w - 3] + "…"
        s = f"  {C}{B}{lk:<{key_w}}{R} {ld:<{desc_w}}"
        if i < len(right):
            rk, rd = right[i]
            if len(rd) > desc_w - 1:
                rd = rd[:desc_w - 3] + "…"
            s += f"{D}│{R} {C}{B}{rk:<{key_w}}{R} {rd}"
        print(s)

    print(f"\n  {D}Press q or Esc to close…{R}", flush=True)

    import tty, termios
    tty_fd = os.open("/dev/tty", os.O_RDONLY)
    tty_file = os.fdopen(tty_fd, "r")
    old = termios.tcgetattr(tty_fd)
    try:
        tty.setraw(tty_fd)
        while True:
            ch = tty_file.read(1)
            if ch in ("q", "Q", "\x1b", "\r", "\n", " "):
                break
    finally:
        termios.tcsetattr(tty_fd, termios.TCSADRAIN, old)
        tty_file.close()

entries = parse()
display(entries)
PYEOF
