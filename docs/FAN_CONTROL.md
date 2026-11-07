# Fan control

Owner: `install-scripts/app/03_power.sh` (installs and configures),
`config/legiond/legiond.ini` (the configuration).
Flag: `LOQ_ENABLE_LEGIOND`, plus `LOQ_BATTERY_CHARGE_START` /
`LOQ_BATTERY_CHARGE_END` for charge thresholds.

---

## 1. LOQ 17IRX10 support is unverified

**Say this first, because it is the thing most likely to disappoint you.**
upstream does not guarantee support for this chassis. `legiond` is an AUR
package built against a table of Legion models, and the Lenovo LOQ line is not
in the set it was written against.

What happens on an unsupported model: the daemon starts, runs, and reports no
controllable hardware. It does not fail. That is why `03_power.sh` treats it as
a degradation rather than an error:

```bash
warn "legiond did not start; check: journalctl -u legiond"
```

and, when the package cannot be built at all:

```bash
warn "legiond unavailable; fan control stays with thermald and the firmware defaults"
svc_enable thermald
marker_set 03_power_no_legiond
```

Nothing else in the install depends on it. If legiond turns out to control
nothing on your machine, you have lost nothing that was previously working —
the firmware's own fan curve and `thermald`'s trip points remain authoritative,
and that is what runs.

### Check whether it actually did anything

```bash
systemctl status legiond --no-pager
journalctl -u legiond -b --no-pager
legionctl
```

What you are looking for:

- `systemctl is-active legiond` returning `active` means the daemon is running.
  It does **not** mean it controls fans.
- `journalctl -u legiond` reporting an unknown model, an unsupported
  embedded controller, or zero fan devices means it is a no-op on this machine.
- `legionctl` listing fan devices it can write to is the actual confirmation.
  An empty list, or a `fan_curve get` that errors, means no EC control.

```bash
# Does the daemon see this model?
journalctl -u legiond -b | grep -iE 'model|lenovo|unsupported|unknown'

# What can it actually write?
legionctl fan get
legionctl get
```

If the answer is "nothing", the honest outcome is: no custom fan curves, and the
fan behaviour you get is the firmware's, plus `thermald` enforcing trip points
so the CPU throttles before it damages itself. Set `LOQ_ENABLE_LEGIOND=0` and
move on rather than leaving a service running that controls nothing.

---

## 2. legiond's scope vs PPD's

Different layers of the machine, different knobs:

| | legiond | power-profiles-daemon |
|---|---------|------------------------|
| Layer | EC (embedded controller) | kernel cpufreq / P-state |
| Writes | fan RPM, PL1/PL2 power limits, charge thresholds, Fn+Q mode | scaling governor, energy performance preference |
| Path | `/etc/legiond.conf`, D-Bus via `legionctl` | `powerprofilesctl` |
| Physically | the firmware's fan controller and the EC's registers | `/sys/devices/system/cpu/cpu*/cpufreq/*` |

They are complementary, not competing — which is why both can be enabled.
`power-profiles-daemon` decides how aggressively the CPU boosts; legiond decides
what the fans do about it. The one place they could collide is the platform
power profile, and `power_hint_mode` in `legiond.ini` is the setting that keeps
them out of each other's way:

```ini
power_hint_mode = auto
```

The comment in the file states the intent: PPD owns cpufreq, and both writing it
is what made power behaviour unreproducible. **See
[POWER_MANAGEMENT.md](POWER_MANAGEMENT.md) §1 for the full ownership table.**

---

## 3. `config/legiond/legiond.ini`

Installed to `/etc/legiond.conf`, mode `0644`, by `03_power.sh`.

```ini
[loq]
trip_points = 90,95,100
fan_curve = 40:0, 50:10, 60:25, 70:45, 80:70, 90:100
fan_curve_discrete = 40:0, 50:15, 60:35, 70:55, 80:80, 90:100
battery_charge_limit = 80
battery_charge_start_threshold = 75
performance_mode = balanced
power_hint_mode = auto
```

### `fan_curve` syntax

```
upper_temp:speed, upper_temp:speed, ...
```

- `upper_temp` — degrees Celsius.
- `speed` — percentage of maximum fan duty, 0 to 100.

