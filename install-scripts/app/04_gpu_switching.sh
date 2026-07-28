#!/bin/bash
# =============================================================================
# 04 - GPU Switching Installation
# =============================================================================

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/utils.sh"

say "Installing GPU switching options..."

# Install envycontrol (AUR)
install_pkg "envycontrol" 1

# Copy loq-control desktop file if available
if [[ -f "$SCRIPT_DIR/../../runtime/loq-control" ]]; then
    warn "loq-control GUI available in runtime/ - see runtime/README.md"
fi

# GPU mode switching commands
cat > /usr/local/bin/gpu-switch << 'EOF'
#!/bin/bash
# GPU switching wrapper
MODE="${1:-hybrid}"
case "$MODE" in
    hybrid) envycontrol gpu-switch hybrid ;;
    intel) envycontrol gpu-switch integrated ;;
    nvidia) envycontrol gpu-switch discrete ;;
    *) echo "Usage: gpu-switch {hybrid|intel|nvidia}" ;;
esac
EOF
chmod +x /usr/local/bin/gpu-switch

ok "GPU switching installed"
ok "Usage: gpu-switch hybrid|intel|nvidia"