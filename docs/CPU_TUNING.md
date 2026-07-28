# CPU Tuning

## Intel Undervolt

### Install

```bash
yay -S intel-undervolt
```

### Configuration

File: `/etc/intel-undervolt.conf`

```bash
# i7-13700HX undervolt values (mV)
undervolt 0 "Core" -100
undervolt 1 "Uncore" -80
undervolt 2 "Cache" -80
undervolt 3 "System Agent" -50
undervolt 4 "Analog I/O" -50

# Power limits (mW)
power package 15000 25000  # short long
power core 15000 25000

# Temperature offset (°C below Tjmax)
tjoffset -10

# HWP hints
hwp 0 1  # P-cores perf hint
hwp 1 1  # E-cores perf hint
```

### Enable

```bash
sudo systemctl enable --now intel-undervolt
```

### Check Status

```bash
intel-undervolt status
```

---

## P-State Tuning

### intel-pstate-states

Diagnostic tool for Hardware-managed P-States.

```bash
# Install
cd runtime/intel-pstate-states
cargo build --release

# Run diagnostics
sudo ./intel-pstate-states
```

### Governors

| Governor | Use Case |
|----------|----------|
| `schedutil` | Default, good balance |
| `performance` | Maximum performance |
| `powersave` | Minimum power |

### EPP (Energy Performance Preference)

| Value | Description |
|-------|-------------|
| `performance` | Highest performance, lowest power savings |
| `balance_performance` | Balanced |
| `balance_power` | More power savings, some performance |
| `power` | Lowest power, highest power savings |

### Check Current State

```bash
# Check governor
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor

# Check EPP
cat /sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference
```

---

## Thermal Management

### thermald

```bash
sudo pacman -S thermald
sudo systemctl enable --now thermald
```

### Check Thermal Throttling

```bash
# Check for throttling
cat /sys/devices/system/cpu/cpu*/thermal_throttle/core_throttle_count

# Intel P-state status
cat /sys/devices/system/cpu/intel_pstate/status
```

---

## Advanced: Custom Undervolt

### Find Safe Values

```bash
# Monitor temperatures during stress test
sudo pacman -S stress
stress-ng --cpu 20 --timeout 60s

# Gradually increase undervolt
# Start with -50mV, increase by -10mV
# Monitor stability and temperatures
```

### Reset to Defaults

```bash
# Reset undervolt
sudo intel-undervolt reset

# Or restore backup
sudo cp /etc/intel-undervolt.conf.backup /etc/intel-undervolt.conf
```

---

## Troubleshooting

### Undervolt Not Applied

```bash
# Check service status
systemctl status intel-undervolt

# Check MSRs
sudo rdmsr 0x150  # MSR_IA32_THERM_STATUS

# Check BIOS settings
# Disable " overclock" or "Enhanced Turbo"
```

### System Unstable

```bash
# Reduce undervolt values
# -50mV instead of -100mV

# Check for errors in logs
journalctl -u intel-undervolt
```