**`upper_temp` is an upper bound, not an exact match.** The daemon picks the
last entry whose `upper_temp` is less than or equal to the current temperature.
At 55 °C with the curve above, the entry `50:10` applies: 10 % duty. At 49 °C
the `40:0` entry applies and the fan idles. It is a step function with
interpolation between steps in most implementations, but do not depend on the
interpolation — design the curve so the behaviour is the same either way.

Two curves are defined: `fan_curve` for continuously variable fans and
`fan_curve_discrete` for machines whose fans only have fixed speed steps. On a
17-inch LOQ with a single fan the two should be close; they are both present
because the chassis revision matters and this has not been confirmed on the
hardware.

The shipped curve reaches 100 % at 90 °C, below the first trip point of 90 °C,
so the fans are at maximum before the firmware starts pulling power. That is the
intended relationship: fans are cheaper than throttling.

### `trip_points`

```ini
trip_points = 90,95,100
```

Kept at the platform defaults deliberately. On a thin chassis, pushing the trip
points lower moves the throttling point rather than making the machine cooler —
the same heat is produced, it is just removed at a lower frequency and lower
voltage, with a worse noise profile. Raise them only if you are deliberately
running a thermal stress test.

### `battery_charge_limit` and `battery_charge_start_threshold`

```ini
battery_charge_limit = 80
battery_charge_start_threshold = 75
```

The EC path. `03_power.sh` also offers to set the same values through `upower`,
which is the systemd path. Both write the same firmware register; setting one
overrides the other, which is expected. Source values are
`LOQ_BATTERY_CHARGE_START` and `LOQ_BATTERY_CHARGE_END`.

Keeping the charge ceiling at 80 % and starting at 75 % is the part of this
setup that most extends battery life: a laptop kept at 100 % on the charger
degrades its cells faster than any power-management setting affects it.

### `performance_mode`

```ini
performance_mode = balanced
```

Fn+Q cycles `quiet`, `balanced`, `performance`, `custom`. Note that this is the
EC's own mode register and it interacts with the firmware's power limits. It is
**not** the same as the PPD profile. Keep PPD on `balanced` and leave this at
`balanced` unless you have a reason.

---

## 4. Unverified keys — flagging honestly

Two keys in `legiond.ini` are **upstream keys whose support this repository has
not verified**:

| Key | Status |
|-----|--------|
| `trip_points` | Present in the file. Whether this upstream build accepts the key name in a user section on this chassis is unverified — no daemon has been run against this hardware from this repo. |
| `power_hint_mode` | Present in the file. Its exact accepted values, and whether `auto` means "adopt the platform profile" (which would be exactly the conflict this is meant to avoid) rather than "do not touch it", is unverified. |

Neither key is required for fans to work. If the daemon refuses to parse the
config or logs an unknown-key warning, remove them one at a time and restart:

```bash
sudo cp /etc/legiond.conf /etc/legiond.conf.bak
sudo systemctl restart legiond
journalctl -u legiond -b --no-pager | tail -20
```

The verification ladder for this is the same for both: does the daemon start, does
it report the model, and does `legionctl` see the hardware. Nothing in this repo
can answer that without the machine.

---

## 5. Charge thresholds without legiond

They do not need legiond. `upower` sets the same firmware register:

```bash
upower -e
upower -i "$(upower -e | head -1)" set-charge-threshold 75 80
upower -i "$(upower -e | head -1)" get
```

If no battery is reported, `03_power.sh` leaves the thresholds to the firmware
and says so. Lenovo's BIOS exposes them too.

---

## 6. Verification

```bash
# Is the daemon running, and does it know this machine?
systemctl is-active legiond
journalctl -u legiond -b --no-pager

# What can it write?
legionctl get
legionctl fan get

# The curve actually in force
grep -E 'fan_curve|trip_points' /etc/legiond.conf

# Temperature and duty, live
for z in /sys/class/thermal/thermal_zone*; do
  printf '%s %s C\n' "$(cat "$z"/type 2>/dev/null)" "$(awk '{print $1/1000}' "$z"/temp 2>/dev/null)"
done
```

---

## 7. Related

- [POWER_MANAGEMENT.md](POWER_MANAGEMENT.md) — the other two daemons and why
  TLP was removed
- [CPU_TUNING.md](CPU_TUNING.md) — undervolt; a cooler-running CPU needs less fan
- [GPU_SETUP.md](GPU_SETUP.md) — dGPU power state, which changes the thermal picture