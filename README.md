# Lenovo LOQ - Definitive Arch Linux Setup

[![Arch Linux](https://img.shields.io/badge/Arch_Linux-1793D1?style=for-the-badge&logo=arch-linux&logoColor=white)](https://archlinux.org/)
[![Lenovo LOQ](https://img.shields.io/badge/Lenovo_LOQ-Yellow?style=for-the-badge)]()
[![NVIDIA Blackwell](https://img.shields.io/badge/NVIDIA-Blackwell_sm__120-76B900?style=for-the-badge&logo=nvidia&logoColor=white)]()
[![CI](https://github.com/ciroautuori/archloq/actions/workflows/ci.yml/badge.svg)](https://github.com/ciroautuori/archloq/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Complete setup for Lenovo LOQ 17IRX10 (i7-13700HX + RTX 5060 Laptop 8GB) on Arch Linux.

## What's Included

### 🚀 Installation Methods

| Method | Description | Time |
|--------|-------------|------|
| **Modular Scripts** | Step-by-step installation | 30-45 min |
| **Arch from Zero** | Full Arch installation guide | 2-3 hours |

### 💻 Hardware Support

- ✅ **NVIDIA Blackwell** - RTX 5060 Laptop 8GB (sm_120)
- ✅ **Intel i7-13700HX** - P/E cores, HWP, undervolt
- ✅ **Lenovo WMI** - Power modes, fan control, charging
- ✅ **KDE Plasma 6** - Wayland optimized

## Documentation

| Document | Description |
|----------|-------------|
| [Installation Guide](docs/INSTALLATION.md) | Arch from Zero + modular scripts |
| [Power Management](docs/POWER_MANAGEMENT.md) | TLP, legion_linux, loq-mode |
| [CPU Tuning](docs/CPU_TUNING.md) | Intel undervolt, pstate diagnostics |
| [GPU Setup](docs/GPU_SETUP.md) | NVIDIA Blackwell, envycontrol |
| [Fan Control](docs/FAN_CONTROL.md) | legiond, custom curves |
| [LLM Stack](docs/LLM_STACK.md) | Ollama, llama.cpp, Open WebUI |
| [Secrets Management](docs/SECRETS.md) | git-crypt, SOPS, GitHub Secrets |

## Quick Start

```bash
git clone https://github.com/ciroautuori/archloq.git
cd archloq

# 1. Review the config first — these scripts run as root
$EDITOR config/loq.conf

# 2. Run the modular installer
sudo ./install-scripts/pacmaster.sh
```

> **Read before running.** Every script here modifies system-level settings
> (kernel modules, power, undervolt, fan curves) and is tuned for the exact
> hardware listed above. Review anything you run as root, and make sure you
> have a way back — see [docs/INSTALLATION.md](docs/INSTALLATION.md).

Optional — fetch the upstream reference repos (llama.cpp, ollama, open-webui):

```bash
./runtime/fetch-runtime.sh
```

## Configuration

Edit `config/loq.conf` before installation:

```bash
LOQ_HOSTNAME="loq"
LOQ_USERNAME="yourname"
LOQ_TIMEZONE="Europe/Rome"

# Enable features
LOQ_ENABLE_OLLAMA="1"
LOQ_ENABLE_UNDERVOLT="1"
LOQ_ENABLE_LLAMA_CPP="1"

# GPU mode
LOQ_GPU_MODE="hybrid"  # hybrid, intel, nvidia
```

## Repository Structure

```
archloq/
├── README.md
├── LICENSE
├── CONTRIBUTING.md
├── SECURITY.md
├── .github/
│   ├── workflows/ci.yml          # shellcheck, syntax, exec bits, secret scan
│   ├── ISSUE_TEMPLATE/
│   └── pull_request_template.md
├── docs/
│   ├── INSTALLATION.md
│   ├── POWER_MANAGEMENT.md
│   ├── CPU_TUNING.md
│   ├── GPU_SETUP.md
│   ├── FAN_CONTROL.md
│   ├── LLM_STACK.md
│   └── SECRETS.md
├── config/
│   ├── loq.conf                  # main configuration
│   ├── tlp.d/
│   ├── modprobe.d/
│   ├── legion_linux/
│   └── applications/
├── scripts/                      # loq-mode, loq-power-apply, loq-power-diag, ...
├── install-scripts/
│   ├── pacmaster.sh              # entrypoint
│   ├── lib/utils.sh
│   └── app/01_*.sh ... 99_*.sh
├── optimize/                     # sysctl, journald, udev, Wayland env
├── manage/loq-backup.sh
├── dotfiles/                     # Catppuccin/OneDark, zsh, nvim, konsole, ...
└── runtime/                      # upstream reference clones (NOT tracked)
    ├── README.md
    └── fetch-runtime.sh          # clone/update them on demand
```


## Secrets Management

⚠️ **NEVER commit secrets to GitHub!**

Use `docs/SECRETS.md` for:
- git-crypt setup
- SOPS configuration
- GitHub Actions Secrets
- Template files

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Security issues: please follow
[SECURITY.md](SECURITY.md) rather than opening a public issue.

## License

MIT — see [LICENSE](LICENSE).