#!/bin/bash
# =============================================================================
# 06 - System Performance Tuning
# =============================================================================

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/utils.sh"

say "Applying system performance tuning..."

# Makepkg config
bak /etc/makepkg.conf
sed -i 's|-march=x86-64 -mtune=generic|-march=native|' /etc/makepkg.conf
grep -qE '^MAKEFLAGS=' /etc/makepkg.conf || sed -i 's|^#MAKEFLAGS=.*|MAKEFLAGS="-j$(nproc)"|' /etc/makepkg.conf
grep -qE '^RUSTFLAGS=' /etc/makepkg.conf || sed -i '/^LTOFLAGS=/a RUSTFLAGS="-C opt-level=3 -C target-cpu=native"' /etc/makepkg.conf
sed -i '/^BUILDENV=/ s|!ccache|ccache|' /etc/makepkg.conf

# Pacman parallel downloads
bak /etc/pacman.conf
sed -i 's|^ParallelDownloads = 5|ParallelDownloads = 10|' /etc/pacman.conf

# Sysctl tuning
mkdir -p /etc/sysctl.d
bak /etc/sysctl.d/99-loq-perf.conf
cat > /etc/sysctl.d/99-loq-perf.conf << 'EOF'
vm.swappiness=100
vm.vfs_cache_pressure=50
vm.dirty_bytes=256M
vm.dirty_background_bytes=64M
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
kernel.nmi_watchdog=0
EOF

# I/O scheduler
mkdir -p /etc/udev/rules.d
bak /etc/udev/rules.d/60-ioschedulers.rules
cat > /etc/udev/rules.d/60-ioschedulers.rules << 'EOF'
# NVMe
ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="none"
# SSD
ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="mq-deadline"
# HDD
ATTR{queue/rotational}=="1", ATTR{queue/scheduler}="bfq"
EOF

# Systemd services
systemctl enable irqbalance systemd-oomd fstrim.timer paccache.timer

ok "System performance tuned"