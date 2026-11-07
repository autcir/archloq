#!/usr/bin/env bash
# =============================================================================
# 20 — install the Xfce stack and the Catppuccin Mocha theme
# =============================================================================
# Idempotent. Safe to re-run.
#
# xfce4-goodies is deliberately NOT installed: it pulls in gigolo, extra gvfs
# helpers, a second terminal and an image viewer this setup has no use for. The
# individual plugins wanted here are listed explicitly instead.
# =============================================================================

set -euo pipefail

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
say()  { printf '==> %s\n' "$*"; }
ok()   { printf '  ok    %s\n' "$*"; }
warn() { printf '  warn  %s\n' "$*" >&2; }
skip() { printf '   --   %s\n' "$*"; }

say "installing the Xfce stack"
sudo pacman -S --needed --noconfirm \
  xfce4 xfce4-panel xfwm4 xfdesktop thunar \
  xfce4-session xfce4-settings xfconf xfce4-appfinder \
  xfce4-notifyd xfce4-screensaver xfce4-power-manager xfce4-panel-profiles \
  xfce4-clipman xfce4-whiskermenu-plugin xfce4-docklike-plugin \
  xfce4-screenshooter xfce4-pulseaudio-plugin xfce4-terminal mousepad \
  xorg-server xorg-xinit xorg-apps \
  pipewire pipewire-pulse wireplumber pavucontrol \
  gnome-keyring lxpolkit xbindkeys xdotool wmctrl \
  foot sddm \
  papirus-icon-theme adwaita-icon-theme \
  ttf-jetbrains-mono-nerd ttf-inter ttf-noto-sans \
  light bluez bluez-utils

for cursor in bibata-cursor bibata-cursor-classic; do
  if pacman -Si "$cursor" >/dev/null 2>&1; then
    sudo pacman -S --needed --noconfirm "$cursor" && ok "$cursor" && break
  fi
done

# ---------------------------------------------------------------------------
say "Catppuccin Mocha theme assets"
theme_src="$(cd "$(dirname "${BASH_SOURCE[0]}")/../config" && pwd)/xfwm4/themes/mocha"
theme_dst="$CONFIG_HOME/xfwm4/themes/mocha"

if [[ -d "$theme_src" ]]; then
  mkdir -p "$theme_dst"
  cp -r "$theme_src/." "$theme_dst/"
  n=$(find "$theme_dst" -name '*.xpm' | wc -l)
  ok "xfwm4 mocha theme installed ($n XPM assets)"
else
  warn "theme source missing at $theme_src"
fi

# The generator is in the repo so the palette lives in one place.
if [[ -f "$(dirname "${BASH_SOURCE[0]}")/../tools/gen-xfwm4-theme.py" ]]; then
  skip "assets regenerate with: python3 tools/gen-xfwm4-theme.py config/xfwm4/themes/mocha"
fi

# Kvantum is retained for the Qt applications (SDDM among them), not for Xfce.
kv_src="$(cd "$(dirname "${BASH_SOURCE[0]}")/../config" && pwd)/kvantum"
if [[ -d "$kv_src/catppuccin-mocha-blue" ]]; then
  mkdir -p "$CONFIG_HOME/Kvantum"
  cp -r "$kv_src/catppuccin-mocha-blue" "$CONFIG_HOME/Kvantum/"
  ok "Kvantum Catppuccin Mocha Blue installed (Qt apps + SDDM)"
fi

# ---------------------------------------------------------------------------
if [[ -n "${DISPLAY:-}" ]] && command -v xfconf-query >/dev/null 2>&1; then
  say "applying the xfwm4 theme"
  xfconf-query -c xfwm4 -p /theme -n -t string -s mocha && ok "xfwm4 theme set"
else
  skip "no DISPLAY: set the xfwm4 theme after logging in (xfce4-settings > Window Manager > Theme)"
fi

ok "20-xfce complete"
