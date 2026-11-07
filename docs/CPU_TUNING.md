# CPU tuning — the undervolt

Owner: `install-scripts/app/04_cpu_undervolt.sh` (install) and
`manage/loq-uv-diagnose.sh` (validate). Flags: `LOQ_ENABLE_UNDERVOLT`,
`LOQ_UNDERVOLT_CORE`, `LOQ_UNDERVOLT_UNCORE`, `LOQ_UNDERVOLT_CACHE`,
`LOQ_UNDERVOLT_SA`, `LOQ_UNDERVOLT_IO`, `LOQ_UNDERVOLT_SIGNATURE`.

**Stock Raptor Lake does not need an undervolt.** The i7-13700HX runs at its
intended frequency on its default PL1/PL2 limits. What an undervolt buys is a
little efficiency margin at the top of the boost curve, in exchange for
silently-corrupting work if you get it wrong. That trade is only acceptable with
a conservative offset and a test that would notice.

---

## 1. What each domain is

`intel-undervolt` writes one offset per voltage domain. They are not
interchangeable: they cover different silicon, and a value that is fine on one
rail can be unstable on another.

| Domain | Silicon | What it affects on Raptor Lake | Symptom when too far |
|--------|---------|--------------------------------|----------------------|
| `core` | the Vccxin/Vccxout rail feeding every core, P and E | Absolute core voltage at any frequency. The largest lever and the one that buys the most power | Computations return wrong answers; WHEA-Logger reports a processor error |
| `uncore` | the System Agent-adjacent ring, iGPU block, media engine, PCIe, SATA | Throughput of iGPU compute, NVMe and network latency, video encode. Also the ring interconnect | iGPU glitches, dropped PCIe packets, media decode artifacts, machine check |
| `cache` | the LLC voltage domain | L3 hit latency and frequency. Contended cache-heavy code degrades first | High cache-miss latency, machine check under memory-bound load |
| `sa` | System Agent — the fabric between cores, cache, iGPU and memory controller | Memory and fabric stability. This one is the least forgiving on mobile parts because the memory controller shares it | Memory errors, WHEA-Logger bus errors, idle-state instability |
| `i/o` | the I/O ring: PCIe, SATA, USB controllers | PCIe link training, power-state transitions. Matters more here because the dGPU and NVMe both live behind it | Link dropping to a lower speed, GPU losing the bus after suspend |

The domains interact. A large negative `uncore` offset raises the risk that the
SA/IO domain droops under load that is heavy on one and light on the other.
That is why the diagnostics halve a domain at a time rather than moving all
five together.

---

## 2. Why the old values were too aggressive

The previous `loq.conf` shipped:

```
core -100   uncore -80   cache -80   sa -50   io -50
```

On 13th gen these are beyond what is reliably stable, and the way they fail is
the reason this document exists: **not a crash**. A too-deep core offset does not
produce a kernel panic or an MCE you can see. It produces a computation that
returns a wrong answer. In a compiler, a checksum mismatch hours later. In a
crypto library, a failure under load. In a database, a corrupted page. The
damage is discovered in whatever was running, long after the machine booted with
a perfectly healthy-looking `dmesg`.

Undervolting also interacts with `Raptor Lake`'s own behaviour: the Vmin curve
shifts per silicon lottery, so `-100 mV` may be free on one 13700HX and
corrupting work on the next, with nothing in the firmware telling you which one
you have.

The values now shipped:

| Domain | Old | New |
|--------|-----|-----|
| `core` | -100 | **-60** |
| `uncore` | -80 | **-40** |
| `cache` | -80 | **-30** |
| `sa` | -50 | **-20** |
| `io` | -50 | **-20** |

Roughly half on every domain, and much less on `sa` and `i/o`, which are the two
where the failure mode is worst and the gain is smallest.

---

## 3. `manage/loq-uv-diagnose.sh`

```bash
sudo manage/loq-uv-diagnose.sh                 # 45 minute run
sudo manage/loq-uv-diagnose.sh --minutes 240   # a proper cold soak
sudo manage/loq-uv-diagnose.sh --show          # what is applied right now
sudo manage/loq-uv-diagnose.sh --reset         # back to stock
```

