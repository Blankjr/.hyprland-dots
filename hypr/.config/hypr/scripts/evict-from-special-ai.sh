#!/usr/bin/env python3
"""Listen for windows opening on special:ai and relocate any non-AI window to
the Xiaomi (main) monitor's visible primary workspace. Keeps special:ai a
true scratchpad for the Claude Chat / T3 Chat PWAs."""
import json
import os
import re
import socket
import subprocess
import sys

AI_CLASSES = re.compile(r"^(chrome-claude\.ai__-Default|chrome-t3\.chat__-Default)$")
MAIN_MONITOR = re.compile(r"Xiaomi")

sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
if not sig:
    sys.exit("HYPRLAND_INSTANCE_SIGNATURE not set")

runtime = os.environ.get("XDG_RUNTIME_DIR", "/tmp")
sock_path = f"{runtime}/hypr/{sig}/.socket2.sock"


def main_monitor_primary_ws():
    out = subprocess.check_output(["hyprctl", "monitors", "-j"], text=True)
    for mon in json.loads(out):
        if MAIN_MONITOR.search(mon.get("description", "")):
            return mon["activeWorkspace"]["id"]
    return None


def handle(line: str) -> None:
    if not line.startswith("openwindow>>"):
        return
    parts = line[len("openwindow>>"):].split(",", 3)
    if len(parts) < 3:
        return
    addr, ws, cls = parts[0], parts[1], parts[2]
    if ws != "special:ai" or AI_CLASSES.match(cls):
        return
    target = main_monitor_primary_ws()
    if target is None:
        return
    subprocess.run(
        ["hyprctl", "dispatch", "movetoworkspacesilent", f"{target},address:0x{addr}"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
    )


with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
    s.connect(sock_path)
    with s.makefile("r", encoding="utf-8", errors="replace") as f:
        for line in f:
            handle(line.rstrip("\n"))
