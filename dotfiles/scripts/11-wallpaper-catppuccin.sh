#!/usr/bin/env bash
# 11-wallpaper-catppuccin.sh — Scarica e applica wallpaper Catppuccin Mocha per KDE Plasma 6.
# Source: catppuccin/wallpapers (GitHub) — raccolta curata, license permissiva.
# Idempotente: skip download se già presente.
set -euo pipefail

say()  { printf '\n\033[1;35m[INFO]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[OK]\033[0m  %s\n' "$*"; }
skip() { printf '\033[1;33m[SKIP]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;31m[WARN]\033[0m %s\n' "$*"; }

WALL_DIR="$HOME/.local/share/wallpapers/catppuccin-mocha"
mkdir -p "$WALL_DIR"

# URL wallpaper: uso raw GitHub di catppuccin/wallpapers (selezione Mocha curata)
# Scegliamo alcune immagini rappresentative e leggere.
declare -A WALLS=(
  ["mocha-cat.png"]="https://raw.githubusercontent.com/zhichaoh/catppuccin-wallpapers/main/cat/mocha.png"
  ["mocha-abstract-blue.png"]="https://raw.githubusercontent.com/zhichaoh/catppuccin-wallpapers/main/landscapes/evening-sky.png"
  ["mocha-arch.png"]="https://raw.githubusercontent.com/zhichaoh/catppuccin-wallpapers/main/os/arch.png"
)

# --- 1. Download wallpapers -------------------------------------------------
say "Download wallpapers Catppuccin Mocha"
DOWNLOADED=0
for name in "${!WALLS[@]}"; do
  dest="$WALL_DIR/$name"
  if [ -f "$dest" ]; then
    skip "$name già presente"
  else
    url="${WALLS[$name]}"
    if wget -q --timeout=15 -O "$dest" "$url" 2>/dev/null; then
      ok "Scaricato: $name"
      DOWNLOADED=$((DOWNLOADED + 1))
    else
      warn "Download fallito: $name ($url)"
      rm -f "$dest"
    fi
  fi
done

# --- 2. Cerca il migliore wallpaper disponibile -----------------------------
say "Selezione wallpaper da applicare"
BEST_WALL=""
# Priorità: arch > cat > abstract
for candidate in \
  "$WALL_DIR/mocha-arch.png" \
  "$WALL_DIR/mocha-cat.png" \
  "$WALL_DIR/mocha-abstract-blue.png"; do
  if [ -f "$candidate" ]; then
    BEST_WALL="$candidate"
    break
  fi
done

# Fallback: usa arch-start.png dal repo locale (già nel repo)
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTROOT="$(cd "$HERE/.." && pwd)"
if [ -z "$BEST_WALL" ] && [ -f "$DOTROOT/wallpapers/arch-start.png" ]; then
  cp "$DOTROOT/wallpapers/arch-start.png" "$WALL_DIR/arch-start.png"
  BEST_WALL="$WALL_DIR/arch-start.png"
  ok "Fallback: arch-start.png dal repo locale"
fi

# --- 3. Applica wallpaper via plasma-apply-wallpaperimage --------------------
if [ -n "$BEST_WALL" ]; then
  say "Applica wallpaper: $BEST_WALL"
  if command -v plasma-apply-wallpaperimage >/dev/null 2>&1; then
    plasma-apply-wallpaperimage "$BEST_WALL" \
      && ok "Wallpaper applicato: $BEST_WALL" \
      || warn "plasma-apply-wallpaperimage fallito"
  else
    warn "plasma-apply-wallpaperimage non trovato."
    echo "  Applica manualmente: System Settings → Wallpaper → $BEST_WALL"
  fi
else
  warn "Nessun wallpaper disponibile. Controlla la connessione o aggiungi file in $WALL_DIR"
fi

ok "11-wallpaper-catppuccin completa"
echo ""
echo "  Wallpapers disponibili in: $WALL_DIR"
ls "$WALL_DIR" 2>/dev/null | sed 's/^/    /'
echo ""
echo "  Per applicare un altro wallpaper manualmente:"
echo "    plasma-apply-wallpaperimage $WALL_DIR/<nome>.png"
