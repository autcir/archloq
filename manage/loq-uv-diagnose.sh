#!/usr/bin/env bash
# =============================================================================
# loq-uv-diagnose — is the CPU undervolt actually stable?
# =============================================================================
# An undervolt that is too aggressive does not crash immediately. It corrupts
# results quietly, hours later, in whatever was running. The only honest way to
# validate one is to stress the CPU for a long time while watching for hardware
# error reports, and to bisect when one appears.
#
#   loq-uv-diagnose.sh                 45 minute run, the default
#   loq-uv-diagnose.sh --minutes 90    longer
#   loq-uv-diagnose.sh --show          what is applied right now, no stress
#   loq-uv-diagnose.sh --reset         return to stock
# =============================================================================

set -euo pipefail
MANAGE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARCHLOQ_ROOT="$(cd "$MANAGE_DIR/.." && pwd)"
export ARCHLOQ_ROOT
# shellcheck source=../install-scripts/lib/utils.sh
source "$ARCHLOQ_ROOT/install-scripts/lib/utils.sh"

require_root
require_config

minutes=45
mode=stress

while (($#)); do
  case "$1" in
    --minutes) [[ -n "${2:-}" ]] || die "--minutes needs a number"; minutes="$2"; shift 2 ;;
    --show) mode=show; shift ;;
    --reset) mode=reset; shift ;;
    -h|--help) sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done

# -----------------------------------------------------------------------------
# What is applied right now?
# -----------------------------------------------------------------------------
show_current() {
  say "current undervolt"
  if have intel-undervolt; then
    intel-undervolt -s 2>/dev/null || warn "intel-undervolt -s returned nothing"
  else
    warn "intel-undervolt is not installed"
  fi

  say "effective values as the CPU reports them"
  for zone in /sys/devices/virtual/thermal/thermal_zone*; do
    [[ -r "${zone}offset" ]] || continue
    printf '        %-28s offset %s mV  (type %s)\n' \
      "$(basename "$zone")" "$(cat "${zone}offset")" "$(cat "${zone}type" 2>/dev/null || echo '?')"
  done

  if [[ -r /sys/devices/system/cpu/intel_pstate/no_turbo ]]; then
    say "intel_pstate no_turbo = $(cat /sys/devices/system/cpu/intel_pstate/no_turbo)"
  fi
}

case "$mode" in
  show)
    show_current
    exit 0
    ;;
  reset)
    say "removing the undervolt"
    systemctl disable --now loq-undervolt.service 2>/dev/null || true
    rm -f /etc/intel-undervolt.conf
    have intel-undervolt && intel-undervolt -r 2>/dev/null || true
    ok "undervolt removed; the CPU is back to stock"
    say "set LOQ_ENABLE_UNDERVOLT=0 in config/loq.conf to keep it that way"
    exit 0
    ;;
esac

# -----------------------------------------------------------------------------
# Stress
# -----------------------------------------------------------------------------
if ! enabled "${LOQ_ENABLE_UNDERVOLT:-0}"; then
  warn "LOQ_ENABLE_UNDERVOLT=0, so nothing is undervolted. There is nothing to diagnose."
  exit 0
fi

show_current

if [[ ! -f /etc/intel-undervolt.conf ]]; then
  die "/etc/intel-undervolt.conf is missing. Run install-scripts/app/04_cpu_undervolt.sh first."
fi

# A stress run on an unstable undervolt should not be the first thing to happen.
if ! timeshift --list >/dev/null 2>&1; then
  warn "timeshift is not usable; consider loq-snapshot.sh pre-kernel first"
else
  say "taking a pre-kernel snapshot so this run is recoverable"
  "$MANAGE_DIR/loq-snapshot.sh" pre-kernel "before uv-diagnose (${minutes}m)" || \
    warn "could not create the snapshot; continue anyway"
fi

if ! have stress-ng; then
  pkg_install stress-ng || die "stress-ng is required"
fi

threads="$(nproc)"
say "stressing ${threads} threads for ${minutes} minutes"
info "this raises the temperature and will make the fans loud; that is the point"

dmesg_before="$(dmesg 2>/dev/null | wc -l || echo 0)"

# --matrix exercises AVX/FMA/vector paths where voltage droop shows up first.
# --verify makes stress-ng confirm the operation actually did work.
if have timeout; then
  timeout --signal=SIGTERM "${minutes}m" \
    stress-ng --cpu "$threads" --matrix 1 --matrix-size 64 --verify \
    --timeout "${minutes}m" --metrics-brief &
else
  stress-ng --cpu "$threads" --matrix 1 --matrix-size 64 --verify \
    --timeout "${minutes}m" --metrics-brief &
fi
stress_pid=$!

# Watch for hardware errors while the CPU is loaded. WHEA-Logger is 18, machine
# check is 19; both mean the silicon reported an actual fault.
watch_start="$(date '+%s')"
hardware_faults=0
while kill -0 "$stress_pid" 2>/dev/null; do
  new_faults="$(dmesg 2>/dev/null | tail -n +"$((dmesg_before + 1))" \
    | grep -ciE 'WHEA|hardware error|MCE|machine check|edac.*error' || true)"
  if ((new_faults > hardware_faults)); then
    err "hardware error reported while stressing"
    dmesg 2>/dev/null | tail -n +"$((dmesg_before + 1))" \
      | grep -iE 'WHEA|hardware error|MCE|machine check|edac.*error' | tail -5 | sed 's/^/        /'
    hardware_faults="$new_faults"
    kill -TERM "$stress_pid" 2>/dev/null || true
    break
  fi
  elapsed=$(( $(date '+%s') - watch_start ))
  [[ $((elapsed % 300)) -lt 5 ]] && printf '        %dm elapsed, no hardware errors so far\n' "$((elapsed / 60))"
  sleep 5
done

wait "$stress_pid" 2>/dev/null || true

# -----------------------------------------------------------------------------
# Verdict
# -----------------------------------------------------------------------------
echo
final_faults="$(dmesg 2>/dev/null | tail -n +"$((dmesg_before + 1))" \
  | grep -ciE 'WHEA|hardware error|MCE|machine check|edac.*error' || true)"

if ((final_faults > 0)); then
  err "FAILED: $final_faults hardware error(s) during a ${minutes} minute run."
  echo
  err "Your undervolt is not stable on this CPU. Do the following:"
  err "  1. loq-uv-diagnose.sh --reset        return to stock, keep the laptop usable"
  err "  2. Edit config/loq.conf and halve the offending offset"
  err "  3. 04_cpu_undervolt.sh, then run this again"
  err
  err "The current values are:"
  grep -E '^\s+\S+\s+-' /etc/intel-undervolt.conf | sed 's/^/        /'
  err
  err "If even -10 mV fails, set LOQ_ENABLE_UNDERVOLT=0. Raptor Lake does not need"
  err "an undervolt to run at its intended frequency."
  exit 1
fi

ok "PASSED: ${minutes} minutes of CPU+AVX stress with no WHEA/MCE errors."
say ""
say "That is good evidence the undervolt is stable, not proof. A tighter test is"
say "--minutes 240 run cold. Whatever you decide, write the result down:"
say "  ${LOQ_UNDERVOLT_CORE}/${LOQ_UNDERVOLT_UNCORE}/${LOQ_UNDERVOLT_CACHE}/${LOQ_UNDERVOLT_SA}/${LOQ_UNDERVOLT_IO} mV -- passed ${minutes}m"
