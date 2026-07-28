#!/usr/bin/env bash
# LOQ 17IRX10 — pre-reboot safety gate.
# Confirms the machine will boot cleanly. Run before EVERY reboot after changes.
#   bash verify-boot.sh
fail=0; warn=0
ok(){   printf '  \033[1;32m✓\033[0m %s\n' "$*"; }
bad(){  printf '  \033[1;31m✗ FAIL\033[0m %s\n' "$*"; fail=1; }
wn(){   printf '  \033[1;33m! warn\033[0m %s\n' "$*"; warn=1; }
hd(){   printf '\n\033[1;36m== %s ==\033[0m\n' "$*"; }

hd "Bootloader / UKI"
UKI=/boot/EFI/Linux/arch-linux-zen.efi
[[ -s $UKI ]] && ok "UKI present ($(du -h $UKI|cut -f1))" || bad "UKI missing: $UKI"
bootctl list 2>/dev/null | grep -q 'arch-linux-zen.efi' && ok "systemd-boot sees the entry" || bad "boot entry not discoverable"
sz=$(stat -c%s "$UKI" 2>/dev/null||echo 0); (( sz>40000000 )) && ok "UKI size sane" || bad "UKI suspiciously small ($sz bytes)"

hd "Kernel cmdline"
CL=/etc/kernel/cmdline
if grep -q 'root=' "$CL" 2>/dev/null; then ok "cmdline has root= ($(wc -c<$CL) bytes)"; else bad "cmdline missing root="; fi
grep -q 'nvidia_drm.modeset=1' "$CL" && ok "nvidia modeset in cmdline" || wn "nvidia_drm.modeset not set"
# embedded UKI cmdline must match /etc/kernel/cmdline
if diff -q <(bootctl list 2>/dev/null|grep -m1 'options:'|sed 's/.*options: //') <(cat "$CL") >/dev/null 2>&1; then
  ok "embedded UKI cmdline == /etc/kernel/cmdline"; else wn "UKI cmdline differs from /etc/kernel/cmdline (rebuild UKI if you changed it)"; fi

hd "Filesystems"
findmnt --verify --fstab >/dev/null 2>&1 && ok "fstab valid (findmnt --verify)" || bad "fstab INVALID — fix before reboot"
for m in / /home /boot; do findmnt -n "$m" >/dev/null 2>&1 && ok "$m mounted" || bad "$m not mounted"; done
df --output=pcent /boot 2>/dev/null|tail -1|tr -d ' %'|awk '{if($1>90)exit 1}' && ok "/boot has free space" || wn "/boot >90% full"

hd "Package DB integrity"
if pacman -Dk >/dev/null 2>&1; then ok "no broken package dependencies"; else bad "pacman -Dk reports broken deps:"; pacman -Dk 2>&1|sed 's/^/      /'; fi

hd "NVIDIA modules resolvable"
if modinfo -k "$(uname -r)" nvidia >/dev/null 2>&1; then ok "nvidia module found for $(uname -r)"; else wn "nvidia module not found for running kernel"; fi

hd "systemd unit health (boot-critical)"
for u in local-fs.target sysinit.target systemd-sysctl.service systemd-udevd.service; do
  st=$(systemctl is-active "$u" 2>/dev/null||true)
  [[ $st == active || $st == exited ]] && ok "$u: $st" || wn "$u: $st"
done
mapfile -t badf < <(systemctl --failed --plain --no-legend 2>/dev/null|awk '{print $1}')
if ((${#badf[@]})); then wn "failed system units (non-fatal, review): ${badf[*]}"; else ok "no failed system units"; fi

hd "sysctl values live (read-only)"
[[ $(sysctl -n vm.swappiness 2>/dev/null) == 100 ]] && ok "vm.swappiness=100" || wn "vm.swappiness not 100"
[[ $(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null) == bbr ]] && ok "tcp_congestion_control=bbr" || wn "bbr not active"
[[ $(cat /sys/block/nvme0n1/queue/scheduler 2>/dev/null) == *'[none]'* ]] && ok "nvme scheduler=none" || wn "nvme scheduler not none"

echo
if (( fail )); then printf '\033[1;31m✗ NOT SAFE TO REBOOT — fix FAILs above.\033[0m\n'; exit 1
elif (( warn )); then printf '\033[1;33m~ Safe to reboot (warnings above are non-fatal).\033[0m\n'
else printf '\033[1;32m✓ ALL CLEAR — safe to reboot.\033[0m\n'; fi