### What `--show` prints

1. `intel-undervolt -s` — the offsets intel-undervolt believes are set.
2. Every `/sys/devices/virtual/thermal/thermal_zone*/offset`, with its type,
   so you can see what the kernel is actually reporting.
3. `/sys/devices/system/cpu/intel_pstate/no_turbo` if present.

If (1) and (2) disagree, something re-applied or cleared the offsets after
boot. That is the suspend-resume bug in §5.

### What a stress run does

```bash
stress-ng --cpu "$(nproc)" --matrix 1 --matrix-size 64 --verify --timeout 45m --metrics-brief
```

`--matrix` is the important flag. It exercises the AVX/FMA/vector paths where
voltage droop shows up first; a plain integer loop will pass an unstable
undervolt all day. `--verify` makes stress-ng confirm the operation actually
computed the expected result, so a miscomputation is caught as a failure rather
than silently producing wrong data.

Before starting, the script takes a `pre-kernel` snapshot through
`manage/loq-snapshot.sh` if `timeshift --list` works.

### Hardware error detection

While the CPU is loaded, the script polls `dmesg` for new lines and matches:

```
WHEA | hardware error | MCE | machine check | edac.*error
```

The two that matter most:

| Kernel facility | What it reports | Why |
|------------------|-----------------|-----|
| **WHEA-Logger, bus error `18`** | A corrected or uncorrected error on a CPU internal bus — ring, cache, or the interconnect. This is the one an unstable undervolt produces | The processor itself detected the fault. This is hardware telling you, not a heuristic |
| **Machine Check Exception, `19`** | An MCE was raised and reported. On x86 this is the top-level vector for a CPU error | Appears as `mce: [hardware error]` in `dmesg` |

**EDAC** (Error Detection and Correction) is also matched
(`edac.*error`). EDAC reads the corrected-error counters the CPU exposes in its
corrected-error registers; `ce_count` climbing during a stress run is a strong
signal even when nothing was logged as a hard error. Check it directly:

```bash
grep -r . /sys/devices/system/edac/mc/mc*/ce_count /sys/devices/system/edac/mc/mc*/ue_count
```

On the first new matching line the script prints the offending lines, kills the
stress run and fails. It does not average, retry, or decide it was fine.

### Verdict

```
PASSED: 45 minutes of CPU+AVX stress with no WHEA/MCE errors.
```

and it says, correctly, that this is good evidence and not proof. For anything
you intend to keep, run it cold for 240 minutes.

### Bisecting

On failure the script tells you what to do, and the loop is:

```bash
# 1. stay usable while you think
sudo manage/loq-uv-diagnose.sh --reset

# 2. halve the offending domain in config/loq.conf, e.g. sa -20 -> -10
$EDITOR config/loq.conf

# 3. re-apply and re-test
sudo install-scripts/app/04_cpu_undervolt.sh
sudo manage/loq-uv-diagnose.sh --minutes 45
```

Repeat until it passes. Hard floor is 0 mV: if `sa -10` still fails, set
`LOQ_ENABLE_UNDERVOLT=0`. That is a valid outcome and the right one — this CPU
does not need an undervolt.

Record the result somewhere, in the file's own suggested form:

```
-60/-40/-30/-20/-20 mV -- passed 45m
```

---

## 4. Known gap: the signature check does not work

**State this plainly rather than trusting it.** `04_cpu_undervolt.sh` tries to
confirm the running CPU is the part the offsets were written for, using:

```bash
cpu_signature="$(cpuid -1 -s 0x1 2>/dev/null | awk '/^Version/ {print $4}')"
```

compared against `LOQ_UNDERVOLT_SIGNATURE="0x106B0"`. That check **has not been
observed working on real hardware.** Do not rely on it. If `04_cpu_undervolt.sh`
prints `running CPU signature matches`, that is the awk extraction succeeding,
not a verified match.

Two distinct problems:

