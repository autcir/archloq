# Xfce

Desktop environment. Owner: `install-scripts/app/05_desktop_xfce.sh` (packages,
display manager, session) and `dotfiles/scripts/` (everything after login).

Xfce 4.20 on X11. One window manager, one compositor, one settings store.

---

## 1. Packages

Installed by `05_desktop_xfce.sh`:

```
xfce4 xfce4-panel xfwm4 xfdesktop thunar xfce4-session xfce4-settings xfconf
xfce4-appfinder xfce4-notifyd xfce4-screensaver xfce4-power-manager
xfce4-clipman xfce4-whiskermenu-plugin xfce4-docklike-plugin
xfce4-screenshooter xfce4-pulseaudio-plugin xfce4-terminal mousepad
xfce4-panel-profiles xfce4-xkb-plugin
xorg-server xorg-xinit xorg-apps
pipewire pipewire-pulse pipewire-alsa pipewire-jack wireplumber pavucontrol
gnome-keyring lxpolkit
xbindkeys xdotool wmctrl
papirus-icon-theme adwaita-icon-theme
ttf-jetbrains-mono-nerd ttf-inter ttf-noto-sans
<LOQ_TERMINAL>          # foot by default
sddm                    # or lightdm
```

`dotfiles/scripts/20-xfce.sh` installs the same stack plus `light`, `bluez` and
`bluez-utils`, for running it on a live desktop without a root install script.

### Why `xfce4-goodies` is deliberately absent

It is a metapackage. Installing it drags in gigolo, extra `gvfs` backends,
synaptic, an image viewer and a second terminal — several of which are the
`xfce4` versions, so you end up with two of the same program under different
names and no way to tell which one is in your path.

The three or four plugins actually wanted are listed individually above:
`xfce4-whiskermenu-plugin`, `xfce4-docklike-plugin`, `xfce4-pulseaudio-plugin`,
`xfce4-screenshooter`. `90_postinstall.sh` reports an installed
`xfce4-goodies` as an advisory, because it means something pulled it in
unintentionally.

---

## 2. SDDM, not LightDM

`LOQ_DISPLAY_MANAGER="sddm"`. Both work; `05_desktop_xfce.sh` accepts either
and `die`s on anything else, so a typo in `loq.conf` fails at install time
rather than at first login.

Why SDDM:

- **envycontrol documents support for it.** Switching GPU mode with SDDM works
  because envycontrol rewrites SDDM's `Xsetup` script to inject the PRIME
  profile. That is a first-class supported path, and it is the thing on this
  machine most likely to need it ([GPU_SETUP.md](GPU_SETUP.md)).
- Qt theming without dragging in a Qt session: the Kvantum Catppuccin Mocha Blue
  theme in `dotfiles/config/kvantum/` styles the greeter, which is why Kvantum is
  retained for Qt applications even though Xfce itself is not Qt.
- One small process. It owns one VT, shows one greeter, and does not layer GTK on
  top of Qt to render a session chooser.

Only one display manager may be enabled. `configure_display_manager()` walks
`gdm lightdm sddm ly display-manager` and disables any other that is enabled, so
two DMs never fight over the VT.

**Autologin is off.** See [SECRETS.md](SECRETS.md) §4 for why.

---

## 3. Compositor: xfwm4's own, no picom

`xfwm4` has a compositor built in. It is enabled here
(`/general/use_compositing = true`, vblank on, popup shadows off).

Two compositors must not run at once. picom and xfwm4's compositor both
redirect the same windows through the same X composite extension; the second one
to initialise takes ownership of the redirection, and the result is tearing,
windows that will not repaint, and intermittent lost input — symptoms that look
like a graphics driver fault and are not one.

`dotfiles/config/xfce/xfce-perchannel-xml/xfwm4/general.xml` carries it:

```xml
<property name="compositing" type="empty">
  <property name="use_compositing" type="bool" value="true"/>
  <property name="vblank" type="int" value="1"/>
  <property name="show_frame_shadow" type="bool" value="true"/>
  <property name="show_popup_shadow" type="bool" value="false"/>
</property>
```

If you install picom, set `use_compositing` to false and enable picom instead.
Never both. `verify-catppuccin.sh` reports the current state either way.

Window snapping to borders is on, snapping to windows is on, snapping to the
desktop is off, and edge snapping is disabled
(`/Net/SnapToEdges=false`) because it fights fullscreen video on a 17-inch
panel.

---

## 4. Panel architecture

Two panels:

```
panel-0  top      whisker-menu | windowbuttons | pager | indicator | clock
panel-1  bottom   docklike | systray | netload | acpi | cpugraph | genmon
```

