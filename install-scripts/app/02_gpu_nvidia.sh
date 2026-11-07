#!/usr/bin/env bash
# =============================================================================
# 02 — NVIDIA Blackwell driver and GPU mode switching
# =============================================================================
# The RTX 5060 Laptop in this machine is a GB206M (Blackwell, sm_120). There is
# NO closed-source driver for it: NVIDIA stopped shipping one and `nvidia-open`
# is the only supported option. The previous archloq script installed
# `nvidia-dkms`, which simply does not exist for this GPU.
#
# GSP firmware is mandatory on nvidia-open and cannot be disabled. Do not carry
# over NVreg_EnableGpuFirmware=0 folklore from the closed-driver era.
# =============================================================================

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/utils.sh
source "$SCRIPT_DIR/../lib/utils.sh"

require_root
require_config
init_dirs

say "== 02 NVIDIA graphics =="

# -----------------------------------------------------------------------------
# Guard against the closed driver being requested again.
# NOTE: nvidia-open-dkms Provides: nvidia-dkms, so `pacman -Qq nvidia-dkms`
# matches the open driver too. Match exact package names only.
# -----------------------------------------------------------------------------
if pacman -Qq nvidia-open-dkms >/dev/null 2>&1; then
  ok "nvidia-open-dkms present (correct for Blackwell GB206M)"
else
  for pkg in nvidia-dkms nvidia; do
    if pacman -Qq 2>/dev/null | grep -qx "$pkg"; then
      die "$pkg is installed but this GPU is Blackwell (GB206M) and has no closed driver. Run: pacman -R $pkg"
    fi
  done
fi

# -----------------------------------------------------------------------------
# Driver
# -----------------------------------------------------------------------------
# shellcheck disable=SC2086  # LOQ_NVIDIA_PACKAGES is an intentional word list
pkg_install $LOQ_NVIDIA_PACKAGES

# DKMS needs headers for the configured kernel. The old loop derived package
# names from /usr/lib/modules/<version>/build (e.g. 7.2.9-zen1-1-zen-headers),
# which do not exist. Install the real header package instead.
pkg_install "${LOQ_KERNEL}-headers"

# -----------------------------------------------------------------------------
# Platform module options (i915 framebuffer compression, audio power saving,
# USB autosuspend). Kept separate from the NVIDIA file because 02 rewrites the
# NVIDIA options on every run and this one is static.
# -----------------------------------------------------------------------------
if [[ -f "$ARCHLOQ_ROOT/config/modprobe.d/lenovo-loq.conf" ]]; then
  install -Dm644 "$ARCHLOQ_ROOT/config/modprobe.d/lenovo-loq.conf" /etc/modprobe.d/lenovo-loq.conf
  ok "installed /etc/modprobe.d/lenovo-loq.conf"
else
  warn "config/modprobe.d/lenovo-loq.conf is missing; platform module options not applied"
fi

# -----------------------------------------------------------------------------
# NVIDIA module options
# -----------------------------------------------------------------------------
write_file /etc/modprobe.d/nvidia.conf 0644 <<'EOF'
# archloq — NVIDIA GB206M (Blackwell)
#
# modeset=1 is required: without it nvidia_drm does not do KMS and the
# display manager cannot set a mode on the dGPU.
#
# NVreg_DynamicPowerManagement=0x02 selects fine-grained PCI Express Runtime D3
# (RTD3), which is what actually lets the dGPU idle between frames. 0x00 is no
# power management, 0x01 is the coarse variant that does not save much.
#
# PreserveVideoMemoryAllocations keeps the VRAM contents across suspend, which
# avoids a corrupted desktop on resume.
options nvidia_drm modeset=1 fbdev=1
options nvidia NVreg_DynamicPowerManagement=0x02 NVreg_PreserveVideoMemoryAllocations=1
EOF

# systemd-boot hands control to the kernel via the initramfs; the nvidia module
# must be early so the dGPU is bound before the first userspace frame.
write_file /etc/mkinitcpio.conf.d/nvidia.conf 0644 <<'EOF'
install_modules+=" nvidia nvidia_drm nvidia_modeset nvidia_uvm "
EOF

