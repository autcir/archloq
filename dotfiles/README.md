# dotfiles — Xfce on Arch Linux

Catppuccin Mocha, Xfce 4.20 on X11. Deployed into `~/.config`.

```bash
./install.sh              # deploy (as your user, not root)
./install.sh --check      # show what would change, deploy nothing
./install.sh --remove     # undo exactly what install.sh created
```

Run it as yourself. Run by root it writes root-owned files into your home,
which then breaks your own edits. `install-scripts/app/09_dotfiles.sh` uses
`runuser` for exactly this reason.

---

## Layout, and where each path lands

### Symlinked — DE-agnostic tool configuration

These are never written by the applications that read them, so a symlink means
`git pull` in this directory takes effect immediately, with no second deploy
step. That is the whole reason for the arrangement.

| `dotfiles/` | deploys to | reads |
|-------------|-----------|-------|
| `config/bat/` | `~/.config/bat/` | bat |
| `config/btop/` | `~/.config/btop/` | btop |
| `config/cava/` | `~/.config/cava/` | cava |
| `config/fastfetch/` | `~/.config/fastfetch/` | fastfetch |
| `config/foot/` | `~/.config/foot/` | foot terminal |
| `config/nvim/` | `~/.config/nvim/` | neovim |
| `config/starship/` | `~/.config/starship/` | starship prompt |
| `config/zsh/` | `~/.config/zsh/` | zsh (sourced from `~/.zshrc`) |
| `config/gtk-3.0/` | `~/.config/gtk-3.0/` | GTK3 apps |
| `config/gtk-4.0/` | `~/.config/gtk-4.0/` | GTK4 apps |
| `config/xsettings/` | `~/.config/xsettings/` | xfsettingsd, and the source for the xsettings channel |
| `config/xbindkeys/` | `~/.config/xbindkeys/` | xbindkeys (mouse only) |
| `config/kvantum/` | `~/.config/Kvantum/` | Qt apps and SDDM |
| `xinitrc` | `~/.xinitrc` | `startx`, for a fallback TTY login |

### Copied — anything xfconf owns

| `dotfiles/` | deploys to | why copied |
|-------------|-----------|-----------|
| `config/xfce/xfce-perchannel-xml/` | `~/.config/xfce/xfce-perchannel-xml/` | xfconf **rewrites these files in place** on every settings change made in a GUI. A symlink would take the repository with it |
| `config/xfwm4/themes/` | `~/.config/xfwm4/themes/` | same: xfwm4 writes its theme directory |

The copy is replaced wholesale rather than merged:

```bash
[[ -e "$target" ]] && rm -rf "$target"
cp -r "$src" "$target"
```

Partial copies of an xfconf tree are how you get a half-applied settings
channel that nothing reports as wrong.

Consequence worth internalising: **the repo copy is the reference, not the live
state.** Xfce rewrites `~/.config/xfce/xfce-perchannel-xml/`. To make a change
permanent, edit `dotfiles/config/xfce/xfce-perchannel-xml/` and run
`23-xfconf-channels.sh`, or edit through the GUI and copy the result back.

### Not deployed

| Path | Purpose |
|------|---------|
| `scripts/` | run manually, after login; see the order below |
| `tools/gen-xfwm4-theme.py` | regenerates `config/xfwm4/themes/mocha` |
| `wallpapers/` | source for `11-wallpaper-catppuccin.sh` |
| `config-extras/` | empty placeholder |

---

## Run order

```bash
./install.sh                    # 1. symlink / copy (idempotent)
./scripts/20-xfce.sh            # 2. packages + theme assets       (needs sudo)
./scripts/23-xfconf-channels.sh # 3. per-channel XML -> live session (needs X)
./scripts/21-panel.sh           # 4. build the two-row panel        (needs X)
./scripts/22-keybindings.sh     # 5. keyboard channel               (needs X)
./scripts/verify-catppuccin.sh  # 6. read the live state back and judge
```

