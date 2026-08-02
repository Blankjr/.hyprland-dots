-- Hyprland configuration
-- https://wiki.hypr.land/Configuring/
--
-- Modules are loaded in dependency order. The legacy hyprland.conf and
-- conf.d/*.conf files remain available as rollback material during migration.

require("lua.monitors")
require("lua.environment")
require("lua.permissions")
require("lua.appearance")
require("lua.input")
require("lua.workspaces")
-- Register workspace initialization before autostart launches Waybar.
require("lua.autostart")
require("lua.keybindings")
require("lua.windowrules")
require("lua.debug")
