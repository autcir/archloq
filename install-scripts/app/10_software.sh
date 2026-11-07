#!/usr/bin/env bash
# =============================================================================
# 10 — software
# =============================================================================
# Development workstation. The LLM stack (ollama, llama.cpp, open-webui) is
# deliberately gone: it idles on the GPU. Docker GPU passthrough still works,
# because the driver and libcuda come from nvidia-open-dkms, not from a host-side
# LLM runtime.
# =============================================================================

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/utils.sh
source "$SCRIPT_DIR/../lib/utils.sh"

require_root
require_config
init_dirs

say "== 10 software =="

# -----------------------------------------------------------------------------
# Base CLI
# -----------------------------------------------------------------------------
pkg_install \
  git git-lfs base-devel git-delta sudo \
  zsh starship tmux neovim \
  bat fastfetch btop cava \
  tree eza ripgrep fd fzf zoxide \
  rsync wget curl jq yq man-db man-pages lsd \
  diff-so-fancy shadow

# -----------------------------------------------------------------------------
# Shell as the default login shell
# -----------------------------------------------------------------------------
target_home="$(getent passwd "$LOQ_USERNAME" | cut -d: -f6)"
if [[ -n "$target_home" ]]; then
  if [[ "$(getent passwd "$LOQ_USERNAME" | cut -d: -f7)" != "/bin/zsh" ]]; then
    usermod -s /bin/zsh "$LOQ_USERNAME"
    ok "$LOQ_USERNAME login shell is now /bin/zsh"
  fi
  chsh -s /bin/zsh "$LOQ_USERNAME" >/dev/null 2>&1 || true
  install -d -m 0755 -o "$LOQ_USERNAME" -g "$LOQ_USERNAME" "$target_home/.cache"
fi

# -----------------------------------------------------------------------------
# makepkg flags (bash, not INI — makepkg.conf is sourced)
# -----------------------------------------------------------------------------
{
  printf '# archloq: build for this machine, not for the lowest common denominator.\n'
  printf 'MAKEFLAGS="-j%s"\n' "${LOQ_MAKEPKG_JOBS:-$(nproc)}"
  printf 'CFLAGS="-march=%s -mtune=native -O2 -pipe -fno-plt"\n' "${LOQ_MAKEPKG_MARCH:-native}"
  printf 'CXXFLAGS="-march=%s -mtune=native -O2 -pipe -fno-plt"\n' "${LOQ_MAKEPKG_MARCH:-native}"
  printf 'LDFLAGS="-Wl,-O2,--as-needed -Wl,-z,relro,-z,now"\n'
} | write_file /etc/makepkg.conf.d/archloq.conf 0644

# -----------------------------------------------------------------------------
# Containers
# -----------------------------------------------------------------------------
if enabled "${LOQ_ENABLE_DOCKER:-0}"; then
  pkg_install docker docker-compose
  if [[ -n "$target_home" ]]; then
    usermod -aG docker "$LOQ_USERNAME"
    ok "added $LOQ_USERNAME to the docker group"
    note "docker group membership is root-equivalent; that is how Docker works."
  fi
  svc_enable docker

  # nvidia-container-toolkit is in Arch extra; no third-party repo needed.
  # The old script added a Debian .list file into /etc/pacman.d, which pacman
  # cannot read. Just install the Arch package.
  if ! pacman -Qq nvidia-container-toolkit >/dev/null 2>&1; then
    if pkg_install nvidia-container-toolkit; then
      ok "nvidia-container-toolkit installed from extra"
      if have nvidia-ctk; then
        nvidia-ctk runtime configure --runtime=docker || warn "nvidia-ctk runtime configure failed"
        run systemctl restart docker
        ok "Docker GPU runtime configured"
      fi
    else
      warn "nvidia-container-toolkit not available; --gpus will not work in containers"
    fi
  fi
else
  skip "docker disabled by config"
fi

# -----------------------------------------------------------------------------
# Kubernetes
# -----------------------------------------------------------------------------
if enabled "${LOQ_ENABLE_KUBERNETES:-0}"; then
  pkg_install kubectl
  pkg_install_aur helm k9s kubectl-ctx || warn "some AUR kubectl tooling was not installed"
  ok "kubernetes tooling installed"
else
  skip "kubernetes disabled by config"
fi

# -----------------------------------------------------------------------------
# Languages
# -----------------------------------------------------------------------------
if enabled "${LOQ_ENABLE_LANGUAGES:-0}"; then
  pkg_install nodejs npm
  if have npm; then
    if npm install -g pnpm >/dev/null 2>&1; then
      ok "pnpm installed"
    else
      warn "pnpm install failed"
    fi
  fi
  pkg_install python python-pip
  if curl -fsSL https://astral.sh/uv/install.sh | sh >/dev/null 2>&1; then
    ok "uv installed"
  else
    warn "uv install failed; install it manually"
  fi
else
  skip "language toolchains disabled by config"
fi

# -----------------------------------------------------------------------------
# Browsers
# -----------------------------------------------------------------------------
if enabled "${LOQ_ENABLE_BROWSERS:-0}"; then
  pkg_install firefox
fi
if enabled "${LOQ_ENABLE_CHROME:-0}"; then
  pkg_install_aur google-chrome-stable || warn "google-chrome-stable was not installed"
fi

# -----------------------------------------------------------------------------
# Media
# -----------------------------------------------------------------------------
if enabled "${LOQ_ENABLE_MEDIA:-0}"; then
  pkg_install ffmpeg mkvtoolnix handbrake
else
  skip "media tools disabled by config"
fi

summary_line "10: dev stack, containers, languages"
marker_set 10_software
ok "10 software complete"
