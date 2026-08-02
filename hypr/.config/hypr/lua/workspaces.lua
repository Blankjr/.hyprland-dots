-- Hyprland restricts require() to Lua modules relative to the config directory.
package.path = package.path .. ";./?.lua;./?/init.lua"

local smw = require("plugins.split-monitor-workspaces")
local smw_helpers = require("plugins.split-monitor-workspaces.lua.helpers")
local smw_monitors = require("plugins.split-monitor-workspaces.lua.monitors")

smw.setup({
    workspace_count = 10,
    keep_focused = true,
    enable_notifications = false,
    enable_persistent_workspaces = true,
    enable_wrapping = true,
    link_monitors = false,
    -- Mi Monitor first (workspaces 1-10), BenQ second (workspaces 11-20).
    monitor_priority = { "DP-3", "DP-2" },
})

-- The package's initial config.reloaded event fires before Hyprland has
-- discovered any outputs, and monitor.added is not emitted for those startup
-- outputs. Populate the package's runtime monitor map once output discovery is
-- complete. Without this, workspace bindings fall back to absolute IDs, so
-- SUPER+2 on DP-2 incorrectly opens workspace 2 instead of workspace 12.
hl.on("hyprland.start", function()
    smw_helpers.load_config_for_all_monitors()
    smw_monitors.remap_all_monitors()
end)

return smw
