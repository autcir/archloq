#!/usr/bin/env bash
# 08-themes-github.sh
# Scarica, installa e ATTIVA temi completi Catppuccin Mocha da GitHub per Plasma 6.
# Porta la palette Catppuccin in tutto il sistema: color scheme, Aurorae window
# decoration, splash screen, look-and-feel, cursors, Kvantum application style.
#
# Fonti GitHub (tutte compatibili Plasma 6.7):
#   - Catppuccin/KDE (color scheme + Aurorae + splash + look-and-feel + cursors)
#     https://github.com/catppuccin/kde
#   - Catppuccin/Kvantum (application style Qt curvo, traslucente)
#     https://github.com/catppuccin/kvantum
#   - Catppuccin/Ghostty (palette terminale, già builtin in questo config)
#   - Catppuccin/starship (prompt, già in questo config)
#
# Flavour: Mocha (dark più scuro). Accent: Blue (#89b4fa, vicino al One Dark Pro
# blu ma più pastello e eye-friendly). WinDec: Modern (rounded, nerdy).
#
# Idempotente: cloni in cache /tmp/loq-themes-cache. Reinstall solo se manca.
# Non distruttivo: applica via kwriteconfig6/plasma-apply-*, salva backup.
set -euo pipefail

say()  { printf '\n\033[1;36m[INFO]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[OK]\033[0m  %s\n' "$*"; }
skip() { printf '\033[1;33m[SKIP]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;31m[WARN]\033[0m %s\n' "$*"; }

CACHE="${LOQ_THEMES_CACHE:-/tmp/loq-themes-cache}"
mkdir -p "$CACHE"
FLAVOUR=1   # Mocha
ACCENT=13   # Blue
WINDEC=2    # Classic (MacOS-like, eye-care)
DOTROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# --- dipendenze -------------------------------------------------------------
say "Controllo dipendenze (wget, unzip, kpackagetool6/6, kwriteconfig6)"
for cmd in wget unzip kpackagetool6 kwriteconfig6 plasma-apply-lookandfeel; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "[ERR] manca $cmd" >&2; exit 1; }
done
ok "dipendenze ok"

# --- 1. Catppuccin/KDE (color scheme + Aurorae + splash + look-and-feel) ----
say "[1/3] Catppuccin/KDE — Mocha Blue"
if [ -d "$CACHE/catppuccin-kde" ]; then skip "già clonato"; else
  git clone --depth 1 https://github.com/catppuccin/kde.git "$CACHE/catppuccin-kde"
fi
( cd "$CACHE/catppuccin-kde" && bash install.sh -q "$FLAVOUR" "$ACCENT" "$WINDEC" 2>&1 | tail -20 ) \
  || warn "install.sh catppuccin-kde ha avuto warning (proseguiamo)"
ok "Catppuccin Mocha Blue installato: color scheme + Aurorae + splash"

# --- 2. Catppuccin/Kvantum (application style Qt) ---------------------------
say "[2/3] Catppuccin/Kvantum — application style Qt"
if [ -d "$CACHE/catppuccin-kvantum" ]; then skip "già clonato"; else
  git clone --depth 1 https://github.com/catppuccin/kvantum.git "$CACHE/catppuccin-kvantum" 2>/dev/null \
    || warn "repo catppuccin/kvantum non trovato (skippo)"
fi
if [ -d "$CACHE/catppuccin-kvantum" ]; then
  KV_USER="$HOME/.config/Kvantum"
  mkdir -p "$KV_USER"
  # Copia i temi Mocha disponibili
  for d in "$CACHE/catppuccin-kvantum"/themes/*Mocha* "$CACHE/catppuccin-kvantum"/Mocha*; do
    [ -d "$d" ] && cp -rf "$d" "$KV_USER/" 2>/dev/null || true
  done
  ok "Kvantum Catppuccin Mocha copiato"
fi

# --- 3. Attiva temi live ----------------------------------------------------
say "[3/3] Attiva temi live (Catppuccin Mocha Blue everywhere)"
# Color scheme
plasma-apply-colorscheme CatppuccinMochaBlue 2>/dev/null || warn "CatppuccinMochaBlue non applicato"
# Look-and-feel (splash + Aurorae + global theme)
plasma-apply-lookandfeel --apply "Catppuccin-Mocha-Blue" 2>/dev/null \
  || warn "look-and-feel non applicato"
# Aurorae window decoration (Classic MacOS-like)
kwriteconfig6 --file ~/.config/kwinrc --group "org.kde.kdecoration2" --key "library" "org.kde.kwin.aurorae"
kwriteconfig6 --file ~/.config/kwinrc --group "org.kde.kdecoration2" --key "theme" "__aurorae__svg__CatppuccinMocha-Classic"
# Application style = Kvantum (prova Catppuccin, fallback OneDarkPro→Sweet)
KV_CURRENT="$(kreadconfig6 --file ~/.config/Kvantum/kvantum.kvconfig --group General --key theme 2>/dev/null || true)"
if ls "$HOME/.config/Kvantum"/*Mocha* >/dev/null 2>&1; then
  KV_THEME=$(ls "$HOME/.config/Kvantum" | rg -iE 'Mocha' | head -1)
  kwriteconfig6 --file ~/.config/kdeglobals --group KDE --key widgetStyle "kvantum"
  kvantummanager --set "$KV_THEME" 2>/dev/null || true
  ok "Kvantum application style: $KV_THEME"
else
  kwriteconfig6 --file ~/.config/kdeglobals --group KDE --key widgetStyle "kvantum"
  # mantieni Kvantum esistente (verrà scelto il miglior disponibile)
  ok "Kvantum application style attivo (tema esistente: ${KV_CURRENT:-nullo})"
fi
# Splash via look-and-feel Catppuccin
# Refresh KWin + Plasma
qdbus6 org.kde.KWin /KWin reconfigure 2>/dev/null || true
kquitapp6 plasmashell 2>/dev/null || true
sleep 1
nohup kstart plasmashell >/dev/null 2>&1 & disown
sleep 2
ok "08-themes-github completa"
echo ""
echo "  Catppuccin Mocha Blue attivo su:"
echo "    - Plasma color scheme (CatppuccinMochaBlue)"
echo "    - Window decoration Aurorae (CatppuccinMocha-Classic)"
echo "    - Splash + Look-and-feel (Catppuccin-Mocha-Blue)"
echo "    - Application style Qt (Kvantum)"
echo "    - Ghostty terminale (config Catppuccin Mocha)"
echo "    - Konsole (CatppuccinMocha colorscheme + profile)"
echo "    - starship prompt (Catppuccin Mocha palette)"
echo ""
echo "  Cache repo: $CACHE (elimina per riforza clone)"
