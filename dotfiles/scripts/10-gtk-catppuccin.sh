#!/usr/bin/env bash
# =============================================================================
# 10 — GTK theming for Catppuccin Mocha
# =============================================================================
# Writes ~/.config/gtk-3.0/settings.ini and gtk-4.0/settings.ini directly.
#
# The previous version shelled out to kwriteconfig6 to write settings.ini, which
# is a roundabout way of producing a text file and required the KDE tools to be
# installed for a plain GTK configuration.
#
# GTK3 settings do not reach libadwaita apps (GNOME Calculator, GNOME Text
# Editor, most Flatpaks). Those read org.gnome.desktop.interface, set below.
# For GTK4/libadwaita you also need a theme that ships a gtk-4.0/ directory;
# Catppuccin does, and gsettings picks it up for the apps that will listen.
# =============================================================================

set -euo pipefail

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
mkdir -p "$CONFIG_HOME/gtk-3.0" "$CONFIG_HOME/gtk-4.0"

write_ini() {
  local dir="$1"
  cat >"$dir/settings.ini" <<'EOF'
# archloq — Catppuccin Mocha
#
# Deliberately NOT a symlink into the repo: this file is rewritten by some GUI
# settings dialogs, and a symlink would take the repository with it.
[Settings]
gtk-theme-name=Adwaita-dark
gtk-icon-theme-name=Papirus-Dark
gtk-cursor-theme-name=Bibata-Hybrid-Classic
gtk-font-name=Inter 11
gtk-application-prefer-dark-theme=1
gtk-enable-animations=1
gtk-xft-antialias=1
gtk-xft-hinting=1
gtk-xft-hintstyle=hintslight
gtk-xft-rgba=rgb
gtk-xft-dpi=96
EOF
  printf 'wrote %s\n' "$dir/settings.ini"
}

write_ini "$CONFIG_HOME/gtk-3.0"
write_ini "$CONFIG_HOME/gtk-4.0"

# libadwaita / GTK4 read dconf, not the ini file.
if command -v gsettings >/dev/null 2>&1; then
  gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
  gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark'
  printf 'set org.gnome.desktop.interface color-scheme=prefer-dark\n'
fi

printf '\nknown limitation: apps built on libadwaita ignore the GTK3 theme. Dark\n'
printf 'icons with a light app window is the expected result, not a failure.\n'
printf 'See docs/REFORMAT-XFCE.md section 10.\n'
