#!/usr/bin/env bash
# =============================================================================
# 09 — Papirus icon themes
# =============================================================================
# Applies through gsettings, which is what both GTK3 and GTK4/libadwaita read.
# The previous version wrote ~/.config/kdeglobals with kwriteconfig6 and
# refreshed PlasmaShell over D-Bus: neither applies on Xfce.
# =============================================================================

set -euo pipefail
say()  { printf '==> %s\n' "$*"; }
ok()   { printf '  ok  %s\n' "$*"; }
warn() { printf 'warn  %s\n' "$*" >&2; }

say "installing Papirus icon themes"
sudo pacman -S --needed --noconfirm papirus-icon-theme adwaita-icon-theme

say "selecting Papirus-Dark for both icon sizes"
# icon-theme drives the 16px icons, icon-theme at non-16 sizes is separate; both
# must agree or GTK picks inconsistently between toolbars and menus.
gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Dark'

# The theme caches renderings under its own directory; without a refresh some
# toolbars keep the old icons until logout.
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
  sudo gtk-update-icon-cache -f -t /usr/share/icons/Papirus-Dark >/dev/null 2>&1 || true
  ok "icon cache refreshed"
fi

ok "Papirus-Dark applied. Log out and back in if icons look stale."