1. **The extraction is unverified.** `cpuid(1)` reports family/model/stepping in
   its `Version:` line as decimal fields, and `-s 0x1` selects register 1. The
   exact output shape varies by `cpuid` version. `awk '/^Version/ {print $4}'`
   was written against a shape that has not been confirmed on this machine. If
   the field is missing, the comparison silently becomes "unknown" and the
   script proceeds with a warning.
2. **The thermal-zone `id` read is a different kind of identifier.**
   `04_cpu_undervolt.sh` also reads `${thermal_zone}/id` for the `x86_pkg_temp`
   zone. That is a kernel-assigned zone index. It is not a CPUID signature, it
   is not derived from the CPU model, and it can never match `0x106B0`. It is
   printed as information only and must not be read as a part check.

### What to do instead

Verify the part by hand:

```bash
lscpu | grep -E 'Model name|Model:'
cpuid -1 -s 0x1
intel-undervolt -q          # lists the domains this CPU actually supports
```

`intel-undervolt -q` is the most useful of the three: it prints the domains the
silicon exposes. If `sa` is absent there, no offset is being written for it and
the value in `loq.conf` is inert.

The real protection against writing offsets for the wrong part is the
diagnostics in §3, not the signature comparison.

---

## 5. Ownership: intel-undervolt vs thermald

- `intel-undervolt` **applies once**, at install time and via
  `loq-undervolt.service` at boot.
- `thermald` **owns the offsets at runtime** and re-asserts them.

The unit `04_cpu_undervolt.sh` writes:

```ini
[Unit]
Description=archloq: apply the CPU undervolt once at boot
After=multi-user.target
After=thermald.service

[Service]
Type=oneshot
RemainAfterExit=no
ExecStart=/usr/bin/intel-undervolt -q
ExecStart=/usr/bin/intel-undervolt -s

[Install]
WantedBy=multi-user.target
```

`After=thermald.service` is the load-bearing line.

### Why a racing re-apply unit loses the undervolt after suspend

Suspend/resume does not preserve MSR state in the way people expect. The
sequence that produces the classic "works after boot, lost after suspend"
failure:

1. Boot. `thermald` starts, writes the offsets.
2. `loq-undervolt.service` runs (ordered after thermald), writes them again.
   Both agree.
3. Suspend. The CPU and its MSRs are reset to a lower power state.
4. Resume. The offsets are **not** automatically restored — but thermald, seeing
   the values it wrote are now absent, re-applies them. Good.
5. Anything that also runs at resume and writes `0` into the same MSR — a
   *second* oneshot unit, `intel-undervolt -r`, a suspend hook, or a unit
   ordered *before* thermald rather than after — clears them.

The symptom is nondeterministic: it may work for a week, or fail on the first
resume. The cause is two writers with no single authority, and a race whose
outcome depends on ordering. `After=thermald.service` makes thermald the last
writer by construction, which removes the race rather than trying to win it.

**One owner per knob is the same rule that governs
[POWER_MANAGEMENT.md](POWER_MANAGEMENT.md).** If you find yourself adding a
second thing that writes an undervolt offset, you are recreating this bug.

---

## 6. Files

| Path | Owner | Written by |
|------|-------|-----------|
| `/etc/intel-undervolt.conf` | offsets | `04_cpu_undervolt.sh` |
| `/etc/systemd/system/loq-undervolt.service` | apply once at boot | `04_cpu_undervolt.sh` |
| `/etc/thermald.conf` | trip points, thermald's own view | package default |
| `/dev/cpu/0/msr` | the `msr` module must be loadable | `modprobe msr` |

`04_cpu_undervolt.sh` warns and skips if `msr` cannot be loaded. Raptor Lake
needs the microcode in `linux-firmware`, which archinstall installs.

---

## 7. Related

- [POWER_MANAGEMENT.md](POWER_MANAGEMENT.md) — PPD/thermald/legiond split
- [FAN_CONTROL.md](FAN_CONTROL.md) — what actually moves when the CPU gets hot
- [REFORMAT-XFCE.md §16](REFORMAT-XFCE.md) — the decision this implements