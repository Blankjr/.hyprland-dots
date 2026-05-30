# dotfiles

Managed with [GNU Stow](https://www.gnu.org/software/stow/). Each top-level directory is a stow package.

## Packages

| Package | Target | Contents |
|---------|--------|----------|
| `hypr` | `~/.config/hypr/` | Hyprland compositor config |
| `mako` | `~/.config/mako/` | Notification daemon |
| `rofi` | `~/.config/rofi/` | App launcher |
| `waybar` | `~/.config/waybar/` | Status bar + scripts |
| `nvim` | `~/.config/nvim/` | Neovim config |
| `qt6ct` | `~/.config/qt6ct/` | Qt6 dark theme (Fusion + darker palette) |
| `mime` | `~/.config/` | Default application associations |
| `scripts` | `~/.config/menu-scripts/` | Rofi script runner (Super+D) |
| `ags` | `~/.config/ags/` | AGS sidebar (display, sound, menus) |
| `secrets` | `~/.config/secrets/` | Env files with tokens (real `.env` is gitignored) |
| `sddm` | — | SDDM login theme (manual install, see below) |

## Usage

```bash
cd ~/.dots

# Link a package
stow <package>

# Unlink a package
stow -D <package>

# Re-link (unlink + link) after restructuring
stow -R <package>
```

### AGS Display Menu

The brightness control uses `ddcutil` which requires the `i2c-dev` kernel module. To load it permanently:

```bash
sudo modprobe i2c-dev
echo "i2c-dev" | sudo tee /etc/modules-load.d/i2c-dev.conf
```

Optional dependencies (features are hidden automatically if not installed):
- `ddcutil` — external monitor brightness via DDC/CI
- `hyprshade` — blue light filter

### Hyprland Plugin: split-monitor-workspaces

Provides awesomewm-style per-monitor workspaces (each monitor gets its own 1–10). Config is in `hypr/.config/hypr/conf.d/plugins.conf`; `autostart.conf` runs `hyprpm reload -n` each session to load it.

One-time install (needs build deps):

```bash
sudo pacman -S --needed cmake cpio pkgconf git gcc
hyprpm add https://github.com/zjeffer/split-monitor-workspaces
hyprpm enable split-monitor-workspaces
hyprpm reload
```

After each Hyprland update, rebuild against the new headers:

```bash
hyprpm update
```

If `monitor_priority` in `plugins.conf` references connector names that no longer exist (e.g. DP-3/DP-2 renumbered after a driver change), update the list — first entry gets workspaces 1–10, second gets 11–20.

### Local Scripts

`~/.dots/localscripts/` is added to `$PATH` in `config.fish`, `.zshrc`, and `.bashrc` directly (no stow). Drop any executable in there and it's instantly callable from fish, zsh, and bash — no relink step.

```bash
chmod +x ~/.dots/localscripts/<new-script>
```

### Secrets

The `secrets` package ships `*.env.example` templates only. After `stow secrets`, copy the example and fill in real values:

```bash
cp ~/.config/secrets/forgejo.env.example ~/.config/secrets/forgejo.env
chmod 600 ~/.config/secrets/forgejo.env
# edit and fill in FORGEJO_TOKEN etc.
```

The real `*.env` files live in the repo but are gitignored.

### SDDM Install

The `sddm` theme cannot be managed with stow (requires root). Install it manually after cloning:

```bash
sudo cp -r ~/.dots/sddm /usr/share/sddm/themes/dots
sudo sed -i 's/Current=.*/Current=dots/' /etc/sddm.conf
```

To preview without logging out:

```bash
sddm-greeter-qt6 --test-mode --theme /usr/share/sddm/themes/dots
```

### RX 6700 XT Blank Screen on Boot

The RX 6700 XT (RDNA2) can get stuck in a low power state after shutdown, causing no video output on next boot. Fix by disabling GPU runtime power management:

```bash
sudo vim /etc/default/grub
```

Add `amdgpu.runpm=0` to `GRUB_CMDLINE_LINUX_DEFAULT`: 
GRUB_CMDLINE_LINUX_DEFAULT='nowatchdog nvme_load=YES zswap.enabled=0 splash loglevel=3 amdgpu.runpm=0'

then regenerate GRUB config:

```bash
sudo grub-mkconfig -o /boot/grub/grub.cfg
```

BIOS — `Settings → Advanced → Power Management Setup`:
- `ErP Ready` → Enabled
- `Settings → Advanced → Wake Up Event Setup` → all wake sources Disabled

