# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - 2026-10-08

Replaces Omarchy (Hyprland) with plain Arch Linux and Xfce. This is a breaking
change: the disk layout, the GPU driver, the power stack and the desktop are all
different, and the result is not in-place upgradeable.

### Fixed

- **`01_kernel_nvidia.sh` installed a driver that does not exist for this GPU.**
  It requested `nvidia-dkms`, the closed-source variant. The RTX 5060 Laptop is a
  GB206M (Blackwell, `sm_120`); NVIDIA ships no closed driver for it, so the
  script installed nothing usable. Now `nvidia-open-dkms`.
- **`config/loq.conf` declared `LOQ_ENABLE_LEGIOND` twice** (lines 22 and 37), so
  the second definition silently won. Every key is now declared once and
  `lib/utils.sh` refuses to start if any key is duplicated.
- **TLP and power-profiles-daemon were both enabled**, along with thermald and
  legiond. TLP and PPD write the same cpufreq and runtime-PM knobs, so the
  effective configuration depended on which started last. TLP is gone.
- **`options i915 enable_guc=2`** in `config/modprobe.d/lenovo-loq.conf` is a
  parameter that was removed from the kernel years ago, and
  `options legion-laptop force=1` forces a module superseded by `legiond`.
  Forcing both meant two daemons contending for the embedded controller.
- **`chromium-flags.conf` was entirely Wayland** (`--ozone-platform-hint=auto`,
  `WaylandWindowDecorations`) and forced `--gtk-version=4`, which produces
  unthemed dialogs on an X11 session.
- **Nine install scripts were dead code** — not referenced by `pacmaster.sh`,
  still present, and still carrying the TLP and Hyprland assumptions.
- **`dotfiles/scripts/01-terminal.sh` installed a `ghostty` config that had been
  deleted**, and `09-icons-papirus.sh` sourced a `lib.sh` that never existed.
  Both are removed.

### Added

- **`archinstall/`** — a real archinstall 4.x profile with a validator that
  imports archinstall and runs its own parser over it, because the upstream
  `schema.json` is not valid JSON and both configurations in the sibling repo are
  unreadable by the current version.
- **`manage/loq-preflight.sh`** — audits what erasing the NVMe would lose:
  uncommitted and unpushed git work, SSH and GPG keys, keyrings, disk usage, and
  whether the backup disk is attached.
- **`manage/loq-snapshot.sh`**, **`loq-restore.sh`**, **`loq-backup.sh`** —
  labelled restore points, borg archiving against a retention policy, and restore
  from an archive.
- **`manage/loq-uv-diagnose.sh`** — stresses the CPU with `stress-ng` while
  watching for WHEA and machine-check errors, and bisects an offset that fails.
- **`docs/PARTITIONING.md`**, **`WIFI.md`**, **`BACKUP.md`**, **`RECOVERY.md`**,
  **`XFCE.md`** — the four-partition layout with byte-exact offsets, getting
  online in the ISO, the external HDD as a managed borg target, four independent
  recovery paths, and the desktop layout.
- **Dotfiles for Xfce**: a generator for the two-row panel and the keyboard
  shortcuts rather than hand-written XML, a versioned xfconf per-channel tree,
  and an xfwm4 theme whose assets are generated from the palette by
  `dotfiles/tools/gen-xfwm4-theme.py`.
- CI validates the archinstall profile instead of only linting shell.

### Changed

- **Disk layout**: four partitions — ESP, a LUKS swap partition, a LUKS btrfs root
  (`@`, `@var`, `@.timeshift`) and a separate LUKS btrfs `/home` (`@home`) — all
  offsets exact multiples of 1 MiB, ending 1 MiB short of the disk so nothing
  collides with the GPT backup header. A swap *partition* also makes hibernate
  possible without the fragility of a snapshotted btrfs swapfile.
- **Power**: `power-profiles-daemon` + `thermald` + `legiond`, one owner per knob.
- **Snapshots**: timeshift driven by a root crontab over btrfs-assistant.
  archinstall's own `snapshot_config` is discarded for any `--config` install, so
  the configuration is done here instead.
- **Undervolt**: conservative values for Raptor Lake (`-60/-40/-30/-20/-20` mV,
  down from `-100/-80/-80/-50/-50`), with mandatory verification.
- **Security**: nftables with IPv6 ICMPv6 allowed, fail2ban, password-required
  sudo, and a sysctl set that leaves `vm.swappiness` alone because zram-generator
  owns swap policy.
- `lib/utils.sh` validates the config, detects duplicate keys, and records
  completion markers so a re-run skips finished work.

### Removed

- The local LLM stack (`ollama`, `llama.cpp`, `open-webui`, `cuda-dkms`,
  `docs/LLM_STACK.md`). It idles on the GPU. Docker GPU passthrough still works.
- TLP and the helpers that invoked it (`loq-mode`, `loq-power-apply`,
  `loq-power-diag`, `loq-definitive-power.sh`, `config/tlp.d/`).
- The Hyprland/KDE desktop, Omarchy-specific config, `optimize/`, `runtime/`, and
  the nine dead install scripts.
- `optimus-manager` and `supergfxctl`, in favour of `envycontrol`.

## [1.0.0] - 2026-07-28

First tagged release. The configuration itself has been in use on the reference
hardware for some time; this release makes the repository usable by anyone else.

### Fixed

- **`runtime/` produced empty directories on every clone.** Nine entries were
  committed as gitlinks (mode 160000) with no `.gitmodules` file, so the
  NVIDIA, undervolt, and LLM reference material was unreachable for everyone
  but the original author. They are now fetched on demand via
  `runtime/fetch-runtime.sh`; all eight upstream URLs verified.
- **`99_safe_reboot_check.sh` always reported success.** It tested `$?` after
  an `echo`, which is always 0, so it printed "ALL CLEAR — safe to reboot"
  regardless of how many checks had failed.
- **`12-transparency-blur.sh` could not be parsed.** The `add_rule()`
  declaration line was missing, leaving an orphaned function body. The function
  was also never called: the script wrote `count 12` and claimed twelve opacity
  rules were applied while creating none.
- **All twelve install scripts were non-executable**, including the documented
  entrypoint `pacmaster.sh`.
- **Colour output was broken everywhere.** `lib/utils.sh` used single-quoted
  `printf`, so every script printed literal `${BLUE}==>${NC}` markers.
- **`.gitignore` hid the secrets template.** `config/*secrets*` also matched
  `config/secrets.json.example`, the file `docs/SECRETS.md` tells users to copy.
- Unquoted `$(nproc)` passed to `cmake -j` in `08_local_llm.sh`.
- Theme lookups using `ls | grep` broke on paths containing spaces.
- README documented `install-scripts/config/loq.conf`, which does not exist.

### Added

- CI (`.github/workflows/ci.yml`): shellcheck, `bash -n` parsing, executable-bit
  enforcement, and a private-key scan, all on GitHub-hosted runners.
- `CONTRIBUTING.md`, `SECURITY.md`, `CODE_OF_CONDUCT.md`, issue and PR templates.
- `.editorconfig`, `.shellcheckrc`, Dependabot for GitHub Actions.
- `runtime/fetch-runtime.sh` to clone or update the upstream reference repos.

[2.0.0]: https://github.com/ciroautuori/archloq/releases/tag/v2.0.0
[1.0.0]: https://github.com/ciroautuori/archloq/releases/tag/v1.0.0
