#!/usr/bin/env bash
# reapply.sh — Riapplica TUTTO il rice Catppuccin Mocha in modo SICURO dopo reboot/reset.
# NESSUN plugin KWin di terze parti. NESSUNA kwinrulesrc opacity globale.
# Testato su KDE Plasma 6.7.2 + Wayland — Lenovo LOQ 17IRX10.
#
# Uso: bash reapply.sh
# Sicuro: rieseguibile N volte, non rompe il desktop.
set -euo pipefail

ok()   { printf '\033[1;32m  ✅ %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m  ⚠️  %s\033[0m\n' "$*"; }
say()  { printf '\n\033[1;35m[%s]\033[0m %s\n' "$1" "$2"; }

echo ""
echo "╭──────────────────────────────────────────────────────╮"
echo "│  Catppuccin Mocha — Reapply completo (SAFE mode)     │"
echo "│  KDE Plasma 6 + Wayland — Lenovo LOQ                 │"
echo "╰──────────────────────────────────────────────────────╯"
echo ""

say "1/8" "Color scheme + Look-and-feel"
plasma-apply-colorscheme CatppuccinMochaBlue 2>/dev/null \
  && ok "Color scheme: CatppuccinMochaBlue" \
  || warn "plasma-apply-colorscheme non disponibile"
plasma-apply-lookandfeel --apply "Catppuccin-Mocha-Blue" 2>/dev/null \
  && ok "Look-and-feel: Catppuccin-Mocha-Blue" \
  || warn "look-and-feel non applicato"

say "2/8" "Kvantum application style"
kvantummanager --set catppuccin-mocha-blue 2>/dev/null && ok "Kvantum: catppuccin-mocha-blue"
kwriteconfig6 --file ~/.config/kdeglobals --group KDE --key widgetStyle "kvantum"
ok "Widget style: kvantum"

say "3/8" "Icon theme"
kwriteconfig6 --file ~/.config/kdeglobals --group Icons --key Theme "Papirus-Dark"
ok "Icons: Papirus-Dark (folder color: blue catppuccin)"

say "4/8" "Font UI sistema"
kwriteconfig6 --file ~/.config/kdeglobals --group General --key font        "Inter,11,-1,5,400,0,0,0,0,0"
kwriteconfig6 --file ~/.config/kdeglobals --group General --key menuFont    "Inter,10,-1,5,400,0,0,0,0,0"
kwriteconfig6 --file ~/.config/kdeglobals --group General --key smallestReadableFont "Inter,8,-1,5,400,0,0,0,0,0"
kwriteconfig6 --file ~/.config/kdeglobals --group General --key toolBarFont "Inter,10,-1,5,400,0,0,0,0,0"
kwriteconfig6 --file ~/.config/kdeglobals --group General --key fixed       "JetBrainsMono Nerd Font,11,-1,5,400,0,0,0,0,0"
ok "Fonts: Inter 11pt UI | JetBrainsMono Nerd 11pt mono"

say "5/8" "Cursor + Splash + Window decoration"
kwriteconfig6 --file ~/.config/kcminputrc --group Mouse --key cursorTheme "catppuccin-mocha-blue-cursors"
ok "Cursor: catppuccin-mocha-blue-cursors"
kwriteconfig6 --file ~/.config/ksplashrc --group KSplash --key Theme "Catppuccin-Mocha-Blue"
ok "Splash: Catppuccin-Mocha-Blue"
kwriteconfig6 --file ~/.config/kwinrc --group "org.kde.kdecoration2" --key library "org.kde.kwin.aurorae"
kwriteconfig6 --file ~/.config/kwinrc --group "org.kde.kdecoration2" --key theme "__aurorae__svg__CatppuccinMocha-Classic"
ok "Window decoration: CatppuccinMocha-Classic (Aurorae)"

say "6/8" "KWin blur nativo (safe — NO plugin terze parti)"
# ⚠️  NON usare kwin-effects-better-blur-dx: rompe input Wayland su Plasma 6.7
kwriteconfig6 --file ~/.config/kwinrc --group Plugins --key blurEnabled       true
kwriteconfig6 --file ~/.config/kwinrc --group Plugins --key contrastEnabled   true
# Assicurati che plugin terze parti siano DISABILITATI
kwriteconfig6 --file ~/.config/kwinrc --group Plugins --key better_blur_dxEnabled false 2>/dev/null || true
kwriteconfig6 --file ~/.config/kwinrc --group Effect-blur --key BlurStrength 12
kwriteconfig6 --file ~/.config/kwinrc --group Effect-blur --key NoiseStrength  0
ok "KWin blur nativo: BlurStrength=12 NoiseStrength=0"

say "7/8" "Kvantum trasparenza (safe)"
KVCONFIG="$HOME/.config/Kvantum/catppuccin-mocha-blue/catppuccin-mocha-blue.kvconfig"
if [ -f "$KVCONFIG" ]; then
  sed -i 's/^reduce_window_opacity=.*/reduce_window_opacity=15/'  "$KVCONFIG"
  sed -i 's/^translucent_windows=.*/translucent_windows=true/'    "$KVCONFIG"
  sed -i 's/^blurring=.*/blurring=true/'                          "$KVCONFIG"
  sed -i 's/^popup_blurring=.*/popup_blurring=true/'              "$KVCONFIG"
  sed -i 's/^blur_konsole=.*/blur_konsole=true/'                  "$KVCONFIG"
  sed -i 's/^blur_translucent=.*/blur_translucent=true/'          "$KVCONFIG"
  ok "Kvantum: trasparenza 15% + blur Qt abilitato"
fi

say "8/8" "Wallpaper + GTK font + Reload"
WALL="$HOME/.local/share/wallpapers/catppuccin-mocha/catppuccin-mocha-sky.png"
if [ -f "$WALL" ]; then
  plasma-apply-wallpaperimage "$WALL" 2>/dev/null && ok "Wallpaper: catppuccin-mocha-sky.png"
else
  warn "Wallpaper non trovato — esegui: bash scripts/11-wallpaper-catppuccin.sh"
fi
sed -i 's/gtk-font-name=.*/gtk-font-name=Inter 11/' ~/.config/gtk-3.0/settings.ini 2>/dev/null || true
ok "GTK font: Inter 11"

# Reload KWin
qdbus6 org.kde.KWin /KWin reconfigure 2>/dev/null && ok "KWin reconfigurato"

echo ""
echo "╭──────────────────────────────────────────────────────╮"
echo "│  🎉 Rice Catppuccin Mocha riapplicato!               │"
echo "│                                                        │"
echo "│  Per la trasparenza sulle finestre Qt:                │"
echo "│  → Riavvia le app aperte (Dolphin, Kate, ecc.)       │"
echo "│                                                        │"
echo "│  Per verifica completa:                               │"
echo "│  bash scripts/verify-catppuccin.sh                   │"
echo "╰──────────────────────────────────────────────────────╯"
echo ""
