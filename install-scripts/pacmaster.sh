#!/usr/bin/env bash
# =============================================================================
# pacmaster — orchestrator
# =============================================================================
# Runs the numbered install steps in order, then the audit and the pre-reboot
# gate. Every step is idempotent, so re-running after fixing one failure is safe
# and cheaper than starting over.
#
#   sudo ./install-scripts/pacmaster.sh              run everything
#   sudo ./install-scripts/pacmaster.sh 01 02 07    run selected steps
#   sudo ./install-scripts/pacmaster.sh --list       show the steps
#   sudo ./install-scripts/pacmaster.sh --audit      only re-run the audit
#
# On first boot after the installer has already run, you almost always want:
#   ./install-scripts/pacmaster.sh --resume
# which skips the steps that already left a completion marker.
# =============================================================================

set -euo pipefail

PACMASTER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARCHLOQ_ROOT="$(cd "$PACMASTER_DIR/.." && pwd)"
export ARCHLOQ_ROOT
# shellcheck source=lib/utils.sh
source "$PACMASTER_DIR/lib/utils.sh"

usage() {
  sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'
  cat <<'EOF'

Options:
  --list        list the install steps and their completion state
  --audit       run only 90_postinstall.sh
  --resume      run only the steps that have no completion marker
  --from N      start at step N and run everything from there
  -h, --help    this text

Steps always run:  90_postinstall.sh, 99_safe_reboot_check.sh
EOF
}

APP_DIR="$PACMASTER_DIR/app"
STEPS=(
  01_kernel_boot.sh
  02_gpu_nvidia.sh
  03_power.sh
  04_cpu_undervolt.sh
  05_desktop_xfce.sh
  06_hardening.sh
  07_snapshots.sh
  08_backup_borg.sh
  09_dotfiles.sh
  10_software.sh
)

# 01_kernel_boot.sh -> 01_kernel_boot, which is the state marker name.
marker_for() { printf '%s' "${1%.sh}"; }

list_steps() {
  say "install steps:"
  local step marker
  for step in "${STEPS[@]}"; do
    marker="$(marker_for "$step")"
    if marker_done "$marker"; then
      printf '  %s  %-28s done\n' "$C_GREEN" "$step"
    else
      printf '  %s  %-28s pending\n' "$C_DIM" "$step"
    fi
  done
}

main() {
  local -a selected=()
  local only_audit=0
  local only_resume=0
  local from_step=""

  if (($# == 0)); then
    selected=("${STEPS[@]}")
  else
    while (($#)); do
      case "$1" in
        -h|--help) usage; exit 0 ;;
        --list) list_steps; exit 0 ;;
        --audit) only_audit=1; shift ;;
        --resume) only_resume=1; shift ;;
        --from)
          [[ -n "${2:-}" ]] || die "--from needs a step number, e.g. --from 02"
          from_step="$2"
          shift 2
          ;;
        [0-9]*)
          local found=0
          for step in "${STEPS[@]}"; do
            if [[ "$step" == "$1"* ]]; then
              selected+=("$step")
              found=1
              break
            fi
          done
          ((found)) || die "no install step matches '$1'"
          shift
          ;;
        *) die "unknown argument: $1 (try --help)" ;;
      esac
    done
  fi

  require_root
  require_config
  init_dirs
  rm -f "$ARCHLOQ_STATE_DIR/summary"

  if ((only_audit)); then
    selected=()
  fi

  # --from N: keep only steps at or after the first one matching N.
  if [[ -n "$from_step" ]]; then
    local -a tail_steps=()
    local skipping=1 step
    for step in "${STEPS[@]}"; do
      if ((skipping)) && [[ "$step" == "$from_step"* ]]; then
        skipping=0
      fi
      ((skipping)) || tail_steps+=("$step")
    done
    ((skipping)) && die "no install step starts with '$from_step'"
    selected=("${tail_steps[@]}")
  fi

  if ((only_resume)); then
    local -a pending=()
    for step in "${STEPS[@]}"; do
      if marker_done "$(marker_for "$step")"; then
        skip "$step already done"
      else
        pending+=("$step")
      fi
    done
    selected=("${pending[@]}")
  fi

  ((${#selected[@]})) && say "will run: ${selected[*]}"

  local step start total=0
  for step in "${selected[@]}"; do
    total=$((total + 1))
    say "[$total/${#selected[@]}] ${step}"
    start="$(date +%s)"

    if "$APP_DIR/$step"; then
      ok "${step} finished in $(( $(date +%s) - start ))s"
    else
      err "${step} FAILED after $(( $(date +%s) - start ))s"
      err "state so far:"
      list_steps
      echo
      err "Fix the cause and re-run just that step, then resume:"
      err "  $0 --resume"
      exit 1
    fi
  done

  # The audit and the gate always run: they are what tells you the machine is
  # safe to reboot.
  say "auditing"
  if ! "$APP_DIR/90_postinstall.sh"; then
    err "the audit found problems. Not declaring success."
    list_steps
    exit 1
  fi

  say "pre-reboot gate"
  if ! "$APP_DIR/99_safe_reboot_check.sh"; then
    err "the pre-reboot gate failed. See the recovery notes above."
    exit 1
  fi

  ok ""
  ok "install complete"
  list_steps
}

main "$@"