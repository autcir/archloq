#!/bin/bash
# =============================================================================
# 02 - Power Management Installation
# =============================================================================

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/utils.sh"

say "Installing power management..."

# Install TLP and thermald
install_pkg "tlp"
install_pkg "thermald"
install_pkg "acpid"

# Install legiond (AUR)
install_pkg "legiond" 1

# Install lenovo-legionlinux (AUR)
install_pkg "lenovolegionlinux-git" 1

# Copy TLP config
bak /etc/tlp.d/lenovo-loq.conf
cp "$SCRIPT_DIR/../../config/tlp.d/lenovo-loq.conf" /etc/tlp.d/lenovo-loq.conf

# Copy modprobe config
bak /etc/modprobe.d/lenovo-loq.conf
cp "$SCRIPT_DIR/../../config/modprobe.d/lenovo-loq.conf" /etc/modprobe.d/lenovo-loq.conf

# Copy legiond config
bak /etc/legion_linux/legiond.ini
cp "$SCRIPT_DIR/../../config/legion_linux/legiond.ini" /etc/legion_linux/legiond.ini

# Enable services
systemctl enable tlp.service thermald.service acpid.service

# Enable legiond if available
if service_exists legiond; then
    systemctl enable legiond.service
fi

# Mask conflicting services
systemctl mask power-profiles-daemon.service systemd-rfkill.service 2>/dev/null || true

ok "Power management installed"

# Apply TLP
tlp start || warn "TLP start failed"
thermald start || warn "thermald start failed"