#!/usr/bin/env bash
# =============================================================================
# 06 — hardening
# =============================================================================
# Practical rather than maximal: a packet filter that only opens SSH, fail2ban
# against password brute force, no passwordless sudo, and a sysctl set that
# covers the mistakes that actually happen (ptrace, kptr leaks, rp_filter).
#
# Deliberately absent: firewalld, AppArmor, auditd. See docs/SECRETS.md.
# =============================================================================

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/utils.sh
source "$SCRIPT_DIR/../lib/utils.sh"

require_root
require_config
init_dirs

say "== 06 hardening =="

# -----------------------------------------------------------------------------
# sudo
#
# No NOPASSWD. It is convenient right up to the moment you need to know that a
# command ran as root.
# -----------------------------------------------------------------------------
if [[ -f /etc/sudoers.d/wheel ]] || grep -qE '^%wheel\s+ALL=' /etc/sudoers; then
  ok "wheel already has password sudo"
else
  printf '%%wheel ALL=(ALL:ALL) ALL\n' | write_file /etc/sudoers.d/wheel 0440
  ok "wheel has password sudo"
fi

# Opening visudo to a full editor on a laptop with no $DISPLAY is unhelpful;
# tell visudo to use a simple editor instead.
if ! grep -q 'editor' /etc/sudoers; then
  printf '\nDefaults editor=/usr/bin/editor\nDefaults !requiretty\n' \
    | write_file /etc/sudoers.d/archloq-visudo 0440
  ok "visudo will use /usr/bin/editor"
fi

if enabled "${LOQ_SUDO_NOPASSWD:-0}"; then
  warn "LOQ_SUDO_NOPASSWD=1: this removes the password prompt for every sudo call."
fi

# -----------------------------------------------------------------------------
# Firewall
# -----------------------------------------------------------------------------
if enabled "${LOQ_ENABLE_FIREWALL:-0}"; then
  pkg_install nftables

  # IPv6 is not optional: dropping ICMPv6 breaks neighbour discovery and every
  # address family silently stops working while IPv4 looks fine.
  # An empty LOQ_SSH_ALLOWED_CIDRS means "anywhere"; the default-drop policy is
  # still doing the work, fail2ban handles the brute force.
  ssh_v4_cidrs="${LOQ_SSH_ALLOWED_CIDRS:-0.0.0.0/0}"

  {
    printf '#!/usr/bin/nft -f\n\n'
    printf 'flush ruleset\n\n'
    printf 'table inet loq_filter {\n'
    printf '  set blocked {\n'
    printf '    type ipv4_addr\n'
    printf '    flags interval\n'
    printf '    elements = { 0.0.0.0/8, 10.0.0.0/8, 127.0.0.0/8, 169.254.0.0/16, 172.16.0.0/12, 192.168.0.0/16, 224.0.0.0/4, 240.0.0.0/4 }\n'
    printf '  }\n\n'
    printf '  chain input {\n'
    printf '    type filter hook input priority filter; policy drop;\n\n'
    printf '    iif lo accept comment "loopback"\n'
    printf '    ct state established,related accept\n'
    printf '    ct state invalid drop\n\n'
    printf '    # ICMP is required for path MTU discovery; rate-limited, not blanket-allowed.\n'
    printf '    ip protocol icmp icmp type { echo-request, destination-unreachable, time-exceeded, parameter-problem } limit rate 10/second accept\n'
    printf '    ip6 nexthdr ipv6-icmp icmpv6 type { echo-request, destination-unreachable, packet-too-big, time-exceeded, parameter-problem, nd-neighbor-solicit, nd-neighbor-advert, nd-router-advert } accept\n\n'
    printf '    # RFC1918 spoofing from outside is never legitimate.\n'
    printf '    ip saddr @blocked drop\n\n'
    printf '    # SSH\n'
    printf '    ip saddr { %s } tcp dport %s ct state new accept\n' "$ssh_v4_cidrs" "$LOQ_SSH_PORT"
    printf '    ip6 saddr { ::/0 } tcp dport %s ct state new accept\n' "$LOQ_SSH_PORT"
    printf '\n    limit rate 5/minute burst 5 packets log prefix "nft-loq-drop " level info\n'
    printf '  }\n\n'
    printf '  chain forward {\n'
    if enabled "${LOQ_ENABLE_DOCKER:-0}"; then
      printf '    # Docker publishes ports through its own rules; allow bridge\n'
      printf '    # forwarding or containers lose networking under policy drop.\n'
      printf '    type filter hook forward priority filter; policy drop;\n'
      printf '    ct state established,related accept\n'
      printf '    iif lo accept\n'
      printf '    iifname "docker*" accept\n'
      printf '    oifname "docker*" accept\n'
      printf '  }\n\n'
    else
      printf '    type filter hook forward priority filter; policy drop;\n'
      printf '  }\n\n'
    fi
    printf '  chain output {\n'
    printf '    type filter hook output priority filter; policy accept;\n'
    printf '  }\n'
    printf '}\n'
  } | write_file /etc/nftables.conf 0644

  # Validate before enabling. An invalid ruleset that is loaded at boot bricks
  # network access, so refuse to proceed if nft cannot parse it.
  if nft -c -f /etc/nftables.conf; then
    ok "nftables ruleset is syntactically valid"
    svc_enable nftables
  else
    warn "nftables ruleset is INVALID; not enabling the service"
    warn "Fix /etc/nftables.conf, verify with 'sudo nft -c -f /etc/nftables.conf', then enable."
  fi
