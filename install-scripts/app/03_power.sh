#!/usr/bin/env bash
# =============================================================================
# 03 — power management
# =============================================================================
# The previous archloq setup enabled TLP, power-profiles-daemon, thermald and
# legiond at the same time. TLP and PPD both write the same cpufreq and
# runtime-PM knobs, so the winner was whichever started last and the result was
# not reproducible.
#
# Division of ownership here:
#   power-profiles-daemon  cpufreq policy, GPU runtime PM. Also the interface
#                          envycontrol uses when it changes GPU mode.
#   thermald               undervolt, temperature thresholds
#   legiond                EC-level hardware: fans, power limit, charge limits
#
# TLP is not installed and must not be.
# =============================================================================

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/utils.sh
source "$SCRIPT_DIR/../lib/utils.sh"

require_root
require_config
init_dirs

say "== 03 power management =="

# -----------------------------------------------------------------------------
# TLP must not be present. Leaving it installed is the exact configuration that
# made the old setup unpredictable.
# -----------------------------------------------------------------------------
tlp_present=0
for pkg in tlp tlp-rdw; do
  pacman -Qq "$pkg" >/dev/null 2>&1 && tlp_present=1
done
if ((tlp_present)); then
  warn "TLP is installed. It and power-profiles-daemon must not both manage power."
  if confirm "Remove TLP now?"; then
    pkg_remove tlp tlp-rdw
    ok "TLP removed"
  else
    warn "leaving TLP installed: expect power settings to fight. Remove it manually."
  fi
fi
rm -f /etc/tlp.conf 2>/dev/null || true

# -----------------------------------------------------------------------------
# power-profiles-daemon
# -----------------------------------------------------------------------------
pkg_install power-profiles-daemon
svc_enable power-profiles-daemon

if have powerprofilesctl; then
  available="$(powerprofilesctl list 2>/dev/null | tr '\n' ' ')"
  ok "power-profiles-daemon profiles: ${available:-unknown}"

  if powerprofilesctl get 2>/dev/null | grep -q .; then
    ok "current profile: $(powerprofilesctl get)"
  fi

  case "${LOQ_DEFAULT_POWER_PROFILE}" in
    power-saver|balanced|performance)
      run powerprofilesctl set "$LOQ_DEFAULT_POWER_PROFILE"
      ok "default profile set to $LOQ_DEFAULT_POWER_PROFILE"
      ;;
    *)
      warn "LOQ_DEFAULT_POWER_PROFILE=$LOQ_DEFAULT_POWER_PROFILE is not a valid profile"
      ;;
  esac
else
  warn "powerprofilesctl not found; PPD may not have started"
fi

# -----------------------------------------------------------------------------
# thermald
#
# thermald is what enforces the undervolt and the trip points. It owns those and
# nothing else. A re-applying oneshot unit would race with it and produce the
# "lost the undervolt after suspend" class of bug.
# -----------------------------------------------------------------------------
pkg_install thermald
svc_enable thermald

# -----------------------------------------------------------------------------
# legiond (AUR): fan curves, power limit, charge thresholds
#
# LOQ 17IRX10 support is not guaranteed by the upstream project. If it is not
# supported the daemon still starts and simply reports no controllable hardware,
# so treat "unit active but no fan control" as a degradation, not a failure.
# -----------------------------------------------------------------------------
if enabled "${LOQ_ENABLE_LEGIOND:-0}"; then
  if ! pacman -Qq legiond >/dev/null 2>&1; then
    if pkg_install_aur legiond; then
      ok "legiond installed"
    else
      warn "legiond unavailable; fan control stays with thermald and the firmware defaults"
      svc_enable thermald
      marker_set 03_power_no_legiond
    fi
  fi

  if pacman -Qq legiond >/dev/null 2>&1; then
    pkg_install python-pydbus
    install -Dm644 "$ARCHLOQ_ROOT/config/legiond/legiond.ini" /etc/legiond.conf 0644 \
      || warn "could not install /etc/legiond.conf"
    ok "installed /etc/legiond.conf"

    svc_enable legiond
    if systemctl is-active --quiet legiond; then
      ok "legiond is active"
      if have legionctl; then
        say "legiond sees: $(legionctl 2>/dev/null | tr '\n' ' ' | head -c 200 || true)"
      fi
    else
      warn "legiond did not start; check: journalctl -u legiond"
    fi
  fi
else
  skip "legiond disabled by config"
fi

# -----------------------------------------------------------------------------
# Charge thresholds (EC/firmware owned via legiond; upower is read-only)
# -----------------------------------------------------------------------------
if have upower && upower -e 2>/dev/null | grep -q .; then
  say "battery devices:"
  upower -e 2>/dev/null | while read -r dev; do
    [[ -n "$dev" ]] || continue
    name="$(upower -i "$dev" 2>/dev/null | awk -F': *' '/model name/ {print $2; exit}')"
    ok "$dev${name:+ ($name)}"
  done
  note "charge thresholds ${LOQ_BATTERY_CHARGE_START}%-${LOQ_BATTERY_CHARGE_END}% are enforced via legiond/EC (/etc/legiond.conf), not via upower (read-only)"
else
  skip "no battery found via upower; thresholds left to the firmware"
fi

# -----------------------------------------------------------------------------
# Panel brightness / backlight (brightnessctl replaces the retired light)
# -----------------------------------------------------------------------------
pkg_install brightnessctl || warn "brightnessctl unavailable; use xfce4-power-manager slider"

summary_line "03: PPD + thermald + legiond (TLP removed)"
marker_set 03_power
ok "03 power management complete"