Both full-width (`length = 100`), `size-mode = auto`. Four workspaces,
`focus_new = 1` with `click_to_focus = true`.

### Built by script, not shipped as layout XML

This is the one design decision worth arguing about, so here is the argument.
`xfce4-panel` stores its layout in an XML file that is version-coupled to the
running xfce4-panel, and **a malformed layout XML is silently ignored** —
xfce4-panel falls back to a default panel and reports nothing. You find out on
the next login that your two-row layout did not apply and there is no error
anywhere to read.

`dotfiles/scripts/21-panel.sh` builds the layout through `xfconf-query` against
the `xfce4-panel` channel — the same interface the panel itself uses. A wrong
property name becomes a visible error at the point of writing:

```
  warn: could not set /xfce4-panel/panels/panel-0/length=100
```

and a plugin that will not add prints why:

```
  cannot add genmon to panel 1: ...
```

It is deterministic across re-runs: existing panels are removed first
(`xfconf-query -c xfce4-panel -p /panels -r -f`), then rebuilt from scratch.

**Limitation, stated plainly:** the property names in `21-panel.sh` were taken
from upstream source rather than observed from a running session on this machine.
The panel is the most likely part of the desktop to need a fix on first login.
`21-panel.sh` prints the diagnostic command for it:

```bash
xfconf-query -c xfce4-panel -p /panels/panel-0/plugins -l
```

Verify with:

```bash
./dotfiles/scripts/21-panel.sh
xfconf-query -c xfce4-panel -p /panels -l
```

---

## 5. Two shortcut channels, deliberately

**Keyboard** → `xfce4-keyboard-shortcuts`, an xfconf channel, written by
`dotfiles/scripts/22-keybindings.sh`.

```bash
bind "<Super>p"                 "xfce4-appfinder --window"
bind "<Super><Shift>Escape>"    "xfce4-shutdown --reboot --halt"
bind "<Super>1"                 "exo-open --working-directory workspace 1"
bind "<Super><Shift>$n"         "xfwm4 --workspace $n --shift --active"
bind "<Super>q"                 "xfwm4 --close"
bind "<Super>h"                 "xfwm4 --hide"
bind "<Super><Up>"              "xfwm4 --maximize"
bind "<Super><Down>"            "xfwm4 --unmaximize"
bind "<Super>Left"              "xfwm4 --left"
bind "<Super>Right"             "xfwm4 --right"
bind "<Print>"                  "xfce4-screenshooter -f -s $HOME/Pictures"
bind "<XF86AudioRaiseVolume>"   "amixer -D pulse sset Master 5%+ unmute"
```

Move window to workspace N is the one genuinely useful binding xfwm4 does not
expose by default, and it goes through `wmctrl`:

```bash
custom "<Super><Control>$n" "move-window-to-workspace-$n" "wmctrl -r :ACTIVE: -t $((n - 1))"
```

The channel survives package upgrades because xfce4-session's keyboard-shortcuts
plugin reads it at startup. `XF86Audio*` is bound directly rather than left to
`xfce4-pulseaudio-plugin` so volume works on the single-display setup without
depending on the daemon having started.

**Mouse** → `~/.config/xbindkeys/xbindkeysrc`, symlinked from
`dotfiles/config/xbindkeys/`.

```
Super + Button2   wmctrl -r :ACTIVE: -b add,maximized_vert
Super + Button3   xdotool key --clearmodifiers super+q
```

Why the split: xbindkeys binds at the **X server level**. With it running there
is no way to ask Xfce which bindings exist — `xfconf-query -c
xfce4-keyboard-shortcuts -l` will not show the mouse ones. Two systems both
claiming the same key, resolved by focus timing, is the failure mode. So each
owns exactly one class of input.

Two details in that file that are easy to get wrong:

- Maximise-vertically uses `wmctrl -b add,maximized_vert` because it is only
  reachable as a client message; there is no default xfwm4 keystroke to forward.
- Super + Button3 forwards the keystroke rather than sending `WM_DELETE`
  directly, so the application's own close handling runs — unsaved-changes
  prompts, "close tab" versus "close window".

---

## 6. The xfconf per-channel tree

```
dotfiles/config/xfce/xfce-perchannel-xml/
├── xfce4-desktop/backdrop.xml          per-workspace backdrop
├── xfce4-keyboard-shortcuts/custom-0.xml   reference copy
├── xfce4-session/general.xml           SaveOnExit, no crash restore
└── xfwm4/general.xml                   focus, snapping, compositor
    xfwm4/theme.xml                     titlebar
    xfwm4/xfce4_keyboard.xml            Alt/Super key actions
```

