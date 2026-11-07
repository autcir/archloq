#!/usr/bin/env bash
# =============================================================================
# verify-catppuccin — is the theme actually applied?
# =============================================================================
# Reads the live xfconf state instead of checking that files exist. A theme can
# be fully installed and still not applied, which is the failure mode that a
# file-presence check cannot see.
#
# Exits non-zero if any check fails, so install-scripts/app/09_dotfiles.sh can
# gate on it.
# =============================================================================

set -uo pipefail

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
failures=0

pass() { printf '  ok    %s\n' "$*"; }
fail() { printf '  FAIL  %s\n' "$*" >&2; failures=$((failures + 1)); }
info() { printf '  --    %s\n' "$*"; }

printf '== verifying Catppuccin Mocha ==\n\n'

need_x() {
  printf 'no DISPLAY. Cannot read the live XFCE state.\n' >&2
  exit 2
}
[[ -n "${DISPLAY:-}" ]] || need_x

# -----------------------------------------------------------------------------
# xfwm4 theme
# -----------------------------------------------------------------------------
if command -v xfconf-query >/dev/null 2>&1; then
  theme="$(xfconf-query -c xfwm4 -p /theme -n 2>/dev/null || true)"
  if [[ "$theme" == "mocha" ]]; then
    pass "xfwm4 theme is 'mocha'"
  elif [[ -n "$theme" ]]; then
    fail "xfwm4 theme is '$theme', expected 'mocha'"
  else
    fail "xfwm4 theme is unset; xfwm4 would fall back to the default theme"
  fi

  compositor="$(xfconf-query -c xfwm4 -p /general/use_compositing -n 2>/dev/null || echo false)"
  if [[ "$compositor" == "true" ]]; then
    pass "xfwm4 compositor is enabled (no external compositor)"
  else
    info "xfwm4 compositor is off; that is a valid choice, blur is simply unavailable"
  fi
else
  fail "xfconf-query not available"
fi

# -----------------------------------------------------------------------------
# Theme files actually present
# -----------------------------------------------------------------------------
theme_dir="$CONFIG_HOME/xfwm4/themes/mocha"
if [[ -d "$theme_dir" ]]; then
  n=$(find "$theme_dir" -name '*.xpm' | wc -l)
  if ((n >= 7)); then
    pass "$theme_dir has $n XPM assets"
  else
    fail "$theme_dir has only $n XPM assets (expected at least 7: 3 buttons x 2 states + menu)"
  fi
else
  fail "$theme_dir does not exist"
fi

# -----------------------------------------------------------------------------
# GTK / icon / cursor, through the real interfaces
# -----------------------------------------------------------------------------
if command -v gsettings >/dev/null 2>&1; then
  gtk="$(gsettings get org.gnome.desktop.interface gtk-theme 2>/dev/null || echo "''")"
  icons="$(gsettings get org.gnome.desktop.interface icon-theme 2>/dev/null || echo "''")"
  # libadwaita apps read these; GTK3-only apps read gtk-3.0/settings.ini instead.
  if [[ "$gtk" == "'Adwaita-dark'" ]]; then
    pass "GTK theme is Adwaita-dark (the reliable baseline)"
  elif [[ "$gtk" == "'"* ]]; then
    info "GTK theme is $gtk -- if it renders light, the theme has no GTK4 support"
  else
    fail "could not read the GTK theme"
  fi

  if [[ "$icons" == "'Papirus-Dark'" ]]; then
    pass "icon theme is Papirus-Dark"
  else
    fail "icon theme is $icons, expected 'Papirus-Dark'"
  fi
else
  info "gsettings not available; skipping GTK and icon checks"
fi

# The cursor xsettingsd reads is /Gtk/CursorThemeName, not /Net/CursorThemeName.
# Plenty of dotfiles get this wrong and the cursor silently never changes.
if command -v xfconf-query >/dev/null 2>&1; then
  cursor="$(xfconf-query -c xsettings -p /Gtk/CursorThemeName -n 2>/dev/null || true)"
  if [[ -n "$cursor" ]]; then
    pass "cursor theme is '$cursor' (read from /Gtk/CursorThemeName)"
  else
    fail "cursor theme unset in xsettings /Gtk/CursorThemeName"
  fi
fi

# -----------------------------------------------------------------------------
# Terminal
# -----------------------------------------------------------------------------
if [[ -f "$CONFIG_HOME/foot/foot.ini" ]]; then
  ttheme="$(sed -n 's/^theme=//p' "$CONFIG_HOME/foot/foot.ini" 2>/dev/null | head -1)"
  if [[ "$ttheme" == "mocha" ]]; then
    pass "foot terminal theme is mocha"
  else
    info "foot theme is '${ttheme:-unset}'"
  fi
else
  info "no foot config at $CONFIG_HOME/foot/foot.ini"
fi

# -----------------------------------------------------------------------------
# Shell
# -----------------------------------------------------------------------------
if command -v starship >/dev/null 2>&1; then
  if [[ -f "$CONFIG_HOME/starship/starship.toml" ]]; then
    pass "starship is installed and configured"
  else
    fail "starship is installed but has no config"
  fi
else
  info "starship not installed"
fi

# -----------------------------------------------------------------------------
# Known limitation, stated rather than hidden
# -----------------------------------------------------------------------------
printf '\n'
info "NOTE: libadwaita applications (GNOME Calculator, GNOME Text Editor, most"
info "      Flatpaks) ignore the GTK3 theme. Dark icons with a light app is the"
info "      expected result, not a broken install. See docs/REFORMAT-XFCE.md §10."

printf '\n'
if ((failures > 0)); then
  printf '%s check(s) failed\n' "$failures" >&2
  exit 1
fi
printf 'all checks passed\n'
