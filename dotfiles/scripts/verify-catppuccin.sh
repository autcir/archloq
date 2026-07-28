#!/usr/bin/env bash
# verify-catppuccin.sh — Verifica stato completo rice Catppuccin Mocha su KDE Plasma 6.
# Output: lista di check con ✅ / ❌ per ogni componente.
set -uo pipefail

# Returns the basename of the first entry in $1 matching glob $2, or nothing.
# Replaces `ls | grep`, which breaks on names containing spaces.
first_match() {
  local dir="$1" pattern="$2" c
  for c in "$dir"/$pattern; do
    [ -e "$c" ] || continue
    basename "$c"
    return 0
  done
  return 1
}


PASS=0
FAIL=0
WARN=0

pass() { printf '\033[1;32m  ✅ %s\033[0m\n' "$*"; PASS=$((PASS+1)); }
fail() { printf '\033[1;31m  ❌ %s\033[0m\n' "$*"; FAIL=$((FAIL+1)); }
warn() { printf '\033[1;33m  ⚠️  %s\033[0m\n' "$*"; WARN=$((WARN+1)); }

echo ""
echo "╭─────────────────────────────────────────────────────╮"
echo "│   Catppuccin Mocha Rice — Verifica Sistema           │"
echo "│   KDE Plasma 6 + Wayland — Lenovo LOQ               │"
echo "╰─────────────────────────────────────────────────────╯"
echo ""

# --- Plasma Color Scheme ----------------------------------------------------
echo "🎨 Plasma Color Scheme"
CS=$(kreadconfig6 --file ~/.config/kdeglobals --group General --key ColorScheme 2>/dev/null)
if echo "$CS" | grep -qi "catppuccin"; then
  pass "Color scheme: $CS"
else
  fail "Color scheme non Catppuccin: '$CS'"
fi

# --- Kvantum ----------------------------------------------------------------
echo ""
echo "🖼  Kvantum Application Style"
KV=$(kreadconfig6 --file ~/.config/Kvantum/kvantum.kvconfig --group General --key theme 2>/dev/null)
if echo "$KV" | grep -qi "catppuccin\|mocha"; then
  pass "Kvantum theme: $KV"
else
  fail "Kvantum non Catppuccin: '$KV'"
fi
KDE_STYLE=$(kreadconfig6 --file ~/.config/kdeglobals --group KDE --key widgetStyle 2>/dev/null)
if [ "$KDE_STYLE" = "kvantum" ]; then
  pass "KDE widget style: kvantum"
else
  warn "KDE widget style non è kvantum: '$KDE_STYLE'"
fi

# --- Look and Feel ----------------------------------------------------------
echo ""
echo "🌐 Look & Feel"
LAF=$(first_match ~/.local/share/plasma/look-and-feel "*[Cc]atppuccin*" || true)
if [ -n "$LAF" ]; then
  pass "Look-and-feel installato: $LAF"
else
  fail "Look-and-feel Catppuccin non trovato"
fi

# --- Aurorae Window Decoration ----------------------------------------------
echo ""
echo "🪟  Window Decoration (Aurorae)"
AURORAE=$(first_match ~/.local/share/aurorae/themes "*[Cc]atppuccin*" || true)
if [ -n "$AURORAE" ]; then
  pass "Aurorae theme: $AURORAE"
else
  fail "Nessun theme Aurorae Catppuccin trovato"
fi

# --- Cursors ----------------------------------------------------------------
echo ""
echo "🖱  Cursor Theme"
CURSOR=$(kreadconfig6 --file ~/.config/kcminputrc --group Mouse --key cursorTheme 2>/dev/null)
if echo "$CURSOR" | grep -qi "catppuccin"; then
  pass "Cursor theme: $CURSOR"
else
  warn "Cursor non Catppuccin in kcminputrc: '$CURSOR'"
  # Controlla anche gtk
  GTK_CURSOR=$(grep "gtk-cursor-theme-name" ~/.config/gtk-3.0/settings.ini 2>/dev/null | cut -d= -f2)
  if echo "$GTK_CURSOR" | grep -qi "catppuccin"; then
    pass "Cursor GTK: $GTK_CURSOR"
  fi
fi

# --- Splash Screen ----------------------------------------------------------
echo ""
echo "💫 Splash Screen"
SPLASH=$(kreadconfig6 --file ~/.config/ksplashrc --group KSplash --key Theme 2>/dev/null)
if echo "$SPLASH" | grep -qi "catppuccin"; then
  pass "Splash: $SPLASH"
else
  warn "Splash non Catppuccin: '$SPLASH' (None = disabilitato, ok)"
fi