The order is load-bearing in three places: `install.sh` must come first or there
are no theme assets; `23` must precede `21` because it sets
`workspace_count` and the compositing properties the panel is built around; and
`22` goes last so a failed panel build does not leave you without a way to close
a window.

Steps 3 to 6 need a live X session and exit non-zero without `$DISPLAY`.

### Re-running after `git pull`

```bash
./reapply.sh
```

Replays `install.sh` plus the live-session steps. It deliberately does not
re-run the package installers.

---

## Scripts

| Script | Does | Root? |
|--------|------|-------|
| `00-prereqs.sh` | installs `git`, `base-devel`, `stow` | yes |
| `09-icons-papirus.sh` | Papirus + Adwaita, applied through `gsettings` | yes |
| `10-gtk-catppuccin.sh` | writes `gtk-3.0/settings.ini` and `gtk-4.0/settings.ini` | no |
| `11-wallpaper-catppuccin.sh` | sets the backdrop **per workspace** through xfconf | no |
| `20-xfce.sh` | the Xfce package stack, xfwm4 theme, Kvantum | yes |
| `21-panel.sh` | builds the two-row panel via `xfconf-query` | no, needs X |
| `22-keybindings.sh` | writes the `xfce4-keyboard-shortcuts` channel | no, needs X |
| `23-xfconf-channels.sh` | applies the per-channel XML tree | no, needs X |
| `99-rollback.sh` | undoes the deploy, from the manifest | no |
| `reapply.sh` | `install.sh` + live-session steps | no |
| `verify-catppuccin.sh` | reads live state, exits non-zero on failure | no, needs X |

Two of these carry a design note that is worth reading before editing:

- `21-panel.sh` builds the panel through `xfconf-query` rather than shipping a
  layout XML, because a malformed panel XML is silently ignored by xfce4-panel.
- `22-keybindings.sh` uses the xfconf channel rather than `~/.Xbindkeysrc`,
  because the channel survives package upgrades and is readable with
  `xfconf-query -c xfce4-keyboard-shortcuts -l`. Mouse bindings are the exception
  and live in `config/xbindkeys/xbindkeysrc`.

---

## Rollback

`install.sh` writes every path it creates to a manifest:

```
~/.config/.dotfiles-manifest
```

`99-rollback.sh` reads that manifest and removes exactly those paths — symlinks
unlinked, copied directories removed — and nothing else. Anything you changed
that `install.sh` did not create is left alone.

```bash
./scripts/99-rollback.sh
find ~/.config -maxdepth 2 -name '*.dotfiles-backup.*'
```

Backups are **kept, not deleted.** When `install.sh` finds a real file where it
wants a symlink, it moves it aside:

```
~/.config/nvim -> ~/.config/nvim.dotfiles-backup.1757260800
```

That asymmetry is deliberate. Rollback removes the symlink and leaves your
previous directory sitting next to it. Restoring is your call, not the script's.

If there is no manifest, `99-rollback.sh` says so and exits 0 — you either have
not deployed, or you already rolled back.

---

## Notes

- **libadwaita apps ignore this theme.** GNOME Calculator, GNOME Text Editor and
  most Flatpaks render light-on-dark against the rest of the desktop. Accepted,
  not fixed. See [../docs/XFCE.md §9](../docs/XFCE.md).
- **The xfconf tree in this repo is a reference copy.** `xfconf-query -c xfwm4 -l`
  shows the live state; the repo file is what gets pushed into it.
- **`config/xsettings/xsettings.ini` is not an xsettings XML file.** It is a
  keyfile. `xfsettingsd` only honours `/Net/`, `/Xft/`, `/Gtk/` and `/Gdk/`
  prefixes, and xfconf rejects `double` properties outright.
- `tools/gen-xfwm4-theme.py` regenerates the xfwm4 theme assets. The palette
  lives in the repo so it can be rebuilt from upstream without hand-editing XPM.