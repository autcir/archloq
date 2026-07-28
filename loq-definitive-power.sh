#!/usr/bin/env bash
set -euo pipefail

if [[ ${EUID} -ne 0 ]]; then
  echo "Run as root: sudo bash $0" >&2
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

backup_file() {
  local path="$1"
  if [[ -e "$path" && ! -e "${path}.bak-loq" ]]; then
    cp -a "$path" "${path}.bak-loq"
  fi
}

install_config() {
  install -d /etc/tlp.d /etc/legion_linux /etc/modprobe.d /etc/udev/rules.d

  backup_file /etc/tlp.d/lenovo-loq.conf
  install -m 0644 "$ROOT_DIR/config/tlp.d/lenovo-loq.conf" /etc/tlp.d/lenovo-loq.conf

  backup_file /etc/legion_linux/legiond.ini
  install -m 0644 "$ROOT_DIR/config/legion_linux/legiond.ini" /etc/legion_linux/legiond.ini

  backup_file /etc/modprobe.d/lenovo-loq.conf
  install -m 0644 "$ROOT_DIR/config/modprobe.d/lenovo-loq.conf" /etc/modprobe.d/lenovo-loq.conf

  cat >/etc/udev/rules.d/90-loq-power.rules <<'EOF'
SUBSYSTEM=="power_supply", ENV{POWER_SUPPLY_ONLINE}=="0", RUN+="/usr/bin/systemctl start loq-power-apply.service"
SUBSYSTEM=="power_supply", ENV{POWER_SUPPLY_ONLINE}=="1", RUN+="/usr/bin/systemctl start loq-power-apply.service"
EOF
}

install_scripts() {
  install -d /usr/local/bin
  install -m 0755 "$ROOT_DIR/scripts/loq-mode" /usr/local/bin/loq-mode
  install -m 0755 "$ROOT_DIR/scripts/loq-power-apply" /usr/local/bin/loq-power-apply
  install -m 0755 "$ROOT_DIR/scripts/loq-power-diag" /usr/local/bin/loq-power-diag
  install -m 0755 "$ROOT_DIR/scripts/loq-battery-clean.sh" /usr/local/bin/loq-battery-clean
}

install_services() {
  cat >/etc/systemd/system/loq-power-apply.service <<'EOF'
[Unit]
Description=Apply Lenovo LOQ AC/battery power policy
After=multi-user.target tlp.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/loq-power-apply

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload

  # TLP + thermald + acpid sono sempre presenti (repo Arch)
  systemctl enable tlp.service thermald.service acpid.service loq-power-apply.service >/dev/null

  # legiond è AUR — può non essere installato. Non nascondere l'errore, avvisa.
  if systemctl list-unit-files legiond.service >/dev/null 2>&1; then
    systemctl enable legiond.service >/dev/null
  else
    echo "AVVISO: legiond non installato (AUR). Salto enable legiond.service" >&2
    echo "  Installa con: yay -S legiond" >&2
  fi

  systemctl disable --now nvidia-persistenced.service >/dev/null 2>&1 || true
  systemctl disable --now loq-fnq-sync.path >/dev/null 2>&1 || true

  rm -f \
    /etc/acpi/events/loq-fnq-cycle \
    /etc/systemd/system/loq-fnq-sync.path \
    /etc/systemd/system/loq-fnq-sync.service

  if [[ -e /etc/acpi/handler.sh.bak-loq-fnq ]]; then
    cp -a /etc/acpi/handler.sh.bak-loq-fnq /etc/acpi/handler.sh
  fi

  systemctl mask power-profiles-daemon.service systemd-rfkill.service systemd-rfkill.socket >/dev/null 2>&1 || true
  systemctl stop systemd-rfkill.service systemd-rfkill.socket >/dev/null 2>&1 || true
  systemctl restart tlp.service
  systemctl restart thermald.service
  systemctl restart legiond.service 2>/dev/null || echo "AVVISO: legiond.service non disponibile (AUR non installato)" >&2
  systemctl restart acpid.service
  udevadm control --reload-rules
  systemctl start loq-power-apply.service
}

install_config
install_scripts
install_services

echo "Installed Lenovo LOQ power management."
echo "Run: loq-power-diag"
