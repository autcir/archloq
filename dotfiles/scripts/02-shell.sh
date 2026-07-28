#!/usr/bin/env bash
# 02-shell.sh — starship prompt con palette One Dark Pro + zsh plugin check.
# Sostituisce powerlevel10k con starship (più veloce, più portabile).
set -euo pipefail

say()  { printf '\n\033[1;36m[INFO]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[OK]\033[0m  %s\n' "$*"; }
skip() { printf '\033[1;33m[SKIP]\033[0m %s\n' "$*"; }

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTROOT="$(cd "$HERE/.." && pwd)"

# --- starship ---------------------------------------------------------------
say "Installing starship prompt"
if command -v starship >/dev/null 2>&1; then
  skip "starship già installato"
else
  sudo pacman -S --needed --noconfirm starship
  ok "installato starship"
fi

# --- starship config (One Dark Pro) -----------------------------------------
say "Installing starship config (One Dark Pro)"
STARSHIP_DIR="$HOME/.config"
mkdir -p "$STARSHIP_DIR"
cp -af "$DOTROOT/config/starship/starship.toml" "$STARSHIP_DIR/starship.toml"
ok "starship config → $STARSHIP_DIR/starship.toml"

# --- zshrc: swap p10k → starship --------------------------------------------
say "Updating ~/.zshrc (swap p10k → starship)"
ZSHRC="$HOME/.zshrc"
if ! grep -q 'starship init zsh' "$ZSHRC" 2>/dev/null; then
  # Backup se non esiste già
  [ ! -f "$ZSHRC.loq-bak" ] && [ -f "$ZSHRC" ] && cp -a "$ZSHRC" "$ZSHRC.loq-bak"
  # Commenta p10k instant prompt (se presente)
  sed -i 's/^source.*p10k-instant-prompt/#&/' "$ZSHRC" 2>/dev/null || true
  # Commenta p10k source (se presente)
  sed -i 's/^.*source.*\.p10k\.zsh/#&/' "$ZSHRC" 2>/dev/null || true
  # Cambia ZSH_THEME da powerlevel10k a starship
  sed -i 's/^ZSH_THEME="powerlevel10k\/powerlevel10k"/ZSH_THEME=""/' "$ZSHRC" 2>/dev/null || true
  # Aggiungi starship init in fondo
  echo '' >> "$ZSHRC"
  echo '# Starship prompt — One Dark Pro (loq dotfiles)' >> "$ZSHRC"
  echo 'eval "$(starship init zsh)"' >> "$ZSHRC"
  ok "starship init aggiunto a ~/.zshrc"
else
  skip "starship init già presente in ~/.zshrc"
fi

# --- zsh plugins check (già installati via oh-my-zsh custom) ----------------
say "Checking zsh plugins (zsh-autosuggestions, zsh-syntax-highlighting)"
OMZ_CUSTOM="$HOME/.oh-my-zsh/custom"
for plugin in zsh-autosuggestions zsh-syntax-highlighting; do
  if [ -d "$OMZ_CUSTOM/plugins/$plugin" ]; then
    skip "$plugin già installato"
  else
    git clone "https://github.com/zsh-users/$plugin.git" "$OMZ_CUSTOM/plugins/$plugin"
    ok "clonato $plugin"
  fi
done

ok "02-shell completa"
