#!/bin/bash
# =============================================================================
# 01 - Kernel and NVIDIA Driver Installation
# =============================================================================

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/utils.sh"

say "Installing kernel and NVIDIA drivers..."

# Install kernel
install_pkg "linux-zen"
install_pkg "linux-zen-headers"
install_pkg "linux-firmware"

# Install NVIDIA drivers (AUR)
install_pkg "nvidia-dkms" 1
install_pkg "nvidia-utils-dkms" 1
install_pkg "cuda-dkms" 1

# Configure NVIDIA DRM
cat > /etc/modprobe.d/nvidia-dkms.conf << 'EOF'
options nvidia_drm modeset=1 fbdev=1
options nvidia NVreg_DynamicPowerManagement=0x02 NVreg_PreserveVideoMemoryAllocations=1
EOF

ok "NVIDIA drivers installed and configured"

# Verify
if modinfo -k "$(uname -r)" nvidia &> /dev/null; then
    ok "NVIDIA module found for $(uname -r)"
else
    warn "NVIDIA module not found for running kernel"
fi