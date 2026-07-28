#!/usr/bin/env bash
# ============================================================================
#  loq-backup.sh — maniacal, reproducible backup for archloq (Lenovo LOQ 17IRX10)
#
#  Produces under ~/backups/loq-<DATE>/ :
#    pkglist-*.txt          native + AUR package manifests (for pacman -S restore)
#    dotfiles.tar.zst       non-secret dotfiles / configs
#    chrome-Bookmarks.json  Chrome bookmarks (plaintext, non-secret)
#    MANIFEST.txt           what this snapshot contains + host facts
#    secrets.tar.zst.gpg    ENCRYPTED: ~/.ssh, API keys, .claude.json, Chrome logins
#
#  Usage:
#    bash loq-backup.sh                 # interactive gpg passphrase (symmetric)
#    RECIPIENT=you@key bash loq-backup.sh   # asymmetric (unattended timer-safe)
#
#  NOTE: output goes to ~/backups — keep that OUT of any cloud-synced folder.
# ============================================================================
set -euo pipefail
DATE="$(date +%Y%m%d-%H%M)"
OUT="$HOME/backups/loq-$DATE"
mkdir -p "$OUT"
say(){ printf '\033[1;36m==> %s\033[0m\n' "$*"; }

# ---------------------------------------------------------------- 1. packages
say "Package manifests"
pacman -Qqe  > "$OUT/pkglist-explicit.txt"      # everything explicitly installed
pacman -Qqm  > "$OUT/pkglist-aur.txt"           # foreign/AUR only
pacman -Qqen > "$OUT/pkglist-native.txt"        # repo, explicit
# restore later with:  sudo pacman -S --needed - < pkglist-native.txt ; yay -S - < pkglist-aur.txt

# ---------------------------------------------------------------- 2. dotfiles (non-secret)
say "Dotfiles + configs (non-secret)"
tar -C "$HOME" --ignore-failed-read -caf "$OUT/dotfiles.tar.zst" \
  .zshrc .p10k.zsh .gitconfig \
  .config/environment.d \
  .config/code-flags.conf .config/electron-flags.conf .config/chromium-flags.conf \
  .config/Code/User/settings.json .config/Code/User/keybindings.json \
  .local/share/konsole .config/konsolerc \
  .config/systemd/user \
  .claude/CLAUDE.md .claude/settings.json .claude/skills .claude/commands \
  2>/dev/null || true

# ---------------------------------------------------------------- 3. Chrome (non-secret bits)
say "Chrome bookmarks"
CH="$HOME/.config/google-chrome/Default"
cp -f "$CH/Bookmarks" "$OUT/chrome-Bookmarks.json" 2>/dev/null || true

# ---------------------------------------------------------------- 4. SECRETS -> encrypted
say "Collecting secrets (SSH, API keys, Chrome logins, MCP config)"
SEC="$(mktemp -d)"; trap 'rm -rf "$SEC"' EXIT
mkdir -p "$SEC/ssh" "$SEC/chrome" "$SEC/openvidia"
cp -a "$HOME/.ssh/." "$SEC/ssh/" 2>/dev/null || true
cp -a "$HOME/.claude.json" "$SEC/claude.json" 2>/dev/null || true          # MCP servers + tokens
cp -a "$HOME/.config/openvidia/keys.json" "$HOME/.config/openvidia/accounts.json" "$SEC/openvidia/" 2>/dev/null || true
cp -a "$HOME/.gnupg" "$SEC/gnupg" 2>/dev/null || true
# Chrome password/session restore needs BOTH these files AND the keyring key (see docs).
for f in "Login Data" "Cookies" "Web Data" "$HOME/.config/google-chrome/Local State"; do
  cp -a "$CH/$f" "$SEC/chrome/" 2>/dev/null || cp -a "$f" "$SEC/chrome/" 2>/dev/null || true
done
# kwallet "Chrome Safe Storage" key is required to decrypt the above on a new install:
kwallet-query -l kdewallet 2>/dev/null > "$SEC/chrome/KWALLET-note.txt" || true

say "Encrypting secrets -> secrets.tar.zst.gpg"
if [[ -n "${RECIPIENT:-}" ]]; then
  tar -C "$SEC" -caf - . | gpg --encrypt --recipient "$RECIPIENT" -o "$OUT/secrets.tar.zst.gpg"
else
  tar -C "$SEC" -caf - . | gpg --symmetric --cipher-algo AES256 -o "$OUT/secrets.tar.zst.gpg"
fi
chmod 600 "$OUT/secrets.tar.zst.gpg"

# ---------------------------------------------------------------- 5. manifest
{
  echo "archloq backup $DATE"
  echo "host: $(hostnamectl hostname 2>/dev/null)  kernel: $(uname -r)"
  echo "native pkgs: $(wc -l < "$OUT/pkglist-native.txt")  aur: $(wc -l < "$OUT/pkglist-aur.txt")"
  echo "secrets bundle: ssh, .claude.json (MCP), openvidia keys, gnupg, chrome logins"
  echo "reproducible /etc lives in git: ~/Documenti/cbrain/dev/arch/loq"
} > "$OUT/MANIFEST.txt"

say "DONE -> $OUT"
du -sh "$OUT"
echo "Off-machine copy (do this!):  rsync -a --delete ~/backups/  <external-or-remote>:loq-backups/"
