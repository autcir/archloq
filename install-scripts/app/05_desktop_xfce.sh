#!/usr/bin/env bash
# =============================================================================
# 05 — Xfce desktop
# =============================================================================
# Xfce 4.20 on X11. The window manager is xfwm4 with its own built-in
# compositor; there is no picom. Display manager is configurable because
# envycontrol documents support for both SDDM and LightDM.
# =============================================================================

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/utils.sh
source "$SCRIPT_DIR/../lib/utils.sh"

require_root
require_config
init_dirs

say "== 05 Xfce desktop =="

if ! enabled "${LOQ_ENABLE_DESKTOP:-1}"; then
  skip "desktop disabled by config"
  marker_set 05_desktop_xfce
  exit 0
fi

# -----------------------------------------------------------------------------
# Packages
#
# xfce4-goodies is deliberately absent: it drags in gigolo, extra gvfs helpers
# and a second terminal, none of which this setup uses.
# -----------------------------------------------------------------------------
pkg_install \
  xfce4 xfce4-panel xfwm4 xfdesktop thunar xfce4-session xfce4-settings xfconf \
  xfce4-appfinder xfce4-notifyd xfce4-screensaver xfce4-power-manager \
  xfce4-clipman-plugin xfce4-whiskermenu-plugin xfce4-docklike-plugin \
  xfce4-screenshooter xfce4-pulseaudio-plugin xfce4-terminal mousepad \
  xfce4-panel-profiles xfce4-xkb-plugin \
  xorg-server xorg-xinit xorg-apps \
  pipewire pipewire-pulse pipewire-alsa pipewire-jack wireplumber pavucontrol \
  gnome-keyring lxsession \
  xbindkeys xdotool wmctrl \
  papirus-icon-theme adwaita-icon-theme \
  ttf-jetbrains-mono-nerd inter-font noto-fonts \
  unzip curl git

pkg_install "${LOQ_TERMINAL}"

# The terminal must actually exist; a typo in loq.conf should fail loudly here
# rather than at first login.
if ! have "$LOQ_TERMINAL"; then
  warn "$LOQ_TERMINAL is not a valid terminal command. Check LOQ_TERMINAL in loq.conf."
  warn "installed alternatives: foot (default), alacritty, ghostty"
fi

cursor_pkg=""
for candidate in bibata-cursor bibata-cursor-classic; do
  if pacman -Si "$candidate" >/dev/null 2>&1; then
    cursor_pkg="$candidate"
    break
  fi
done
[[ -n "$cursor_pkg" ]] && pkg_install "$cursor_pkg"

# -----------------------------------------------------------------------------
# Display manager
# -----------------------------------------------------------------------------
configure_display_manager() {
  case "$LOQ_DISPLAY_MANAGER" in
    sddm)
      pkg_install sddm
      # envycontrol rewrites sddm's Xsetup script to inject the PRIME profile.
      ok "sddm installed"
      ;;
    lightdm)
      pkg_install lightdm lightdm-gtk-greeter
      ok "lightdm installed"
      ;;
    *)
      die "LOQ_DISPLAY_MANAGER must be sddm or lightdm (got '$LOQ_DISPLAY_MANAGER')"
      ;;
  esac

  # Only one DM may be enabled or they fight over the VT.
  local other
  for other in gdm lightdm sddm ly display-manager; do
    [[ "$other" == "$LOQ_DISPLAY_MANAGER" ]] && continue
    if systemctl is-enabled "$other.service" >/dev/null 2>&1; then
      warn "$other.service is enabled; disabling it"
      svc_disable "$other.service"
    fi
  done

  svc_enable "${LOQ_DISPLAY_MANAGER}.service"
  if ! systemctl is-enabled getty@tty2.service >/dev/null 2>&1; then
    svc_enable getty@tty2.service
  fi
}

configure_display_manager

# -----------------------------------------------------------------------------
# Autologin is off. The greeter is the only way in; see docs/SECRETS.md.
# SDDM uses /etc/sddm.conf.d/, LightDM uses /etc/lightdm/lightdm.conf.
# -----------------------------------------------------------------------------
for _conf in "/etc/$LOQ_DISPLAY_MANAGER.conf" /etc/sddm.conf.d/*.conf /etc/lightdm/lightdm.conf; do
  [[ -f "$_conf" ]] || continue
  if grep -qE '^\s*AutologinUser=' "$_conf"; then
    sed_idempotent "$_conf" 's/^\s*AutologinUser=.*/AutologinUser=/' \
      "disabled autologin in $_conf"
  fi
done

# -----------------------------------------------------------------------------
# User session prerequisites
# -----------------------------------------------------------------------------
if id "$LOQ_USERNAME" >/dev/null 2>&1; then
  target_home="$(getent passwd "$LOQ_USERNAME" | cut -d: -f6)"
  # shellcheck disable=SC2086  # LOQ_USER_GROUPS is an intentional word list
  usermod -aG $LOQ_USER_GROUPS "$LOQ_USERNAME"
  ok "groups for $LOQ_USERNAME: $LOQ_USER_GROUPS"

  # The Xfce session needs a readable ~/.Xauthority seed and a sane XDG setup.
  if [[ ! -f "$target_home/.Xauthority" ]]; then
    install -m 0600 -o "$LOQ_USERNAME" -g "$LOQ_USERNAME" /dev/null "$target_home/.Xauthority"
    note "created an empty $target_home/.Xauthority; it is repopulated at first login"
  fi

  # Session save: Xfce remembers window positions. Without this it also restores
  # crashed applications on the next login, which is rarely what you want.
  write_file "$target_home/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-session.xml" 0644 <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-session" version="1.0">
  <property name="general" type="empty">
    <property name="FailsafeSessionName" type="string" value="Failsafe"/>
    <property name="SaveOnExit" type="bool" value="true"/>
    <property name="AutoSave" type="bool" value="false"/>
  </property>
  <property name="shutdown" type="empty">
    <property name="ShowHibernate" type="bool" value="false"/>
    <property name="ShowHybridSleep" type="bool" value="false"/>
  </property>
</channel>
EOF
  chown -R "$LOQ_USERNAME:$LOQ_USERNAME" "$target_home/.config/xfce4" 2>/dev/null || true
else
  warn "user $LOQ_USERNAME does not exist; skipping session setup"
  warn "archinstall creates users from the --creds file. A missing user there means"
  warn "no unprivileged account was created at all -- see archinstall/README.md"
fi

# -----------------------------------------------------------------------------
# Kernel-mode mouse acceleration is not a thing on X11 Xorg; leave it alone.
# xfce4-screensaver handles the lock, xfce4-power-manager the idle policy.
# -----------------------------------------------------------------------------
pkg_install xfce4-screensaver

summary_line "05: Xfce with $LOQ_DISPLAY_MANAGER, theme $LOQ_THEME, terminal $LOQ_TERMINAL"
marker_set 05_desktop_xfce
ok "05 Xfce desktop complete"