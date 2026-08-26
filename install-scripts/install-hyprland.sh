#!/usr/bin/env bash
# install-hyprland.sh — Fase Hyprland per ArchLOQ
# Installa e configura Hyprland con Catppuccin Mocha
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES="$HERE/dotfiles"

say()  { printf '\n\033[1;36m[INFO]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[OK]\033[0m  %s\n' "$*"; }
warn() { printf '\033[1;33m[WARN]\033[0m %s\n' "$*"; }
err()  { printf '\033[1;31m[ERR]\033[0m  %s\n' "$*"; exit 1; }

# ============================================================
# FASE H1: Pacchetti Hyprland
# ============================================================
say "FASE H1: Installazione pacchetti Hyprland"

PACCHETTI=(
    hyprland
    hyprpaper
    hyprlock
    hypridle
    waybar
    rofi-wayland
    mako
    wl-clipboard
    cliphist
    grim
    slurp
    brightnessctl
    playerctl
    pavucontrol
    nm-connection-editor
    dolphin
    wlogout
    polkit-kde-authentication-agent
    xdg-desktop-portal-hyprland
    xdg-desktop-portal-gtk
    qt6-wayland
    gtk3
    papirus-icon-theme
    ttf-hack-nerd
)

echo "Pacchetti da installare:"
printf '  %s\n' "${PACCHETTI[@]}"
echo ""
read -p "Installare? [y/N] " yn
if [[ "$yn" == [yY] ]]; then
    yay -S --needed --noconfirm "${PACCHETTI[@]}"
    ok "Pacchetti installati"
else
    warn "Saltato installazione pacchetti"
fi

# ============================================================
# FASE H2: Backup config esistenti
# ============================================================
say "FASE H2: Backup configurazioni esistenti"

BACKUP_DIR="$HOME/.config/hypr-backup-$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

for dir in hypr waybar rofi mako; do
    if [ -d "$HOME/.config/$dir" ]; then
        cp -r "$HOME/.config/$dir" "$BACKUP_DIR/"
        ok "Backup $dir completato"
    fi
done

# ============================================================
# FASE H3: Deploy configurazioni
# ============================================================
say "FASE H3: Deploy configurazioni Hyprland"

# Hyprland
mkdir -p "$HOME/.config/hypr"
cp "$DOTFILES/config/hypr/hyprland.conf" "$HOME/.config/hypr/"
cp "$DOTFILES/config/hypr/hyprpaper.conf" "$HOME/.config/hypr/"
cp "$DOTFILES/config/hypr/hyprlock.conf" "$HOME/.config/hypr/"
ok "Hyprland config deployata"

# Waybar
mkdir -p "$HOME/.config/waybar"
cp "$DOTFILES/config/waybar/config" "$HOME/.config/waybar/"
cp "$DOTFILES/config/waybar/style.css" "$HOME/.config/waybar/"
ok "Waybar config deployata"

# Rofi
mkdir -p "$HOME/.config/rofi"
cp "$DOTFILES/config/rofi/config.rasi" "$HOME/.config/rofi/"
ok "Rofi config deployata"

# Mako
mkdir -p "$HOME/.config/mako"
cp "$DOTFILES/config/mako/config" "$HOME/.config/mako/"
ok "Mako config deployata"

# ============================================================
# FASE H4: Wallpaper
# ============================================================
say "FASE H4: Wallpaper Catppuccin Mocha"

WALLPAPER_DIR="$HOME/.local/share/wallpapers/catppuccin-mocha"
mkdir -p "$WALLPAPER_DIR"

if [ ! -f "$WALLPAPER_DIR/catppuccin-mocha-sky.png" ]; then
    echo "Scarico wallpaper Catppuccin Mocha..."
    curl -sL "https://raw.githubusercontent.com/catppuccin/catppuccin/main/assets/redirects/links/catppuccin-wallpaper.png" \
        -o "$WALLPAPER_DIR/catppuccin-mocha-sky.png" 2>/dev/null || true
    ok "Wallpaper scaricato"
else
    ok "Wallpaper già presente"
fi

# ============================================================
# FASE H5: Autostart session
# ============================================================
say "FASE H5: Configurazione autostart"

# Crea desktop entry per Hyprland
mkdir -p "$HOME/.local/share/wayland-sessions"
cat > "$HOME/.local/share/wayland-sessions/hyprland.desktop" << 'EOF'
[Desktop Entry]
Name=Hyprland
Comment=ArchLOQ Hyprland Session
Exec=Hyprland
Type=Application
DesktopNames=Hyprland
EOF
ok "Desktop entry creata"

# ============================================================
# Fine
# ============================================================
echo ""
ok "============================================"
ok "  Hyprland installato e configurato!"
ok "============================================"
echo ""
echo "  Per avviare:"
echo "    1. Logout da KDE"
echo "    2. Seleziona Hyprland dal display manager"
echo "    3. Oppure: Hyprland da terminale"
echo ""
echo "  Hotkeys principali:"
echo "    SUPER + Return    → Ghostty (terminale)"
echo "    SUPER + D         → Rofi (menu app)"
echo "    SUPER + Q         → Chiudi finestra"
echo "    SUPER + F         → Fullscreen"
echo "    SUPER + L         → Lock schermo"
echo "    SUPER + 1-5       → Workspace"
echo "    SUPER + SHIFT + Q → Esci"
echo ""
echo "  Backup salvato in: $BACKUP_DIR"
echo ""
warn "  NOTA: per tornare a KDE, seleziona Plasma dal display manager"
