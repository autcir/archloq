# archloq

Reproducible Arch Linux + Xfce on a **Lenovo LOQ 17IRX10** (i7-13700HX, RTX 5060 Laptop).

The install is split in two so that the part that touches your disk is small,
versioned, and reviewable:

1. **`archinstall/`** does partitioning, encryption, the bootloader and the kernel.
   The profile is validated against archinstall's own parser, not a guessed schema.
2. **`install-scripts/`** does everything else — driver, power, desktop, hardening,
   snapshots, backup, dotfiles. Every step is idempotent, so re-running one after
   a failure is cheap.

Nothing in this repository is automatic. You run it, you read it first.

[![Arch Linux](https://img.shields.io/badge/Arch_Linux-1793D1?style=for-the-badge&logo=arch-linux&logoColor=white)](https://archlinux.org/)
[![Lenovo LOQ](https://img.shields.io/badge/Lenovo_LOQ-76B900?style=for-the-badge)]()
[![NVIDIA Blackwell](https://img.shields.io/badge/NVIDIA-Blackwell_sm__120-fc5252?style=for-the-badge&logo=nvidia&logoColor=white)]()
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

---

## What this is tuned for

| Component | Choice | Why |
|-----------|--------|-----|
| GPU | `nvidia-open-dkms` + `envycontrol` | The RTX 5060 Laptop is a GB206M (Blackwell, `sm_120`). **No closed-source driver exists for it** — see [GPU_SETUP.md](docs/GPU_SETUP.md). |
| Kernel | `linux-zen` + `systemd-boot` | Pure UEFI, no shim, no Secure Boot. |
| Desktop | Xfce 4.20, xfwm4's own compositor | No picom. Two compositors fight over the same redirected windows. |
| Power | `power-profiles-daemon` + `thermald` + `legiond` | One owner per sysfs knob. TLP is gone — see [POWER_MANAGEMENT.md](docs/POWER_MANAGEMENT.md). |
| Storage | LUKS2 on 3 of 4 partitions, btrfs subvolumes | Separate `/home` so a root rollback cannot touch your files. |
| Snapshots | timeshift on btrfs-assistant | `/home` is not snapshotted; borg covers it. |
| Backup | borg on an external HDD | The repository is encrypted even though the ext4 underneath is not. |

---

## Quick start

Read [docs/INSTALLATION.md](docs/INSTALLATION.md). The short version:

```bash
# 0. On the CURRENT system, before wiping anything.
sudo ./manage/loq-preflight.sh --mount --backup

# 1. Boot the Arch ISO, connect to the network (docs/WIFI.md), disable Secure Boot
#    in the firmware, then:
cp /root/archloq/archinstall/user_configuration.json /root/
cp archinstall/user_credentials.json.example /root/creds.json && $EDITOR /root/creds.json
archinstall --config /root/user_configuration.json --creds /root/creds.json

# 2. First boot:
git clone https://github.com/ciroautuori/archloq /root/archloq
$EDITOR /root/archloq/config/loq.conf
/root/archloq/install-scripts/pacmaster.sh --resume

# 3. Verify
sudo /root/archloq/install-scripts/pacmaster.sh --audit
sudo /root/archloq/manage/loq-uv-diagnose.sh     # validate the undervolt
```

---

## Documentation

Start with these two; they carry the reasoning.

| Document | Covers |
|----------|--------|
| **[REFORMAT-XFCE.md](docs/REFORMAT-XFCE.md)** | The design spec: every decision, the rationale, the defects found in the previous setup, and what the implementation turned up. Read this first. |
| **[INSTALLATION.md](docs/INSTALLATION.md)** | The executable runbook. |

| Document | Covers |
|----------|--------|
| [PARTITIONING.md](docs/PARTITIONING.md) | The four-partition layout, byte-exact offsets, and both the `archinstall` and manual `parted` routes |
| [WIFI.md](docs/WIFI.md) | Getting online in the ISO, three methods, and the archinstall config key trap |
| [GPU_SETUP.md](docs/GPU_SETUP.md) | Blackwell driver, module options, envycontrol modes, troubleshooting |
| [POWER_MANAGEMENT.md](docs/POWER_MANAGEMENT.md) | PPD, thermald, legiond — and why TLP was removed |
| [CPU_TUNING.md](docs/CPU_TUNING.md) | Undervolt domains, conservative values, how to validate them |
| [FAN_CONTROL.md](docs/FAN_CONTROL.md) | legiond scope, fan curves, the degradation path |
| [XFCE.md](docs/XFCE.md) | Desktop layout, panel architecture, keybindings, the libadwaita limitation |
| [BACKUP.md](docs/BACKUP.md) | The external HDD as a managed borg target |
| [RECOVERY.md](docs/RECOVERY.md) | Boot failures, rollback, btrfs recovery, total disk loss |
| [SECRETS.md](docs/SECRETS.md) | What is stored where, and what is deliberately not done |
| [archinstall/README.md](archinstall/README.md) | The profile, the validator, and four silent archinstall bugs |

---

## Repository structure

```
archloq/
├── archinstall/
│   ├── user_configuration.json        # the install; validated, generated
│   ├── user_credentials.json.example  # the shape of the credentials
│   ├── validate.py                     # validates the profile against archinstall itself
│   └── README.md
├── config/
│   ├── loq.conf                       # every flag, opt-in, documented
│   ├── legiond/legiond.ini            # fan curves, charge limits
│   ├── modprobe.d/lenovo-loq.conf     # i915, audio, USB autosuspend
│   ├── timeshift/timeshift.json       # snapshot type and exclusions
│   └── applications/                  # per-application config
├── install-scripts/
│   ├── pacmaster.sh                   # orchestrator: --resume, --audit, --from N
│   ├── lib/utils.sh                   # config loading, idempotency markers, logging
│   └── app/                           # 01..10, then 90_postinstall, 99_safe_reboot_check
├── manage/                            # loq-preflight, loq-backup, loq-restore,
│                                       # loq-snapshot, loq-uv-diagnose
├── dotfiles/                          # Xfce; run order in dotfiles/README.md
└── docs/
```

---

## Working with it

```bash
# What has run, and what has not
sudo ./install-scripts/pacmaster.sh --list

# Re-run only what failed
sudo ./install-scripts/pacmaster.sh --resume

# Re-check the system without changing anything
sudo ./install-scripts/pacmaster.sh --audit
```

Every script in `install-scripts/` and `manage/` is shellcheck-clean at `warning`
severity, and CI enforces it.

---

## Removed in this version

Deliberately, and documented rather than quietly dropped:

- **TLP.** It and `power-profiles-daemon` write the same `cpufreq` and runtime-PM
  knobs, so the effective configuration depended on which one started last. The
  TLP-era helpers (`loq-mode`, `loq-power-apply`, `loq-power-diag`) were deleted
  because they invoke `tlp`.
- **The Hyprland/KDE desktop and Omarchy.** Replaced by Xfce. `optimize/` and
  `runtime/` went with it.
- **The local LLM stack** (ollama, llama.cpp, open-webui). It idles on the GPU.
  Docker GPU passthrough still works — the driver and `libcuda` come from
  `nvidia-open-dkms`, not from a host-side LLM runtime.
- **`optimus-manager` and `supergfxctl`.** `envycontrol` replaces the former;
  supergfxctl's own wiki advises against installing it during the transition to
  its successor unless VFIO is needed, and nothing here needs VFIO.

---

## License

MIT — see [LICENSE](LICENSE).