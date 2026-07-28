#!/usr/bin/env bash
# LOQ 17IRX10 — CLI moderna SOTA July 2026.
# Installa i pacchetti che rendono la shell zsh degna di un dev laptop 2026.
# Idempotente: safe to re-run.
#
#   sudo bash install-cli.sh
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ $EUID -eq 0 ]] || { echo "run with sudo"; exit 1; }

say(){ printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }

# --- repo packages (pacman) --------------------------------------------------
PAC_PKGS=(
  fzf
  zoxide
  eza
  git-delta
  bat
  ripgrep
  fd
  jq
  ttf-jetbrains-mono-nerd
)

say "Installing CLI moderna via pacman: ${PAC_PKGS[*]}"
pacman -S --needed --noconfirm "${PAC_PKGS[@]}"

# --- mise (runtime manager: node, python, go, rust) -------------------------
# SoT replacement for nvm/pyenv/asdf. Da AUR per evitare lo script curl.
say "Installing mise via AUR (skip if already present)"
if ! command -v mise >/dev/null 2>&1; then
  if command -v yay >/dev/null 2>&1; then
    sudo -u "${SUDO_USER:-$USER}" yay -S --needed --noconfirm mise-bin
  else
    echo "AVVISO: yay non trovato. Installa mise manualmente: yay -S mise-bin" >&2
  fi
else
  echo "  mise gia installato"
fi

# --- legiond (AUR — Lenovo Legion/LOQ daemon) --------------------------------
say "Checking legiond (AUR)"
if ! pacman -Q legiond >/dev/null 2>&1; then
  if command -v yay >/dev/null 2>&1; then
    echo "  Installazione legiond via yay..."
    sudo -u "${SUDO_USER:-$USER}" yay -S --needed --noconfirm legiond
  else
    echo "AVVISO: legiond non installato. Installa con: yay -S legiond" >&2
  fi
else
  echo "  legiond gia installato"
fi

# --- user configs (Wayland flags) --------------------------------------------
say "Copying user .config flags (chromium, electron, code, wayland env)"
USER_HOME="$(getent passwd "${SUDO_USER:-$USER}" | cut -d: -f6)"
USER_CFG="$HERE/user/.config"
for f in chromium-flags.conf electron-flags.conf code-flags.conf; do
  if [[ -f "$USER_CFG/$f" ]]; then
    install -Dm 0644 "$USER_CFG/$f" "$USER_HOME/.config/$f"
    chown "${SUDO_USER:-$USER}:${SUDO_USER:-$USER}" "$USER_HOME/.config/$f"
  fi
done
if [[ -d "$USER_CFG/environment.d" ]]; then
  mkdir -p "$USER_HOME/.config/environment.d"
  cp -av "$USER_CFG/environment.d/"* "$USER_HOME/.config/environment.d/" 2>/dev/null || true
  chown -R "${SUDO_USER:-$USER}:${SUDO_USER:-$USER}" "$USER_HOME/.config/environment.d/"
fi

# --- zshrc reference (non sovrascrive, solo copia se non esiste) -------------
say "Checking ~/.zshrc for loq dev CLI block"
ZSHRC="$USER_HOME/.zshrc"
if ! grep -q "loq dev CLI" "$ZSHRC" 2>/dev/null; then
  echo "  AVVISO: ~/.zshrc non ha il blocco 'loq dev CLI'." >&2
  echo "  Reference: $HERE/user/zshrc.reference (sezioncina in fondo)" >&2
  echo "  Per integrare: aggiungi le righe dopo '# ===== loq dev CLI =====' nel tuo ~/.zshrc" >&2
else
  echo "  zshrc: blocco loq dev CLI gia presente"
fi

say "CLI SOTA install completa. Riavvia la shell: exec zsh"
