# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Hyprland desktop environment dotfiles for CachyOS (Arch-based), managed with **GNU Stow**. Each top-level directory is a stow package that symlinks into `~/.config/` (or other XDG paths).

## Stow Commands

```bash
cd ~/.dots
stow <package>        # symlink a package
stow -D <package>     # unlink
stow -R <package>     # re-link after restructuring
```

Every package follows the stow convention: files inside `<package>/.config/` land in `~/.config/`. The `sddm` package is an exception — it requires manual `sudo cp` to `/usr/share/sddm/themes/`.

## AGS (Aylur's GTK Shell)

The AGS sidebar is the most complex component. It's a **GTK4 TypeScript/TSX** app using AGS v2 (`ags/gtk4`).

- Entry point: `ags/.config/ags/app.ts` — registers request handlers (`toggle-panel`, `show-panel`, `hide-panel`)
- Widgets in `widgets/` are TSX components using `ags/gtk4` JSX (`jsxImportSource: "ags/gtk4"`)
- Services in `lib/` wrap shell commands (`wpctl`, `ddcutil`, `makoctl`) with polling-based state
- Styles use SCSS partials imported through `style.scss`
- `waybar/` subdirectory contains config/style snippets to integrate AGS with Waybar

Run/restart AGS: `ags run` or `ags quit && ags run`
Send commands: `ags request toggle-panel`

## Hyprland Config

The entry point is `hypr/.config/hypr/hyprland.lua`, split into modules under `lua/`. `lua/workspaces.lua` configures the pinned `split-monitor-workspaces` Lua submodule under `plugins/`. The legacy `hyprland.conf` and `conf.d/*.conf` files are retained only as migration rollback material.

The `very-old-config/` directory is legacy/archived (gitignored) and should be ignored.

## Waybar

Config: `waybar/.config/waybar/config.jsonc` — modules reference scripts in `scripts/`. Custom modules call AGS (`ags request`), `rofi`, `hyprctl`, and various CLI tools. Waybar is pinned to output `DP-3`.

## Scripts

`scripts/.config/menu-scripts/` contains rofi-based utility scripts. `runner.sh` auto-discovers sibling `.sh` scripts and presents them in a rofi menu (bound to Super+D in Hyprland).

## Key Tools/Dependencies

- **Hyprland** (compositor), **Waybar** (bar), **Rofi** (launcher), **Mako** (notifications)
- **AGS v2** with GTK4 for the sidebar panel
- **wpctl** (PipeWire audio), **ddcutil** (external monitor brightness), **hyprshade** (blue light filter)
- **Mullvad VPN**, **cliphist** (clipboard), **hyprpicker** (color picker)
