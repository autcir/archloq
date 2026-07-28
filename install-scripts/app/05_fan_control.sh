#!/bin/bash
# =============================================================================
# 05 - Fan Control Installation
# =============================================================================

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/utils.sh"

say "Installing fan control..."

# Check if legion_laptop module is loaded
if lsmod | grep -q legion_laptop; then
    ok "legion_laptop module loaded"
else
    warn "legion_laptop module not loaded - check BIOS settings"
fi

# Copy legiond config if available
if [[ -f "$SCRIPT_DIR/../../config/legion_linux/legiond.ini" ]]; then
    bak /etc/legion_linux/legiond.ini
    cp "$SCRIPT_DIR/../../config/legion_linux/legiond.ini" /etc/legion_linux/legiond.ini
fi

# Start legiond if available
if service_exists legiond; then
    systemctl enable legiond.service
    systemctl start legiond.service
    ok "legiond daemon started"
else
    warn "legiond not installed - install with: yay -S legiond"
fi

# Fan curve configuration
cat > /usr/local/bin/loq-fan-curve << 'EOF'
#!/bin/bash
# Manual fan curve override (requires legion_laptop)
# Point format: TEMP:PWM
POINTS=("40:0" "55:30" "65:60" "75:90" "85:100")

echo "Fan curve: ${POINTS[@]}"
EOF
chmod +x /usr/local/bin/loq-fan-curve

ok "Fan control installed"