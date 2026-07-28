#!/bin/bash
# =============================================================================
# 99 - Safe Reboot Check
# =============================================================================

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/utils.sh"

say "Running pre-reboot safety checks..."

# Check UKI
UKI=/boot/EFI/Linux/arch-linux-zen.efi
if [[ -s $UKI ]]; then
    ok "UKI present ($(du -h $UKI|cut -f1))"
else
    error "UKI missing: $UKI"
    exit 1
fi

# Check kernel cmdline
CL=/etc/kernel/cmdline
if grep -q 'root=' "$CL" 2>/dev/null; then
    ok "cmdline has root= ($(wc -c<$CL) bytes)"
else
    error "cmdline missing root="
fi

if grep -q 'nvidia_drm.modeset=1' "$CL" 2>/dev/null; then
    ok "nvidia modeset in cmdline"
else
    warn "nvidia_drm.modeset not set"
fi

# Check fstab
if findmnt --verify --fstab >/dev/null 2>&1; then
    ok "fstab valid"
else
    error "fstab INVALID — fix before reboot"
fi

# Check package DB
if pacman -Dk >/dev/null 2>&1; then
    ok "no broken package dependencies"
else
    error "pacman -Dk reports broken deps"
fi

# Check NVIDIA modules
if modinfo -k "$(uname -r)" nvidia >/dev/null 2>&1; then
    ok "nvidia module found for $(uname -r)"
else
    warn "nvidia module not found for running kernel"
fi

# Check sysctl values
if [[ "$(sysctl -n vm.swappiness 2>/dev/null)" == 100 ]]; then
    ok "vm.swappiness=100"
else
    warn "vm.swappiness not 100"
fi

echo
if (( $? )); then
    printf '\033[1;31m✗ NOT SAFE TO REBOOT — fix issues above.\033[0m\n'
    exit 1
else
    printf '\033[1;32m✓ ALL CLEAR — safe to reboot.\033[0m\n'
fi