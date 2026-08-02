local programs = require("lua.programs")
local smw = require("lua.workspaces")

local main_mod = "SUPER"

local function bind(keys, dispatcher, description, flags)
    local options = { description = description }
    for name, value in pairs(flags or {}) do
        options[name] = value
    end
    return hl.bind(keys, dispatcher, options)
end

bind(main_mod .. " + RETURN", hl.dsp.exec_cmd(programs.terminal), "Terminal")
bind(main_mod .. " + Q", hl.dsp.window.close(), "Close window")
bind(main_mod .. " + E", hl.dsp.exec_cmd(programs.file_manager), "File manager")
bind(main_mod .. " + D", hl.dsp.exec_cmd("~/.config/menu-scripts/runner.sh"), "Script runner")
bind(main_mod .. " + F", hl.dsp.window.float({ action = "toggle" }), "Toggle floating")
bind(main_mod .. " + H", hl.dsp.exec_cmd("~/.config/hypr/scripts/show-keybinds.sh"), "Keybinding help")
bind(main_mod .. " + R", hl.dsp.exec_cmd("hyprctl reload"), "Reload Hyprland config")
bind(main_mod .. " + SHIFT + R", hl.dsp.exec_cmd("~/.config/hypr/scripts/uninstall-package.sh"), "Uninstall package")

-- Group windows into one tiled slot with a clickable tab bar.
bind(main_mod .. " + G", hl.dsp.group.toggle(), "Toggle window group")
bind(main_mod .. " + TAB", hl.dsp.group.next(), "Next group tab")
bind(main_mod .. " + SHIFT + TAB", hl.dsp.group.prev(), "Previous group tab")

-- Application launcher and desktop utilities.
bind(main_mod .. " + SPACE", hl.dsp.exec_cmd("pkill rofi || rofi -show drun"), "Application launcher", { release = true })
bind(main_mod .. " + C", hl.dsp.exec_cmd("hyprpicker -a"), "Copy color")
bind(main_mod .. " + V", hl.dsp.exec_cmd("cliphist list | rofi -dmenu -p 'Clipboard' | cliphist decode | wl-copy"), "Clipboard history")
bind(main_mod .. " + L", hl.dsp.exec_cmd("ags request toggle-panel"), "Control panel")
bind(main_mod .. " + A", hl.dsp.exec_cmd("ags request toggle-ai"), "Local AI panel")
bind(main_mod .. " + P", hl.dsp.window.pseudo(), "Pseudo tiling")

-- Screenshots (grim + slurp + swappy).
bind(main_mod .. " + F12", hl.dsp.exec_cmd([[grim -g "$(slurp)" - | swappy -f -]]), "Screenshot region")
bind(main_mod .. " + ALT + F12", hl.dsp.exec_cmd([[grim -o "$(hyprctl monitors -j | jq -r '.[] | select(.focused).name')" - | swappy -f -]]), "Screenshot active monitor")
bind(main_mod .. " + CTRL + ALT + F12", hl.dsp.exec_cmd("grim - | swappy -f -"), "Screenshot all monitors")
bind(main_mod .. " + J", hl.dsp.layout("togglesplit"), "Toggle split")

-- Move focus with mainMod + arrow keys.
bind(main_mod .. " + left", hl.dsp.focus({ direction = "left" }), "Move focus")
bind(main_mod .. " + right", hl.dsp.focus({ direction = "right" }), "Move focus")
bind(main_mod .. " + up", hl.dsp.focus({ direction = "up" }), "Move focus")
bind(main_mod .. " + down", hl.dsp.focus({ direction = "down" }), "Move focus")

-- Nth workspace on the focused monitor, with workspace 10 on key 0.
for i = 1, smw.get_amount_of_workspaces() do
    local key = i % 10
    local workspace = tostring(i)
    bind(main_mod .. " + " .. key, smw.workspace(workspace), "Switch workspace")
    bind(main_mod .. " + SHIFT + " .. key, smw.move_to_workspace_silent(workspace), "Move window to workspace")
end

bind(main_mod .. " + S", hl.dsp.workspace.toggle_special("magic"), "Toggle scratchpad")
bind(main_mod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }), "Move window to scratchpad")

bind(main_mod .. " + mouse_down", smw.cycle_workspaces("next"), "Cycle workspaces")
bind(main_mod .. " + mouse_up", smw.cycle_workspaces("prev"), "Cycle workspaces")

-- Move/resize windows with mainMod + LMB/RMB and dragging.
bind(main_mod .. " + mouse:272", hl.dsp.window.drag(), "Move window", { mouse = true })
bind(main_mod .. " + mouse:273", hl.dsp.window.resize(), "Resize window", { mouse = true })

-- Laptop multimedia keys for volume and LCD brightness.
local repeat_locked = { locked = true, repeating = true }
bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), "Raise volume", repeat_locked)
bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), "Lower volume", repeat_locked)
bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), "Mute audio", repeat_locked)
bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), "Mute microphone", repeat_locked)
bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"), "Raise brightness", repeat_locked)
bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"), "Lower brightness", repeat_locked)

local locked = { locked = true }
bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), "Next track", locked)
bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), "Play or pause", locked)
bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), "Play or pause", locked)
bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), "Previous track", locked)
