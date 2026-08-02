hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("GTK_THEME", "Adwaita:dark")
hl.env("TERMINAL", "kitty")

-- Firefox
hl.env("MOZ_ENABLE_WAYLAND", "1")

-- Electron >28 apps (may help)
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
