hl.window_rule({
    name = "suppress-maximize-events",
    match = { class = ".*" },
    suppress_event = "maximize",
})

hl.window_rule({
    name = "fix-xwayland-drags",
    match = {
        class = "^$",
        title = "^$",
        xwayland = true,
        float = true,
        fullscreen = false,
        pin = false,
    },
    no_focus = true,
})

hl.window_rule({
    name = "floating-term",
    match = { class = "floating-term" },
    float = true,
    size = { "50%", "40%" },
    center = true,
})

hl.window_rule({
    name = "keybind-helper",
    match = { class = "keybind-helper" },
    float = true,
    size = { 1200, 450 },
    center = true,
})

-- Launch shims focus and briefly unlock the matching app's existing group.
hl.window_rule({
    name = "group-zed-windows",
    match = { class = "^dev\\.zed\\.Zed$" },
    group = "set always lock always",
    focus_on_activate = true,
})

hl.window_rule({
    name = "group-vscodium-windows",
    match = { class = "^(codium|VSCodium|com\\.vscodium\\.codium)$" },
    group = "set always lock always",
    focus_on_activate = true,
})

hl.window_rule({
    name = "move-hyprland-run",
    match = { class = "hyprland-run" },
    move = "20 monitor_h-120",
    float = true,
})
