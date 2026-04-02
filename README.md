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