# -----------------------------------------------------------------------------
# PRIME / GPU switching
#
# envycontrol drives the PRIME profiles and is explicitly documented as
# compatible with SDDM. supergfxctl is not used: its own wiki advises against
# installing it during the transition to its successor (cardwire) unless VFIO is
# needed, and nothing here needs VFIO.
# -----------------------------------------------------------------------------
if ! pacman -Qq envycontrol >/dev/null 2>&1; then
  if pkg_install_aur envycontrol; then
    ok "envycontrol installed"
  else
    warn "envycontrol unavailable; GPU mode cannot be switched. The driver still works in hybrid mode."
  fi
fi

# power-profiles-daemon is the only policy owner. envycontrol talks to it when it
# changes GPU mode, and we do not run TLP for exactly this reason.
pkg_install power-profiles-daemon
svc_enable power-profiles-daemon

if enabled "${LOQ_ENABLE_NVIDIA_RTD3:-1}"; then
  ok "fine-grained RTD3 requested (NVreg_DynamicPowerManagement=0x02)"
else
  note "RTD3 disabled by config; the dGPU will draw more idle power"
  sed_idempotent /etc/modprobe.d/nvidia.conf 's/NVreg_DynamicPowerManagement=0x02 //' \
    "removed the RTD3 parameter from /etc/modprobe.d/nvidia.conf"
fi

# -----------------------------------------------------------------------------
# Set the initial GPU mode
# -----------------------------------------------------------------------------
apply_gpu_mode() {
  local mode="$1"
  if ! have envycontrol; then
    warn "cannot set GPU mode to '$mode': envycontrol is not installed"
    return 0
  fi
  case "$mode" in
    integrated|hybrid|nvidia) ;;
    *) warn "unknown LOQ_GPU_MODE '$mode'; expected integrated|hybrid|nvidia"; return 0 ;;
  esac

  if [[ "$(id -u)" -eq 0 ]]; then
    # Integrated mode cannot drive the HDMI/DP outputs on this chassis; they are
    # wired to the dGPU. Say so before switching.
    if [[ "$mode" == "integrated" ]]; then
      note "integrated mode: external monitors will be dark on this laptop (outputs are dGPU-wired)"
    fi
    run envycontrol -s "$mode" || warn "envycontrol -s $mode failed"
    ok "GPU mode set to $mode"
  fi
}

case "${LOQ_GPU_MODE}" in
  hybrid)
    # The safe default. External monitors and the internal panel both work.
    apply_gpu_mode hybrid
    ;;
  integrated|nvidia)
    warn "LOQ_GPU_MODE=$LOQ_GPU_MODE is applied now but will be re-applied on every boot only if"
    warn "  envycontrol's systemd unit is enabled. Verify with: envycontrol -g"
    apply_gpu_mode "$LOQ_GPU_MODE"
    ;;
  *)
    die "LOQ_GPU_MODE must be integrated, hybrid or nvidia (got '$LOQ_GPU_MODE')"
    ;;
esac

# -----------------------------------------------------------------------------
# Rebuild so the new module options are in the running image. Needed even
# without a kernel change because /etc/mkinitcpio.conf.d/nvidia.conf is new.
# -----------------------------------------------------------------------------
say "rebuilding the initramfs with the NVIDIA module options"
run mkinitcpio -P
ok "initramfs rebuilt"

# -----------------------------------------------------------------------------
# Verification
# -----------------------------------------------------------------------------
report_module() {
  local mod="$1"
  if modinfo -k "$(uname -r)" "$mod" >/dev/null 2>&1; then
    ok "$mod is present for $(uname -r)"
  else
    warn "$mod is not present for $(uname -r); run 'sudo mkinitcpio -P' and reboot"
  fi
}
report_module nvidia
report_module nvidia_drm

if [[ -r /sys/module/nvidia_drm/parameters/modeset ]]; then
  modeset="$(cat /sys/module/nvidia_drm/parameters/modeset)"
  if [[ "$modeset" == "Y" ]]; then
    ok "nvidia_drm modeset=Y"
  else
    warn "nvidia_drm modeset=$modeset (expected Y)"
  fi
fi

summary_line "02: nvidia-open-dkms, envycontrol, GPU mode ${LOQ_GPU_MODE}"
marker_set 02_gpu_nvidia
ok "02 NVIDIA graphics complete"