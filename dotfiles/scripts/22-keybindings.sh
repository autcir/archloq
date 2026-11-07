#!/usr/bin/env bash
# =============================================================================
# 22 — keyboard shortcuts (XFCE 4.20 / xfwm4)
# -----------------------------------------------------------------------------
# Modifier layout. Three separate roles, no overlap:
#
#   Super  → launchers and window actions, Arch/Omarchy style. NO digits:
#            a digit under Super is ambiguous with the numpad, so digits are
#            never bound to it.
#   Alt+1..N → virtual desktops (N = xfwm4's actual workspace_count)
#   Alt+Numpad → tiling grid on the numpad, which mirrors the physical layout
#
# Omarchy/Hyprland is not installed here (see dotfiles/README.md); this file is
# what reproduces that feel on xfwm4.
# =============================================================================

set -euo pipefail

CHANNEL=xfce4-keyboard-shortcuts

if [[ -z "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]]; then
  printf 'no DISPLAY. Run this from inside the Xfce session.\n' >&2
  exit 1
fi
command -v xfconf-query >/dev/null 2>&1 || {
  printf 'xfconf-query not found\n' >&2
  exit 1
}

# Remove a binding. `-r` fails when the property does not exist, which is the
# common case on a fresh machine, so the error is swallowed on purpose.
unbind() {
  local path="$1"
  xfconf-query -c "$CHANNEL" -p "$path" -r >/dev/null 2>&1 || true
}

# Every binding is removed and then written back, never overwritten in place.
# xfsettingsd has a long-standing bug (Xfce forum #15542) where overwriting an
# existing shortcut leaves the grab unregistered in the running xfwm4: the value
# looks correct in the channel, the key does nothing, and which keys are broken
# changes on every xfwm4/xfsettingsd restart. Delete-then-recreate is the
# documented workaround and makes the grab stick.
# xfsettingsd consumes each property change as a separate D-Bus event. Writing
# forty of them back to back floods it and it silently drops some, which showed
# up as a binding that reads correctly in the channel but does nothing live —
# and which ones drop changes between runs. The small pause keeps it in step.
BIND_DELAY="${BIND_DELAY:-0.12}"

bind_wm() {
  local trigger="$1" action="$2"
  unbind "/xfwm4/custom/$trigger"
  if xfconf-query -c "$CHANNEL" -p "/xfwm4/custom/$trigger" -n -t string -s "$action" 2>/dev/null; then
    printf '  [WM]  %-24s %s\n' "$trigger" "$action"
  else
    printf '  FAILED [WM] %-20s %s\n' "$trigger" "$action" >&2
  fi
  sleep "$BIND_DELAY"
}

bind_cmd() {
  local trigger="$1" command="$2"
  unbind "/commands/custom/$trigger"
  if xfconf-query -c "$CHANNEL" -p "/commands/custom/$trigger" -n -t string -s "$command" 2>/dev/null; then
    printf '  [CMD] %-24s %s\n' "$trigger" "$command"
  else
    printf '  FAILED [CMD] %-20s %s\n' "$trigger" "$command" >&2
  fi
  sleep "$BIND_DELAY"
}

printf '== Configurazione Scorciatoie XFCE ==\n\n'

# --- 0. Purge delle scorciatoie superate -------------------------------------
# xfconf channels accumulate: writing new bindings never removes old ones. The
# previous layout is therefore removed explicitly, or Super+1..5 and Super+Numpad
# would keep working alongside the new ones and look like the script failed.
printf 'Rimozione binding precedenti...\n'

# Super+Alt+digits and Super+Shift+digits are only cleared beyond the real
# workspace count; the ones in range are re-bound further down, since Super
# carries the desktop switch as well as Alt.
for n in 5 6; do
  unbind "/xfwm4/custom/<Super>$n"
  unbind "/xfwm4/custom/<Super><Shift>$n"
  unbind "/xfwm4/custom/<Super><Alt>$n"
  unbind "/xfwm4/custom/<Alt><Super>$n"
done

# Super + Numpad -> tiling: replaced by Alt + Numpad. Includes the NumLock-off
# fallbacks (KP_Home, KP_Up, KP_Begin, ...), which were dead weight anyway
# since Numlock defaults to on.
for k in KP_1 KP_2 KP_3 KP_4 KP_5 KP_6 KP_7 KP_8 KP_9 \
         KP_Home KP_Up KP_Page_Up KP_Left KP_Begin KP_Right \
         KP_End KP_Down KP_Next KP_Delete KP_Insert; do
  unbind "/xfwm4/custom/<Super>$k"
done

# Super+Alt+arrows were never managed by this script: they were left over in the
# channel from a manual experiment, with a scrambled quadrant mapping
# (Up -> tile_down_right_key, Down -> tile_down_left_key). Alt is now used for
# the numpad grid and the desktops, so they are dropped.
for k in Left Right Up Down; do
  unbind "/xfwm4/custom/<Super><Alt>$k"
done

# Duplicated Super+q.
unbind "/xfwm4/custom/<Super><Shift>q"
printf '\n'

# --- 1. Super: lanciatori e azioni sulle finestre (stile Arch/Omarchy) -------
bind_cmd "<Super>Return"               "alacritty"
bind_cmd "<Super>d"                    "rofi -show drun"
bind_cmd "<Super>w"                    "rofi -show window"
bind_cmd "<Super>e"                    "thunar"
bind_cmd "<Super>p"                    "xfce4-display-settings --minimal"
bind_cmd "<Print>"                     "xfce4-screenshooter -f -s $HOME/Pictures"

bind_wm "<Super>q"                     "close_window_key"
bind_wm "<Super>f"                     "fullscreen_key"

# Show desktop lives on Super+Shift+D because Super+D goes to the launcher.
bind_wm "<Super><Shift>d"              "show_desktop_key"

bind_wm "<Super>Left"                  "tile_left_key"
bind_wm "<Super>Right"                 "tile_right_key"
bind_wm "<Super>Up"                    "maximize_window_key"
bind_wm "<Super>Down"                  "hide_window_key"

# --- 2. Alt + numeri: griglia di tiling --------------------------------------
#  7 (Alto-SX)  |  8 (Alto-Metà)  |  9 (Alto-DX)
#  4 (SX-Metà)  |  5 (FULLSCREEN) |  6 (DX-Metà)
#  1 (Basso-SX) |  2 (Basso-Metà) |  3 (Basso-DX)
#
# The number row carries the same grid as the numpad, so either hand works and
# the shape of the gesture matches the shape of the screen.
bind_wm "<Alt>7"                       "tile_up_left_key"
bind_wm "<Alt>8"                       "tile_up_key"
bind_wm "<Alt>9"                       "tile_up_right_key"
bind_wm "<Alt>4"                       "tile_left_key"
bind_wm "<Alt>5"                       "fullscreen_key"
bind_wm "<Alt>6"                       "tile_right_key"
bind_wm "<Alt>1"                       "tile_down_left_key"
bind_wm "<Alt>2"                       "tile_down_key"
bind_wm "<Alt>3"                       "tile_down_right_key"

# --- 3. Alt + Numpad: stessa griglia -----------------------------------------
# Kept alongside the number row deliberately: two ways in, no overlap with the
# Super bindings above, and Alt is free on the keypad.
bind_wm "<Alt>KP_7"                    "tile_up_left_key"
bind_wm "<Alt>KP_8"                    "tile_up_key"
bind_wm "<Alt>KP_9"                    "tile_up_right_key"
bind_wm "<Alt>KP_4"                    "tile_left_key"
bind_wm "<Alt>KP_5"                    "fullscreen_key"
bind_wm "<Alt>KP_6"                    "tile_right_key"
bind_wm "<Alt>KP_1"                    "tile_down_left_key"
bind_wm "<Alt>KP_2"                    "tile_down_key"
bind_wm "<Alt>KP_3"                    "tile_down_right_key"

# --- 4. Super + numeri: desktop virtuali --------------------------------------
# Read from xfwm4 instead of a hardcoded list, otherwise Super+5 is bound to a
# desktop that does not exist (workspace_count is 4). That was a real bug: the
# shortcut looked configured but went nowhere.
WS_COUNT="$(xfconf-query -c xfwm4 -p /general/workspace_count -n 2>/dev/null || echo 4)"
case "$WS_COUNT" in
  ''|*[!0-9]*) WS_COUNT=4 ;;
esac

for n in $(seq 1 "$WS_COUNT"); do
  bind_wm "<Super>$n"                  "workspace_${n}_key"
  bind_wm "<Super><Shift>$n"           "move_window_workspace_${n}_key"
done

# --- 5. Super + Shift + numeri: la finestra segue al desk --------------------
# Same action, so that the move is reachable whichever block the digit is on.
for n in $(seq 1 "$WS_COUNT"); do
  bind_wm "<Alt><Shift>$n"             "move_window_workspace_${n}_key"
done

# No `xfwm4 --replace` here. xfsettingsd watches this channel and pushes new
# bindings to the running xfwm4 by itself, live. Restarting xfwm4 instead races
# that push: xfwm4 registers whichever grabs arrived before xfsettingsd caught
# up, which left a random subset of the digits live and the rest dead.

printf '\nDesktop: %s. Configurazione salvata e applicata con successo!\n' "$WS_COUNT"