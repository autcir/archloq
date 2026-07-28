#!/usr/bin/env bash
# LOQ 17IRX10 — performance & maintenance layer.
# Idempotent: safe to re-run. Reproduces the whole tune-up on a fresh Arch install.
#
#   sudo bash install.sh          # apply everything (safe, no boot-mechanism changes)
#   sudo bash install.sh --clean  # also remove orphaned *-debug packages
#
# Does NOT touch: UKI / mkinitcpio / kernel cmdline / bootloader.
# Optional boot tweaks are documented (NOT auto-applied) in docs/manual-tweaks.md.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ $EUID -eq 0 ]] || { echo "run with sudo"; exit 1; }

say(){ printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
bak(){ [[ -f "$1" && ! -f "$1.loq-bak" ]] && cp -a "$1" "$1.loq-bak" || true; }

# ---------------------------------------------------------------- 1. drop-in configs
say "Installing drop-in config files under /etc"
cp -av "$HERE/files/etc/." /etc/

# ---------------------------------------------------------------- 2. makepkg.conf
say "Tuning /etc/makepkg.conf (native march, all cores, ccache, rust native)"
MK=/etc/makepkg.conf; bak "$MK"
sed -i 's|-march=x86-64 -mtune=generic|-march=native|' "$MK"
grep -qE '^MAKEFLAGS=' "$MK" || sed -i 's|^#MAKEFLAGS=.*|MAKEFLAGS="-j$(nproc)"|' "$MK"
grep -qE '^RUSTFLAGS=' "$MK" || sed -i '/^LTOFLAGS=/a RUSTFLAGS="-C opt-level=3 -C target-cpu=native"' "$MK"
sed -i '/^BUILDENV=/ s|!ccache|ccache|' "$MK"

# ---------------------------------------------------------------- 3. pacman.conf
say "pacman: ParallelDownloads=10"
bak /etc/pacman.conf
sed -i 's|^ParallelDownloads = 5|ParallelDownloads = 10|' /etc/pacman.conf

# ---------------------------------------------------------------- 4. fstab noatime (validated)
say "fstab: relatime -> noatime on ext4 (validated before commit)"
bak /etc/fstab
tmp=$(mktemp)
sed '/[[:space:]]ext4[[:space:]]/ s|rw,relatime|rw,noatime|' /etc/fstab > "$tmp"
if findmnt --verify --fstab --tab-file "$tmp" >/dev/null 2>&1; then
  cp "$tmp" /etc/fstab; echo "  fstab validated OK"
else
  echo "  !! fstab verify FAILED — kept original"; findmnt --verify --fstab --tab-file "$tmp" || true
fi
rm -f "$tmp"

# ---------------------------------------------------------------- 5. packages
say "Installing irqbalance + ccache"
pacman -S --needed --noconfirm irqbalance ccache

# ---------------------------------------------------------------- 6. services / timers
say "Enabling maintenance timers + perf daemons"
systemctl enable --now fstrim.timer paccache.timer irqbalance.service systemd-oomd.service
systemctl enable --now reflector.timer
systemctl enable nvidia-suspend.service nvidia-resume.service nvidia-hibernate.service
say "Disabling NetworkManager-wait-online (6.7s boot block)"
systemctl disable NetworkManager-wait-online.service || true

# ---------------------------------------------------------------- 7. live-apply
say "Applying sysctl + udev + journal cap now"
sysctl --system >/dev/null
udevadm control --reload && udevadm trigger --subsystem-match=block --action=change
systemctl restart systemd-journald
journalctl --vacuum-size=500M >/dev/null 2>&1 || true

# ---------------------------------------------------------------- 8. cache cleanup
say "Trimming package cache (keep last 2)"
paccache -rk2 || true
command -v yay >/dev/null && sudo -u "${SUDO_USER:-$USER}" yay -Sc --noconfirm >/dev/null 2>&1 || true

# ---------------------------------------------------------------- 9. optional orphan cleanup
if [[ "${1:-}" == "--clean" ]]; then
  say "Removing orphaned *-debug packages only (real orphans left for manual review)"
  mapfile -t deb < <(pacman -Qtdq 2>/dev/null | grep -- '-debug$' || true)
  ((${#deb[@]})) && pacman -Rns --noconfirm "${deb[@]}" || echo "  none"
  echo "  Non-debug orphans (review manually): $(pacman -Qtdq 2>/dev/null | grep -v -- '-debug$' | tr '\n' ' ')"
fi

say "DONE. Run ./verify-boot.sh before rebooting."