`dotfiles/scripts/23-xfconf-channels.sh` walks each channel file and writes each
property individually with `xfconf-query`:

```bash
./dotfiles/scripts/23-xfconf-channels.sh
```

**xfconf has no "import" verb.** The files in the repo are the reference; the
script is what actually pushes them into the live session. Writing property by
property means a typo produces a visible `FAIL` line here rather than a channel
that half-applies and looks fine.

The xfce4-session channel deliberately sets `SaveOnExit=true` and
`AutoSave=false`: Xfce remembers window positions across logout, but does not
restore a crashed application on the next login.

---

## 7. Terminal: foot + Catppuccin Mocha

`LOQ_TERMINAL="foot"` (`alacritty` and `ghostty` are drop-in substitutes;
`05_desktop_xfce.sh` warns if the configured one is not a valid command).

`dotfiles/config/foot/foot.ini` selects `theme=mocha` from a separate palette
file, so the palette can be regenerated from upstream without touching
behavioural settings. JetBrainsMono Nerd Font 11, 10000 lines of scrollback,
1000 of history, block cursor with no blink, cursor hidden when unfocused, visual
bell via `notify-send` instead of the laptop speaker, `resize-step=0,1` so Nerd
Font box-drawing characters keep an honest glyph grid.

### Shell

zsh + starship + Catppuccin, recycled unchanged from `config/zsh` and
`config/starship`. `10_software.sh` sets `/bin/zsh` as the login shell.

---

## 8. Verification

`dotfiles/scripts/verify-catppuccin.sh` reads the **live** state rather than
checking that files exist. A theme can be fully installed and not applied, and
that is the failure a file-presence check cannot see.

```bash
./dotfiles/scripts/verify-catppuccin.sh
```

It checks:

- `xfconf-query -c xfwm4 -p /theme -n` is `mocha` — not merely present
- compositor state
- at least 7 XPM assets in `~/.config/xfwm4/themes/mocha` (3 buttons × 2 states
  plus the menu button)
- `gsettings get org.gnome.desktop.interface icon-theme` is `Papirus-Dark`
- `xfconf-query -c xsettings -p /Gtk/CursorThemeName -n` is set — `/Gtk/`, not
  `/Net/`, which `xfsettingsd` does not consult
- foot theme, starship config

Exits non-zero on any failure, which is how `09_dotfiles.sh` gates on it.

---

## 9. libadwaita limitation

**`libadwaita` applications ignore this theme. They will look light-on-dark
mismatched against the rest of the desktop.** This is accepted, not fixed.

GNOME Calculator, GNOME Text Editor, and most Flatpaks on the GTK4 libadwaita
stack ship their own style and override `gtk-theme-name`. No GTK theme reaches
them. Setting `org.gnome.desktop.interface gtk-theme` does not change it, which
is why `verify-catppuccin.sh` reports Adwaita-dark as "the reliable baseline"
and treats Catppuccin there as a fallback rather than an expectation.

The mitigation is choosing applications: prefer Xfce-native and GTK3 apps
(`mousepad`, `thunar`, `pavucontrol`). The font and icon settings do carry over
to libadwaita apps, so those are not wrong, only the colours.

`verify-catppuccin.sh` prints this as a standing note rather than a failure,
because a broken install and a libadwaita app look identical and only one of them
is your fault.

---

## 10. Run order

```bash
./dotfiles/install.sh                    # symlinks / copies (as your user)
./dotfiles/scripts/20-xfce.sh            # packages + theme assets (needs sudo)
./dotfiles/scripts/23-xfconf-channels.sh # per-channel XML -> live session
./dotfiles/scripts/21-panel.sh           # build the two-row panel
./dotfiles/scripts/22-keybindings.sh     # keyboard channel
./dotfiles/scripts/verify-catppuccin.sh  # read back and judge
```

Order matters in three places:

- `install.sh` first, or the later scripts have no theme assets to work with.
- `23-xfconf-channels.sh` **before** `21-panel.sh`: the channel script sets
  `workspace_count` and the compositing/focus properties the panel is built
  around.
- `22-keybindings.sh` last, after the panel exists, so a failed panel build does
  not leave you with no way to close a window.

All of `21`, `22` and `23` need a live X session and refuse to run without
`$DISPLAY`.

---

## 11. Related

- [dotfiles/README.md](../dotfiles/README.md) — what each directory deploys
- [POWER_MANAGEMENT.md](POWER_MANAGEMENT.md) — PPD, which adjusts the CPU
  governor profile by battery state
- [SECRETS.md](SECRETS.md) — why autologin is off
- [REFORMAT-XFCE.md §10](REFORMAT-XFCE.md) — the decision this implements