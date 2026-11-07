# Power management

Owner: `install-scripts/app/03_power.sh`. Flags: `config/loq.conf`
(`LOQ_POWER_PROFILES`, `LOQ_DEFAULT_POWER_PROFILE`, `LOQ_ENABLE_LEGIOND`,
`LOQ_BATTERY_CHARGE_START`, `LOQ_BATTERY_CHARGE_END`).

Three daemons, three disjoint sets of knobs. Exactly one of them writes each
knob. That is the whole design, and it is the reason TLP is gone.

---

## 1. Ownership split

| Daemon | Owns | Interface | Does not touch |
|--------|------|-----------|----------------|
| `power-profiles-daemon` | `/sys/devices/system/cpu/cpu*/cpufreq/*` (scaling governor, energy performance preference), AMD P-state / `intel_pstate` policy, GPU runtime PM policy | `powerprofilesctl` (D-Bus) | temperature, voltages, fans |
| `thermald` | undervolt offsets, CPU temperature trip points | `/etc/thermald.conf`, the MSRs behind `intel-undervolt` | cpufreq policy, fans |
| `legiond` | EC-level hardware: fan curves, charge thresholds, PL1/PL2 power limit, Fn+Q performance mode | `/etc/legiond.conf`, `legionctl` | cpufreq governor |

`power-profiles-daemon` is also the interface **envycontrol** uses when it
switches GPU mode, so a second tool changing cpufreq policy behind its back
breaks both. See [GPU_SETUP.md](GPU_SETUP.md).

`legiond` is scoped separately — see [FAN_CONTROL.md](FAN_CONTROL.md). Its
`power_hint_mode` in `config/legiond/legiond.ini` exists precisely to stop the
daemon from grabbing the platform power profile PPD owns.

---

## 2. Why TLP was removed

The previous archloq configuration enabled `tlp`, `power-profiles-daemon`,
`thermald` and `legiond` at the same time. TLP and PPD write the **same**
kernel knobs: the scaling governor, the energy performance preference, the
`intel_pstate` policy, and the runtime-PM/autosuspend settings. Both daemons
apply their configuration at boot and again on every AC/battery transition.

The result was that the effective configuration was decided by startup order
and by whichever transition fired last. It was not reproducible, and it changed
between reboots on the same machine.

`03_power.sh` now actively removes it:

```bash
for pkg in tlp tlp-rdw; do
  pacman -Qq "$pkg" >/dev/null 2>&1 && tlp_present=1
done
...
rm -f /etc/tlp.conf
```

and `90_postinstall.sh` treats an installed `tlp` or `tlp-rdw` as a blocking
problem, so it cannot come back silently.

### What was deleted along with TLP

These were TLP wrappers. Each one invoked `tlp-stat`, `tlpstart` or
`tlp-setcpu`, so none of them had any meaning once TLP was gone:

| Deleted | Reason |
|---------|--------|
| `scripts/loq-mode` | profile switcher over `tlp-stat -s` |
| `scripts/loq-power-apply` | applied a `loq.conf` profile via `tlp-setcpu` |
| `scripts/loq-power-diag` | reported `tlp-stat` output |
| `scripts/loq-definitive-power.sh` | combined all three into one entrypoint |

They are not replaced by equivalents because the functionality they wrapped is
TLP's. The replacement is:

```bash
powerprofilesctl set power-saver
powerprofilesctl set balanced
powerprofilesctl set performance
```

---

## 3. Why not `auto-power-profiles-daemon`

`auto-power-profiles-daemon` switches PPD's profile based on AC state,
battery level and (optionally) applications. That sounds like a convenience and
is, but it puts a second policy writer on top of PPD: it decides the profile
without the operator doing it, and its rules (charge-threshold mode, thermal
mode) are TLP's idea of power management wearing a different name.

Three policies that can each rewrite the governor are exactly the failure mode
this setup removed. If you want profile switching, do it explicitly:

```bash
# On the charger
powerprofilesctl set performance

# Unplugging
powerprofilesctl set balanced
```

If you want it automatic, put it in one place you can see and edit — a
`systemd --user` unit, or a udev rule — rather than in a second daemon whose
interaction with PPD is documented as best-effort.

---

## 4. What `03_power.sh` installs

```
power-profiles-daemon   PPD itself
thermald                undervolt + trip points
legiond                 AUR, only if LOQ_ENABLE_LEGIOND=1
python-pydbus           D-Bus binding legionctl needs
light                   panel brightness
```

`/etc/legiond.conf` is written from `config/legiond/legiond.ini` when legiond
is present. It is skipped, with a warning rather than a failure, when the model
is unsupported — see [FAN_CONTROL.md](FAN_CONTROL.md).

Charge thresholds are applied with `upower`:

```bash
upower -i "$(upower -e | head -1)" set-charge-threshold 75 80
```

If no battery is found through `upower`, the script leaves the thresholds to
the firmware and says so. It does not fail.

---

## 5. Verification

```bash
# Which profile is active, and what is available
powerprofilesctl list
powerprofilesctl get

# Exactly one cpufreq owner
systemctl is-enabled power-profiles-daemon thermald

# TLP must not be installed
pacman -Q tlp tlp-rdw 2>&1 | grep -c 'is not installed'

# Confirm PPD is the only thing writing the governor
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
grep -r . /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference
```

Expected after a clean install:

```
$ powerprofilesctl get
balanced
$ pacman -Q tlp
error: package 'tlp' was not found
```

### Prove ownership instead of assuming it

Change the profile and watch the knob move:

```bash
powerprofilesctl set performance
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
# expect: performance

powerprofilesctl set balanced
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
# expect: schedutil or powersave, depending on intel_pstate
```

If the governor does not change, something else is writing it. That is the bug
this split exists to make visible.

---

## 6. Troubleshooting

| Symptom | Check |
|---------|-------|
| Governor does not follow `powerprofilesctl set` | `pacman -Q tlp tlp-rdw`; is a power-profile switcher service enabled? |
| Profile reverts after unplugging | something with a udev AC rule is also writing it |
| `powerprofilesctl` reports no profiles | PPD is not started, or the driver is not `intel_pstate`/`amd-pstate`: `ls /sys/devices/system/cpu/intel_pstate` |
| Fans stay at maximum with no load | not a power problem — see [FAN_CONTROL.md](FAN_CONTROL.md) |
| Undervolt missing after suspend | see [CPU_TUNING.md](CPU_TUNING.md) §5 |

---

## 7. Related

- [FAN_CONTROL.md](FAN_CONTROL.md) — legiond's EC-level scope
- [CPU_TUNING.md](CPU_TUNING.md) — undervolt ownership and diagnostics
- [GPU_SETUP.md](GPU_SETUP.md) — envycontrol, which depends on PPD being the
  only cpufreq writer
- [REFORMAT-XFCE.md §9](REFORMAT-XFCE.md) — the decision this implements