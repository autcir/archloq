# Fan Control

## Overview

LOQ supports three methods for fan control:

1. **legiond** - Daemon with automatic profiles
2. **loq-control** - GUI with real-time monitoring
3. **Manual** - Custom fan curves

---

## legiond

### Install

```bash
yay -S legiond
yay -S lenovolegionlinux-git
```

### Enable

```bash
sudo systemctl enable --now legiond
```

### Features

- Automatic fan profile switching
- Based on power profile (Quiet/Balanced/Performance)
- CPU/GPU temperature monitoring
- Safe defaults (EC/BIOS handles critical temps)

### Configuration

File: `config/legion_linux/legiond.ini`

```ini
[core]
fan_control = false  # Safety: let BIOS handle critical temps
cpu_control = false
gpu_control = false  # nvidia-smi path broken
```

### Status

```bash
systemctl status legiond
legiond status
```

---

## loq-control (GUI)

### Install

```bash
cd runtime/loq-control
pip install -r requirements.txt
```

### Features

- Real-time CPU/GPU/RAM monitoring
- Per-core temperature heatmap
- Temperature history graphs
- Thermal throttle detection
- Performance profiles
- Keyboard backlight control

### Requirements

- `legion_laptop` kernel module
- `ideapad_acpi` module

### Run

```bash
python main.py
```

---

## Custom Fan Curves

### Using legion_laptop

```bash
# Check available fan points
cat /sys/devices/platform/legion_laptop/fan_curve

# Set custom curve (10 points)
echo "40 0 55 30 65 60 75 90 85 100" > /sys/devices/platform/legion_laptop/fan_curve
```

### Recommended Curve

```
Point 0: 40°C  0%
Point 1: 55°C  30%
Point 2: 65°C  60%
Point 3: 75°C  90%
Point 4: 85°C  100%
```

### Fan Curve Script

```bash
#!/bin/bash
# /usr/local/bin/loq-fan-curve

set_fan_curve() {
    local curve="$1"
    echo "$curve" > /sys/devices/platform/legion_laptop/fan_curve
}

# Quiet profile
set_fan_curve "40 0 55 20 65 40 75 70 85 100"

# Performance profile
set_fan_curve "40 30 55 60 65 80 75 95 85 100"
```

---

## Diagnostics

### Check Temperatures

```bash
# CPU
sensors
cat /sys/class/thermal/thermal_zone*/temp

# GPU
nvidia-smi -q -d TEMPERATURE

# Fan speed
cat /sys/devices/platform/legion_laptop/fan_speed
```

### Check Throttling

```bash
# CPU throttling
cat /sys/devices/system/cpu/cpu*/thermal_throttle/core_throttle_count

# GPU throttling
nvidia-smi -q -d POWER
```

---

## Troubleshooting

### legion_laptop Not Loading

```bash
# Check BIOS
# Enable "Lenovo Vantage" in BIOS

# Force load
sudo modprobe legion_laptop force=1

# Make permanent
echo "legion_laptop" | sudo tee /etc/modules-load.d/legion_laptop.conf
```

### legiond Not Working

```bash
# Check if module loaded
lsmod | grep legion

# Check logs
journalctl -u legiond

# Restart
sudo systemctl restart legiond
```

### Fan Stuck on Max

```bash
# Check BIOS settings
# "Fan Control Mode" should be "Auto"

# Reset fan curve
echo "default" > /sys/devices/platform/legion_laptop/fan_curve
```