else
  skip "firewall disabled by config"
fi

# -----------------------------------------------------------------------------
# SSH
# -----------------------------------------------------------------------------
if systemctl is-enabled sshd.service >/dev/null 2>&1 || pacman -Qq openssh >/dev/null 2>&1; then
  if enabled "${LOQ_ENABLE_FIREWALL:-0}" && ! grep -qE "^Port[[:space:]]+$LOQ_SSH_PORT" /etc/ssh/sshd_config 2>/dev/null; then
    printf 'Port %s\n' "$LOQ_SSH_PORT" | write_file /etc/ssh/sshd_config.d/10-archloq-port.conf 0644
  fi

  # Password auth stays enabled because this is a laptop, not a bastion. What we
  # can do is refuse the slow-brute-force pattern outright and let fail2ban take
  # the rest.
  {
    printf '# archloq: do not let a client spend 60s on a single connection.\n'
    printf 'LoginGraceTime 30\n'
    printf 'MaxAuthTries 3\n'
    printf 'MaxStartups 10:30:60\n'
  } | write_file /etc/ssh/sshd_config.d/20-archloq-hardening.conf 0644
  ok "sshd hardening drop-in written"
  if systemctl is-active --quiet sshd; then
    if sshd -t; then
      svc_enable sshd
    else
      warn "sshd config test failed; not reloading"
    fi
  fi
fi

# -----------------------------------------------------------------------------
# fail2ban
# -----------------------------------------------------------------------------
if enabled "${LOQ_ENABLE_FAIL2BAN:-0}"; then
  pkg_install fail2ban
  {
    printf '[DEFAULT]\n'
    printf 'bantime  = %s\n' "$LOQ_FAIL2BAN_BANTIME"
    printf 'findtime = %s\n' "$LOQ_FAIL2BAN_FINDTIME"
    printf 'maxretry = %s\n' "$LOQ_FAIL2BAN_MAXRETRY"
    printf 'ignoreip = 127.0.0.1/8 ::1 %s\n' "${LOQ_SSH_ALLOWED_CIDRS:-}"
    printf 'backend  = systemd\n'
    printf 'usedns   = no\n\n'
    printf '[sshd]\n'
    printf 'enabled = true\n'
    printf 'port    = %s\n' "$LOQ_SSH_PORT"
  } | write_file /etc/fail2ban/jail.d/archloq.local 0644
  svc_enable fail2ban
else
  skip "fail2ban disabled by config"
fi

# -----------------------------------------------------------------------------
# sysctl
# -----------------------------------------------------------------------------
{
  printf '# archloq — kernel hardening.\n'
  printf '# vm.swappiness is intentionally NOT set: zram-generator owns swap policy\n'
  printf '# and forcing it to 0 makes zram pointless.\n\n'
  printf 'kernel.kptr_restrict = 2\n'
  printf 'kernel.dmesg_restrict = 1\n'
  printf 'kernel.unprivileged_bpf_disabled = 1\n'
  printf '# unprivileged userns must stay enabled (1) on a laptop: 0 breaks\n'
  printf '# Chrome sandbox, flatpak and rootless containers on recent kernels.\n'
  printf 'kernel.unprivileged_userns_clone = 1\n'
  printf 'fs.suid_dumpable = 0\n'
  printf 'fs.protected_hardlinks = 1\n'
  printf 'fs.protected_symlinks = 1\n\n'
  printf 'net.ipv4.conf.all.rp_filter = 1\n'
  printf 'net.ipv4.conf.default.rp_filter = 1\n'
  printf 'net.ipv4.tcp_syncookies = 1\n'
  printf 'net.ipv4.icmp_echo_ignore_broadcasts = 1\n'
  printf '# accept_ra must stay 1 for SLAAC WiFi; 0 breaks IPv6 on laptops.\n'
  printf 'net.ipv6.conf.all.accept_ra = 1\n'
  if ! enabled "${LOQ_ENABLE_DOCKER:-0}"; then
    printf 'net.ipv4.ip_forward = 0\n'
    printf 'net.ipv6.conf.all.forwarding = 0\n'
  fi
  printf '\n# Do not report deliberately unreachable hosts as hard errors.\n'
  printf 'net.ipv4.tcp_slow_start_after_idle = 0\n'
} | write_file /etc/sysctl.d/90-archloq.conf 0644

run sysctl --system >/dev/null 2>&1 || warn "sysctl --system reported errors; check with 'sysctl -a'"

summary_line "06: nftables, fail2ban, sudo policy, sysctl hardening"
marker_set 06_hardening
ok "06 hardening complete"