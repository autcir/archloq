#!/bin/bash
# =============================================================================
# 07 - Install Scripts and Configurations
# =============================================================================

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/utils.sh"

say "Installing LOQ scripts and applying configurations..."

# Install main scripts
bak /usr/local/bin/loq-mode
bak /usr/local/bin/loq-power-apply
bak /usr/local/bin/loq-power-diag
bak /usr/local/bin/loq-battery-clean

cp "$SCRIPT_DIR/../../scripts/loq-mode" /usr/local/bin/loq-mode
cp "$SCRIPT_DIR/../../scripts/loq-power-apply" /usr/local/bin/loq-power-apply
cp "$SCRIPT_DIR/../../scripts/loq-power-diag" /usr/local/bin/loq-power-diag
cp "$SCRIPT_DIR/../../scripts/loq-battery-clean.sh" /usr/local/bin/loq-battery-clean

chmod +x /usr/local/bin/loq-mode
chmod +x /usr/local/bin/loq-power-apply
chmod +x /usr/local/bin/loq-power-diag
chmod +x /usr/local/bin/loq-battery-clean

# Create udev rule for power events
cat > /etc/udev/rules.d/90-loq-power.rules << 'EOF'
SUBSYSTEM=="power_supply", ENV{POWER_SUPPLY_ONLINE}=="0", RUN+="/usr/bin/systemctl start loq-power-apply.service"
SUBSYSTEM=="power_supply", ENV{POWER_SUPPLY_ONLINE}=="1", RUN+="/usr/bin/systemctl start loq-power-apply.service"
EOF

# Install systemd service for power apply
cat > /etc/systemd/system/loq-power-apply.service << 'EOF'
[Unit]
Description=Apply Lenovo LOQ AC/battery power policy
After=multi-user.target tlp.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/loq-power-apply

[Install]
WantedBy=multi-user.target
EOF

# Enable services
systemctl daemon-reload
systemctl enable loq-power-apply.service

ok "Scripts installed"

# Apply configurations
bash "$SCRIPT_DIR/../../loq-definitive-power.sh" 2>/dev/null || warn "Power config script had issues"

# Verify
loq-power-diag || warn "Power diagnostics show issues"