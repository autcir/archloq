#!/usr/bin/env bash
# =============================================================================
# 04 — CPU undervolt
# =============================================================================
# Raptor Lake (i7-13700HX). The values that shipped in the old loq.conf
# (-100/-80/-80/-50/-50 mV) are past what is reliably stable on 13th gen and can
# corrupt work silently, long after the fact.
#
# Everything applied here is verifiable: manage/loq-uv-diagnose.sh stresses the
# CPU, watches for WHEA/MCE hardware errors, and tells you which offset to
# back off. Nothing here changes the undervolt behind your back afterwards.
# =============================================================================

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/utils.sh
source "$SCRIPT_DIR/../lib/utils.sh"

require_root
require_config
init_dirs

say "== 04 CPU undervolt =="

if ! enabled "${LOQ_ENABLE_UNDERVOLT:-0}"; then
  skip "undervolt disabled by config; stock CPU behaviour"
  marker_set 04_cpu_undervolt
  marker_set 04_cpu_undervolt_disabled
  exit 0
fi

# -----------------------------------------------------------------------------
# intel-undervolt
# -----------------------------------------------------------------------------
pkg_install intel-undervolt
# cpuid lives in AUR (aur/cpuid); kcpuid/libcpuid in extra have different CLIs.
if ! have cpuid; then
  pkg_install_aur cpuid || warn "cpuid unavailable; signature check will warn-only"
fi

# -----------------------------------------------------------------------------
# Verify the CPU signature actually matches before writing any offsets.
# Writing a config for the wrong part is how you get an unstable machine with
# no obvious cause.
# -----------------------------------------------------------------------------
cpu_id="$(cat /proc/cpuinfo | awk -F': *' '/model name/ {print $2; exit}')"
say "CPU: $cpu_id"

detect_signature() {
  local name="$1" wanted="$2" found
  for path in /sys/devices/virtual/thermal/thermal_zone*/; do
    [[ -r "${path}type" ]] || continue
    found="$(cat "${path}type" 2>/dev/null || true)"
    [[ "$found" == "$wanted" ]] || continue
    printf '%s\n' "$path"
    return 0
  done
  return 1
}

core_path="$(detect_signature "$cpu_id" "x86_pkg_temp" || true)"
if [[ -z "$core_path" ]]; then
  warn "no x86_pkg_temp thermal zone found; cannot confirm the package is unlocked"
else
  pkg_id="$(cat "${core_path}id" 2>/dev/null || true)"
  say "thermal zone package id: ${pkg_id:-unknown}"
fi

# Verify the CPU is the one this config was written for. LOQ_UNDERVOLT_SIGNATURE
# is the Intel CPUID family/model signature (0x106B0 = Raptor Lake, RPL-P/RPL-R).
# cpuid(1) gives it; the thermal-zone id read above does not, and neither does
# `intel-undervolt -q`, which is quiet-apply and prints nothing.
cpu_signature="$(cpuid -1 -s 0x1 2>/dev/null | awk '/^Version/ {print $4}' || true)"
cpu_model_hex="$(cpuid -1 2>/dev/null | awk '/Model name/ {print $NF}' | sed 's/0x//' || true)"
say "cpu signature: ${cpu_signature:-unknown} (model field 0x${cpu_model_hex:-?})"
if [[ -n "${cpu_signature:-}" ]]; then
  if [[ "$cpu_signature" == "$LOQ_UNDERVOLT_SIGNATURE" ]]; then
    ok "running CPU signature matches LOQ_UNDERVOLT_SIGNATURE"
  else
    warn "running CPU signature $cpu_signature does not match LOQ_UNDERVOLT_SIGNATURE=$LOQ_UNDERVOLT_SIGNATURE"
    warn "this undervolt was tuned for a different part; see docs/CPU_TUNING.md"
  fi
else
  warn "could not read the CPU signature (is the 'cpuid' package installed?);"
  warn "proceeding, but the offsets may not be appropriate for this CPU"
fi

