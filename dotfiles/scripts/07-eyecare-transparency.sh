#!/usr/bin/env bash
# 07-eyecare-transparency.sh
# Trasparenza + blur + eye-care settings per Catppuccin Mocha su KDE Plasma 6.
#
# Cosa fa:
#   1. Assicura che il compositore KWin sia attivo (necessario per blur).
#   2. Merge NON distruttivo di eye-care in ~/.config/kwinrc via kwriteconfig6
#      (preserva Desktops/Tiling/Plugins/utente. Backup .loq-bak prima).
#   3. Merge NON distruttivo di eye-care in ~/.config/kdeglobals via kwriteconfig6.
#   4. Reconfigura KWin + Plasma.
#   5. Hint: wlsunset per ridurre blue light sera.
#
# Idempotente: rieseguibile, sovrascrive solo le chiavi eye-care marcate.
# NON usa grep -v/sed sul file intero: ogni chiave scritta via kwriteconfig6.
#
# Cosa NON tocca:
#   - systemd / boot / display manager
#   - layout tastiera / locale
#   - network / firewall
#   - sezioni [Desktops] [Tiling] [Plugins] [Xwayland] [org.kde.kdecoration2] utente
set -euo pipefail

say()  { printf '\n\033[1;36m[INFO]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[OK]\033[0m  %s\n' "$*"; }
skip() { printf '\033[1;33m[SKIP]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;31m[WARN]\033[0m %s\n' "$*"; }

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTROOT="$(cd "$HERE/.." && pwd)"
KWINRC="$HOME/.config/kwinrc"
KDEGLOBALS="$HOME/.config/kdeglobals"

# --- helper: scrivi chiave solo se kwriteconfig6 disponibile ----------------
kw_set() {
  local file="$1" group="$2" key="$3" val="$4"
  if command -v kwriteconfig6 >/dev/null 2>&1; then
    kwriteconfig6 --file "$file" --group "$group" --key "$key" "$val"
  else
    skip "kwriteconfig6 assente: imposta manualmente $group/$key = $val"
  fi
}

# --- 1. Compositore attivo --------------------------------------------------
say "Verifica compositore KWin (necessario per blur/trasparenza)"
mkdir -p "$HOME/.config"
if [ ! -f "$KWINRC" ]; then
  touch "$KWINRC"
  ok "creato $KWINRC vuoto"
else
  skip "$KWINRC già presente"
fi

# --- 2. Backup + merge kwinrc (NON distruttivo) ----------------------------
say "Backup kwinrc + merge eye-care (non distruttivo)"
if [ ! -f "$KWINRC.loq-bak" ]; then
  cp -a "$KWINRC" "$KWINRC.loq-bak"
  ok "backup kwinrc: $KWINRC.loq-bak"
else
  skip "backup kwinrc già esistente"
fi
# Compositore
kw_set "$KWINRC" "Compositing" "Backend" "OpenGL"
# GLColorCorrection NON forzato: l'utente puó avere SRGB o true (lascia esistente).
kw_set "$KWINRC" "Compositing" "Enabled" "true"
# Blur eye-care
kw_set "$KWINRC" "Effect-blur" "NoiseStrength" "0"
kw_set "$KWINRC" "Effect-blur" "BlurStrength" "12"
# Contrast effect
kw_set "$KWINRC" "Effect-contrast" "Enabled" "true"
# Disabilita effetti che stancano
kw_set "$KWINRC" "Effect-wobblywindows" "Enabled" "false"
# Magnifier utile (zoom al bisogno)
kw_set "$KWINRC" "Effect-magnifier" "Enabled" "true"
ok "kwinrc eye-care applicato (merge per-chiave, sezioni utente preservate)"

# --- 3. Backup + kdeglobals eye-care (NON distruttivo) ----------------------
say "Backup kdeglobals + merge eye-care"
if [ ! -f "$KDEGLOBALS" ]; then
  touch "$KDEGLOBALS"
fi
if [ ! -f "$KDEGLOBALS.loq-bak" ]; then
  cp -a "$KDEGLOBALS" "$KDEGLOBALS.loq-bak"
  ok "backup kdeglobals: $KDEGLOBALS.loq-bak"
else
  skip "backup kdeglobals già esistente"
fi
kw_set "$KDEGLOBALS" "KDE" "contrast" "4"
kw_set "$KDEGLOBALS" "General" "ColorScheme" "CatppuccinMochaBlue"
# Font eye-care UI: Inter Variable (pacman: inter-font)
kw_set "$KDEGLOBALS" "General" "font" "Inter Variable,11,-1,5,50,0,0,0,0,0"
kw_set "$KDEGLOBALS" "General" "menuFont" "Inter Variable,10,-1,5,50,0,0,0,0,0"
kw_set "$KDEGLOBALS" "General" "smallestReadableFont" "Inter Variable,8,-1,5,50,0,0,0,0,0"
# fixed (terminale) JetBrains Nerd
kw_set "$KDEGLOBALS" "General" "fixed" "JetBrainsMono Nerd Font,11,-1,5,50,0,0,0,0,0"
ok "kdeglobals eye-care applicato (font UI Inter Variable, fixed JetBrains Nerd, scheme CatppuccinMochaBlue)"

# --- 4. Ricarica KWin / Plasma ----------------------------------------------
say "Reload KWin + Plasma"
if command -v qdbus6 >/dev/null 2>&1; then
  qdbus6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1 && ok "KWin reconfigurato" || warn "qdbus6 reconfigure fallito"
else
  warn "qdbus6 non trovato: riloggati o 'systemctl --user restart plasma-kwin_wayland'"
fi

# --- 5. Blue-light filter hint ----------------------------------------------
say "Blue-light filter opzionale (sera)"
if command -v wlsunset >/dev/null 2>&1; then
  skip "wlsunset già installato"
else
  echo "  Per ridurre la luce blu la sera (eye-care notturno):"
  echo "    sudo pacman -S wlsunset"
  echo "    wlsunset -T 4500 -t 3000 -l 40.7 -L 14.6   # esempio Salerno"
fi

ok "07-eyecare-transparency completa"
echo ""
echo "  Verifica: apri Ghostty/Konsole sopra il wallpaper e controlla"
echo "  che si veda il blur morbido Catppuccin Mocha dietro. Se la trasparenza \u00e8 troppo forte,"
echo "  alza background-opacity in config/ghostty/config (0.92 consigliato)."
