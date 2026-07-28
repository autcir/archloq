# Power Management

## Overview

LOQ uses a three-layer power management stack:

1. **TLP** - Base power management
2. **legion_linux** - WMI hardware control
3. **loq-mode** - User profile switching

---

## TLP Configuration

### Install

```bash
sudo pacman -S tlp tlp-rdw
yay -S thermald
```

### Configuration

File: `config/tlp.d/lenovo-loq.conf`

```bash
# CPU scaling
CPU_SCALING_GOVERNOR_ON_AC=performance
CPU_SCALING_GOVERNOR_ON_BAT=powersave
CPU_MAX_PERF_ON_AC=100
CPU_MAX_PERF_ON_BAT=45

# Platform profile
PLATFORM_PROFILE_ON_AC=balanced-performance
PLATFORM_PROFILE_ON_BAT=quiet

# GPU runtime PM
RUNTIME_PM_ON_AC=auto
RUNTIME_PM_ON_BAT=auto
RUNTIME_PM_DENYLIST="0x01:00.0 0x01:00.1"

# WiFi power
WIFI_PWR_ON_AC=off
WIFI_PWR_ON_BAT=on

# USB autosuspend
USB_AUTOSUSPEND=0  # Mouse regression fix
```

### Apply

```bash
sudo tlp start
tlp-stat -b  # Check battery mode
```

---

## legion_linux

### Install

```bash
yay -S lenovolegionlinux-git
yay -S legiond
```

### Features

- Power mode switching (Quiet/Balanced/Performance)
- Battery conservation mode
- Rapid charging control
- FN lock
- Touchpad toggle
- Display overdrive

### Configuration

File: `config/legion_linux/legiond.ini`

```ini
[core]
fan_control = false  # EC/BIOS handles fans

[cpu]
control = false

[gpu]
control = false  # nvidia-smi path broken
```

### Enable

```bash
sudo systemctl enable --now legiond
```

---

## loq-mode Profiles

### Profiles

| Profile | Turbo | CPU % | GPU | WiFi | Notes |
|---------|-------|-------|-----|------|-------|
| battery | off | 45% | quiet | powersave | Long_Life charge |
| work | on | 70% | balanced | default | |
| performance | on | 100% | performance | default | |
| battery-safe-apps | off | 45% | intel-only | powersave | No NVIDIA |

### Usage

```bash
# Switch profiles
loq-mode battery
loq-mode work
loq-mode performance

# Auto-switch on AC/battery
systemctl start loq-power-apply.service
```

### Power Mode WMI Values

- 1 = Quiet (fan curve 0)
- 2 = Balanced (fan curve 1)
- 3 = Performance (fan curve 2)

---

## Diagnostics

```bash
# Check power status
loq-power-diag

# Check TLP status
tlp-stat -b

# Check legiond
legiond status
```

---

## Troubleshooting

### TLP Not Working

```bash
systemctl status tlp
tlp-stat -b
```

### legion_laptop Module Not Loading

```bash
# Check BIOS settings
# Enable "Lenovo Vantage" or similar

# Force load
sudo modprobe legion_laptop force=1
```

### Power Mode Not Changing

```bash
# Check WMI
ls /sys/devices/platform/legion_laptop/

# Manual write
echo 1 > /sys/devices/platform/legion_laptop/power_mode
```