# -----------------------------------------------------------------------------
# intel-undervolt v1.7 config is shell (sourced), not INI:
#   undervolt <index> '<label>' <offset_mV>
# Indices: 0 CPU/core, 1 GPU/uncore, 2 CPU cache, 3 System Agent, 4 Analog I/O.
# -----------------------------------------------------------------------------
say "writing /etc/intel-undervolt.conf"
{
  printf '# archloq — Raptor Lake i7-13700HX, conservative values.\n'
  printf '# Verify before trusting: sudo manage/loq-uv-diagnose.sh\n'
  printf '# See docs/CPU_TUNING.md for how each domain maps to a real voltage rail.\n\n'
  printf "undervolt 0 'CPU' %s\n" "$LOQ_UNDERVOLT_CORE"
  printf "undervolt 1 'GPU' %s\n" "$LOQ_UNDERVOLT_UNCORE"
  printf "undervolt 2 'CPU Cache' %s\n" "$LOQ_UNDERVOLT_CACHE"
  printf "undervolt 3 'System Agent' %s\n" "$LOQ_UNDERVOLT_SA"
  printf "undervolt 4 'Analog I/O' %s\n" "$LOQ_UNDERVOLT_IO"
} | write_file /etc/intel-undervolt.conf 0644

# The i5/i7 domains must be unlocked first or intel-undervolt exits without
# touching anything. Raptor Lake needs the microcode from linux-firmware.
if [[ ! -e /dev/cpu/0/msr ]]; then
  if ! modprobe msr 2>/dev/null; then
    warn "cannot load the msr module; undervolt will not apply."
    warn "Run 'sudo modprobe msr' and check /etc/modprobe.d/ for a persistent entry."
  else
    ok "msr module loaded"
  fi
fi

# -----------------------------------------------------------------------------
# Apply once so the values are live for this boot. thermald owns them from here.
# v1.7 CLI: apply/read (old -q/-s no longer exist). Locked CPUs refuse;
# that is warn-only, not fatal for the install.
# -----------------------------------------------------------------------------
if have intel-undervolt; then
  if intel-undervolt apply 2>&1; then
    ok "undervolt applied"
    intel-undervolt read 2>/dev/null || true
  else
    warn "intel-undervolt refused the configuration (CPU likely locked); stock behaviour kept"
    warn "  verify with: intel-undervolt read"
  fi
else
  warn "intel-undervolt not found in PATH; configuration written but not applied"
fi

# -----------------------------------------------------------------------------
# Make it survive reboot without racing thermald.
# -----------------------------------------------------------------------------
write_file /etc/systemd/system/loq-undervolt.service 0644 <<'EOF'
[Unit]
Description=archloq: apply the CPU undervolt once at boot
Documentation=file:///usr/share/doc/archloq/docs/CPU_TUNING.md
After=multi-user.target
# thermald owns these offsets at runtime; run after it so it is the only writer
# that can re-assert them afterwards.
After=thermald.service

[Service]
Type=oneshot
RemainAfterExit=no
ExecStart=/usr/bin/intel-undervolt apply

[Install]
WantedBy=multi-user.target
EOF

# Enable without --now: a locked CPU makes the service fail at boot, which
# must not fail the install. Apply was already attempted above (warn-only).
run systemctl enable loq-undervolt.service 2>/dev/null || warn "could not enable loq-undervolt.service"
ok "loq-undervolt.service enabled (apply at boot, warn-only if locked)"

# -----------------------------------------------------------------------------
summary_line "04: undervolt ${LOQ_UNDERVOLT_CORE}/${LOQ_UNDERVOLT_UNCORE}/${LOQ_UNDERVOLT_CACHE}/${LOQ_UNDERVOLT_SA}/${LOQ_UNDERVOLT_IO} mV"
marker_set 04_cpu_undervolt

note "undervolt applied but NOT yet verified."
note "Run: sudo $ARCHLOQ_ROOT/manage/loq-uv-diagnose.sh   before trusting it."
ok "04 CPU undervolt complete"