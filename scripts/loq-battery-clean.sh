#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  loq-battery-clean.sh status
  loq-battery-clean.sh soft
  loq-battery-clean.sh hard

Modes:
  status  Show battery blockers.
  soft    Stop Docker/containerd and apply battery policy. Does not close apps.
  hard    Also terminates user apps currently holding /dev/nvidia*.
EOF
}

mode="${1:-status}"
case "$mode" in
  status|soft|hard) ;;
  *) usage >&2; exit 2 ;;
esac

echo "== Current blockers =="
loq-power-diag

if [[ "$mode" == "status" ]]; then
  exit 0
fi

echo
echo "== Applying battery policy =="
sudo loq-power-apply

echo
echo "== Stopping Docker services =="
sudo systemctl stop docker.service docker.socket containerd.service 2>/dev/null || true

if [[ "$mode" == "hard" ]]; then
  echo
  echo "== Terminating processes keeping NVIDIA awake =="
  pids="$(
    lsof -t /dev/nvidia* 2>/dev/null \
      | sort -u \
      | while read -r pid; do
          [[ -n "$pid" ]] || continue
          owner="$(ps -o user= -p "$pid" 2>/dev/null | awk '{print $1}')"
          [[ "$owner" == "$USER" ]] && echo "$pid"
        done
  )"

  if [[ -n "${pids:-}" ]]; then
    echo "$pids" | xargs -r kill -TERM
    sleep 3
    echo "$pids" | xargs -r kill -KILL 2>/dev/null || true
  else
    echo "No user processes found on /dev/nvidia*."
  fi
fi

echo
echo "== Result =="
sleep 2
loq-power-diag