# --- Icon Theme -------------------------------------------------------------
echo ""
echo "🗂  Icon Theme"
ICONS=$(kreadconfig6 --file ~/.config/kdeglobals --group Icons --key Theme 2>/dev/null)
if echo "$ICONS" | grep -qi "papirus"; then
  pass "Icon theme: $ICONS (Papirus ✓)"
elif echo "$ICONS" | grep -qi "catppuccin"; then
  pass "Icon theme: $ICONS"
else
  warn "Icon theme non Papirus/Catppuccin: '$ICONS' — esegui 09-icons-papirus.sh"
fi

# --- GTK Theme --------------------------------------------------------------
echo ""
echo "🐧 GTK Theme"
GTK_THEME=$(grep "gtk-theme-name" ~/.config/gtk-3.0/settings.ini 2>/dev/null | cut -d= -f2)
if echo "$GTK_THEME" | grep -qi "catppuccin"; then
  pass "GTK3 theme: $GTK_THEME"
else
  warn "GTK3 non Catppuccin: '$GTK_THEME' — esegui 10-gtk-catppuccin.sh"
fi

# --- Ghostty ----------------------------------------------------------------
echo ""
echo "👻 Ghostty Terminal"
GHOSTTY_CONF="$HOME/.config/ghostty/config"
if [ -f "$GHOSTTY_CONF" ] && grep -q "catppuccin\|1e1e2e\|cdd6f4" "$GHOSTTY_CONF" 2>/dev/null; then
  pass "Ghostty: Catppuccin Mocha config presente"
else
  warn "Ghostty config non trovata o non Catppuccin (controlla ~/.config/ghostty/config)"
fi

# --- Konsole ----------------------------------------------------------------
echo ""
echo "📟 Konsole"
if [ -f ~/.local/share/konsole/CatppuccinMocha.colorscheme ]; then
  pass "Konsole colorscheme: CatppuccinMocha"
else
  fail "CatppuccinMocha.colorscheme non installata in ~/.local/share/konsole/"
fi

# --- Starship ---------------------------------------------------------------
echo ""
echo "🚀 Starship Prompt"
STARSHIP_CONF="$HOME/.config/starship.toml"
if [ -f "$STARSHIP_CONF" ] && grep -q "catppuccin\|89b4fa\|cba6f7\|1e1e2e" "$STARSHIP_CONF" 2>/dev/null; then
  pass "Starship: Catppuccin Mocha palette"
else
  warn "starship.toml non trovato o non Catppuccin (controlla ~/.config/starship.toml)"
fi

# --- Wallpaper --------------------------------------------------------------
echo ""
echo "🏔  Wallpaper"
WALL_DIR="$HOME/.local/share/wallpapers"
WALL=$(first_match "$WALL_DIR" "*[Cc]atppuccin*" || first_match "$WALL_DIR" "*[Mm]ocha*" || true)
if [ -n "$WALL" ]; then
  pass "Wallpaper Catppuccin trovato: $WALL"
else
  warn "Nessun wallpaper Catppuccin in $WALL_DIR — esegui 11-wallpaper-catppuccin.sh"
fi

# --- KWin blur --------------------------------------------------------------
echo ""
echo "🌫  KWin Blur + Compositing"
BLUR=$(kreadconfig6 --file ~/.config/kwinrc --group "Effect-blur" --key BlurStrength 2>/dev/null)
COMP=$(kreadconfig6 --file ~/.config/kwinrc --group Compositing --key Enabled 2>/dev/null)
if [ "$COMP" = "true" ]; then
  pass "Compositing: attivo"
else
  warn "Compositing non impostato esplicitamente: '$COMP'"
fi
if [ -n "$BLUR" ]; then
  pass "Blur strength: $BLUR"
else
  warn "BlurStrength non impostato (usa 07-eyecare-transparency.sh)"
fi

# --- Riepilogo --------------------------------------------------------------
echo ""
echo "╭──────────────────────────────────────╮"
printf "│  ✅ PASS: %-4d  ❌ FAIL: %-4d  ⚠️  WARN: %-4d │\n" "$PASS" "$FAIL" "$WARN"
echo "╰──────────────────────────────────────╯"
echo ""

if [ "$FAIL" -eq 0 ]; then
  echo "  🎉 Rice Catppuccin Mocha completo! Ottimo lavoro."
elif [ "$FAIL" -le 2 ]; then
  echo "  🔧 Quasi completo — risolvi i FAIL sopra."
else
  echo "  ⚡ Diversi componenti mancanti. Esegui gli script nella sequenza:"
  echo "     bash install.sh --yes"
fi
echo ""
