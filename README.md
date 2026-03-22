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
