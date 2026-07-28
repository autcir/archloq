#!/bin/bash
# =============================================================================
# LOQ UTILITY FUNCTIONS
# =============================================================================
# Shared library for LOQ installation scripts
# =============================================================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

say() { printf '\n${BLUE}==>${NC} %s\n' "$*"; }
ok() { printf '  ${GREEN}✓${NC} %s\n' "$*"; }
warn() { printf '  ${YELLOW}!${NC} %s\n' "$*"; }
error() { printf '  ${RED}✗${NC} %s\n' "$*"; }

# Backup file
bak() { 
    [[ -f "$1" && ! -f "$1.loq-bak" ]] && cp -a "$1" "$1.loq-bak" || true; 
}

# Install package (handles AUR)
install_pkg() {
    local pkg="$1"
    local from_aur="${2:-0}"
    
    if [[ "$from_aur" == "1" ]]; then
        if command -v yay &> /dev/null; then
            yay -S --needed --noconfirm "$pkg"
        else
            warn "yay not available, skipping AUR package: $pkg"
        fi
    else
        pacman -S --needed --noconfirm "$pkg"
    fi
}

# Check if package is installed
pkg_installed() {
    pacman -Q "$1" &> /dev/null
}

# Get user home
get_user_home() {
    getent passwd "${SUDO_USER:-$USER}" | cut -d: -f6
}

# Check systemd service exists
service_exists() {
    systemctl list-unit-files "$1.service" &> /dev/null
}

# Safe reboot check
safe_reboot_check() {
    if [[ -f "$SCRIPT_DIR/optimize/verify-boot.sh" ]]; then
        bash "$SCRIPT_DIR/optimize/verify-boot.sh"
    else
        warn "verify-boot.sh not found, skipping safety check"
    fi
}