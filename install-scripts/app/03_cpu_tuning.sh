#!/bin/bash
# =============================================================================
# 03 - CPU Tuning (Undervolt and P-State)
# =============================================================================

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/utils.sh"

say "Installing CPU tuning..."

# Install intel-undervolt (AUR)
install_pkg "intel-undervolt" 1

# Configure undervolt
cat > /etc/intel-undervolt.conf << 'EOF'
# Undervolt config per i7-13700HX
undervolt 0 "Core" -100
undervolt 1 "Uncore" -80
undervolt 2 "Cache" -80
undervolt 3 "System Agent" -50
undervolt 4 "Analog I/O" -50

# Power limits (mW)
power package 15000 25000
power core 15000 25000

# Temp limit (°C below Tjmax)
tjoffset -10

# HWP hints
hwp 0 1
hwp 1 1
EOF

# Enable and start intel-undervolt
systemctl enable intel-undervolt.service
systemctl start intel-undervolt.service

ok "CPU tuning installed"

# Status check
intel-undervolt status || warn "intel-undervolt status check failed"