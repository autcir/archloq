# Wi-Fi during installation

The Arch ISO has no saved networks. There is nothing to "reconnect" to — you
have to authenticate once, from the live environment, and the connection does
not carry into the installed system (which brings its own NetworkManager
configuration).

---

## 1. On the Lenovo LOQ 17IRX10 specifically

The wireless chipset is an Intel AX211 or similar, and the ISO's kernel has the
`iwlwifi` driver built in. Nothing extra to install.

Verify the radio is visible **before** you start fighting with anything else:

```bash
ip -br link                       # wlan0 should be listed, or wlp*
rfkill list                       # if Soft blocked: sudo rfkill unblock wifi
```

If `wlan0` does not exist at all, the driver did not bind:

```bash
sudo modprobe iwlwifi
dmesg | grep -iE 'iwlwifi|firmware' | tail -20
```

`dmesg` will tell you exactly which firmware is missing if that is the problem.

---

## 2. Three ways, in order of preference

### `wifi-menu` (ncurses, ships with the ISO)

The easiest path, and the one to try first.

```bash
wifi-menu
```

Arrow to your network, Enter, type the passphrase, Enter again. The status line
at the bottom turns green when you have an address. `Esc` leaves without saving.

**If the list is empty:** `wifi-menu` can only see networks that are currently
beaconing. Move closer to the router, or see §4.

### `iwctl` (iwd, ships with the ISO)

More reliable, and the same stack the installed system will use.

```bash
iwctl
[iwd]# device list
[iwd]# station wlan0 scan
[iwd]# station wlan0 get-networks
[iwd]# station wlan0 connect "YOUR-SSID"
# enter the passphrase when prompted
[iwd]# station wlan0 show
[iwd]# quit
```

Confirm you actually have an address — being "connected" to an AP is not the
same as having working DNS:

```bash
ip -br addr show wlan0
ping -c3 archlinux.org
```

### `wpa_supplicant` (when iwd misbehaves)

```bash
# NetworkManager's CLI can drive a connection without a running daemon.
nmcli dev wifi list
nmcli dev wifi connect "YOUR-SSID" password "YOUR-PASSPHRASE"

# Or the low-level tool, which always works:
cat >/etc/wpa_supplicant.conf <<'EOF'
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=wheel
update_config=1
network={
  ssid="YOUR-SSID"
  psk="YOUR-PASSPHRASE"
  key_mgmt=WPA-PSK
}
EOF

wpa_supplicant -B -i wlan0 -c /etc/wpa_supplicant.conf
dhcpcd wlan0          # or: udhcpc -i wlan0
```

Replace `dhcpcd` with `udhcpc` if `dhcpcd` is not in the ISO.

---

## 3. Keeping the connection after the install

**Do not expect the live connection to survive.** It is bound to the running
ISO. The installed system gets a fresh NetworkManager with no saved networks.

Two options, and the second is better:

### Let NetworkManager find the network at first boot

Nothing to do. `install-scripts/app/05_desktop_xfce.sh` enables
`NetworkManager.service`, and the Xfce applet will list networks. Pick yours
from the panel once the desktop is up.

### Pre-seed the profile (no password typed twice, no typo under pressure)

Write the connection file into the target's config before unmounting, then type
the passphrase **once** on the first boot. The password is never written to disk
in the clear and never appears in a shell history.

```bash
# From the ISO, with the target mounted at /mnt and the user home in place:
mkdir -p "/mnt/etc/NetworkManager/system-connections"
chmod 700 "/mnt/etc/NetworkManager/system-connections"

cat >"/mnt/etc/NetworkManager/system-connections/wifi.nmconnection" <<'EOF'
[connection]
id=Wifi
type=wifi
interface-name=wlan0

[wifi]
mode=infrastructure
ssid=YOUR-SSID

[ipv4]
method=auto

[ipv6]
method=auto

[proxy]
EOF

chmod 600 "/mnt/etc/NetworkManager/system-connections/wifi.nmconnection"
chown "$USER:$USER" "/mnt/etc/NetworkManager/system-connections/wifi.nmconnection"
```

Omit the `psk` key entirely and NetworkManager will prompt for the passphrase on
first connection. Including it inline would store the key in a world-readable-
to-root file that a plain `cat` would expose; on a laptop that is a worse trade
than typing it once.

---

## 4. When the network list is empty

In order of likelihood:

1. **The router only broadcasts on 5 GHz and the ISO's driver is unhappy with it.**
   Test from a phone hotspot on 2.4 GHz.
2. **The router has a hidden SSID.** `iwctl` can still join it:
   ```bash
   [iwd]# station wlan0 connect "HiddenSSID"
   ```
3. **802.11r/k (fast roaming) is on.** Some access points with these enabled
   hide themselves from station scans entirely. Temporarily disable them in the
   router UI.
4. **MAC filtering.** Should be visible to a scan regardless; if not, it is not
   MAC filtering.
5. **`rfkill` says hard blocked.** Some laptops ship with the radio hard-blocked
   and a physical switch or a BIOS setting:
   ```bash
   rfkill list
   sudo rfkill unblock all
   # if it goes straight back to blocked, it is the BIOS or a hardware switch
   ```

---

## 5. Ethernet is fine

If you have a USB-C gigabit adapter or a spare cable, skip all of this. Plugged
in, the ISO's `systemd-networkd` usually comes up on its own. Verify with
`ip -br addr`; if only `lo` and the USB interface show no address:

```bash
sudo dhcpcd enp0s20u1     # substitute your interface name
```

---

## 6. Doing the whole thing offline

Every Arch ISO carries the base packages needed for a working system, and the
live environment has enough tooling to partition and format:

```bash
pacstrap -K /mnt base linux-zen linux-zen-headers linux-firmware intel-ucode \
                btrfs-progs cryptsetup efibootmgr git
```

What you **cannot** do offline, and should plan for:

| Task | Needs the network | Why |
|------|-------------------|-----|
| `install-scripts/` (`pacmaster.sh`) | yes — every `pacman -S` | AUR helper, Xfce, NVIDIA, borg |
| `envycontrol`, `legiond` | yes — AUR | not in `extra` |
| `gpu` verification (`nvidia-smi`) | no | already installed by then |
| root + `linux-zen` + LUKS + boot | no | on the ISO |

So: offline gets you a bootable minimal system and a working keyboard and
network stack. Everything above that wants the internet. The practical version
of "offline" is to get to a booting system without it, then connect once you
have a working display manager and finish with `pacmaster.sh --resume`.