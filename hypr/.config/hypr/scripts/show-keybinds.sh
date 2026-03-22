#!/bin/sh
# Show Hyprland keybindings in a floating kitty terminal as a two-column grid.
# When called without args: spawns floating kitty.
# When called with --display: renders the grid (called by kitty).

if [ "$1" != "--display" ]; then
    kitty --class keybind-helper -e "$0" --display
    exit 0
fi

python3 << 'PYEOF'
import os, re, sys, shutil

CONF = os.path.expanduser("~/.config/hypr/conf.d/keybindings.conf")

GROUPS = {
    "Switch workspaces":   ("Super + 1-0",           "Workspaces 1–10"),
    "Move active window":  ("Super + Shift + 1-0",   "Move window to workspace"),
    "Move focus with":     ("Super + Arrows",        "Move focus"),
    "Scroll through":      ("Super + Scroll",        "Cycle workspaces"),
    "Move/resize windows": ("Super + LMB / RMB",     "Move / resize windows"),
}
SKIP_SECTIONS = ("Laptop multimedia", "Requires playerctl")
SKIP_COMMENTS = ("See ", "Example binds", 'Sets "', "KEYBINDINGS", "Example special")

FRIENDLY_DISPATCH = {
    "killactive":            "Close window",
    "togglefloating":        "Toggle floating",
    "pseudo":                "Pseudo tiling",
    "togglesplit":           "Toggle split",
    "togglespecialworkspace": "Toggle scratchpad",
}
FRIENDLY_EXEC = {
    "$terminal":    "Terminal",
    "$fileManager": "File manager",
}

def parse():
    entries = []
    comment = ""
    skip = False

    with open(CONF) as f:
        for raw in f:
            line = raw.strip()

            if not line:
                skip = False
                comment = ""
                continue

            if line.startswith("#"):
                text = re.sub(r"^#+ *", "", line)
                if any(text.startswith(s) for s in SKIP_COMMENTS):
                    continue
                if text.startswith("bind"):
                    continue
                for pat in SKIP_SECTIONS:
                    if pat in text:
                        skip = True
                        break
                else:
                    for pat, val in GROUPS.items():
                        if pat in text:
                            skip = True
                            entries.append(val)
                            break
                    else:
                        comment = text
                continue

            if not line.startswith("bind") or skip:
                continue

            line = re.sub(r"^bind\w*\s*=\s*", "", line)
            parts = [p.strip() for p in line.split(",")]
            if len(parts) < 3:
                comment = ""
                continue

            mods, key, action = parts[0], parts[1], parts[2]
            args = " ".join(p for p in parts[3:] if p)
            args = re.sub(r"#.*$", "", args).strip()

            if "mouse" in key.lower() or "XF86" in key:
                comment = ""
                continue

            mods = (mods.replace("$mainMod", "Super")
                        .replace("SHIFT", "Shift")
                        .replace("ALT_L", "Alt"))
            key = key.replace("RETURN", "Return").replace("SPACE", "Space")
            keys = " + ".join(mods.split() + [key]) if mods else key

            if comment:
                desc = comment
                comment = ""
            elif action == "exec":
                desc = FRIENDLY_EXEC.get(args)
                if not desc:
                    cmd = args.split("|")[0].strip()
                    prog = re.sub(r".*/|\.sh$", "", cmd.split()[0]) if cmd else action
                    desc = prog.replace("-", " ").title()
            elif action in FRIENDLY_DISPATCH:
                desc = FRIENDLY_DISPATCH[action]
            elif action == "movetoworkspace":
                desc = "Move to scratchpad" if "special:" in args else f"Move to workspace {args}"
            else:
                desc = f"{action} {args}".strip() if args else action

            entries.append((keys, desc))

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
