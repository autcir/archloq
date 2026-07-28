# Lenovo LOQ - Definitive Arch Linux Setup

[![Arch Linux](https://img.shields.io/badge/Arch_Linux-1793D1?style=for-the-badge&logo=arch-linux&logoColor=white)](https://archlinux.org/)
[![Lenovo LOQ](https://img.shields.io/badge/Lenovo_LOQ-Yellow?style=for-the-badge)]()
[![NVIDIA Blackwell](https://img.shields.io/badge/NVIDIA-Blackwell-sm_120-blue)]()

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
# Run modular installer
sudo bash install-scripts/pacmaster.sh

# Or follow the installation guide
docs/INSTALLATION.md
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
loq/
├── README.md
├── docs/
│   ├── INSTALLATION.md
│   ├── POWER_MANAGEMENT.md
│   ├── CPU_TUNING.md
│   ├── GPU_SETUP.md
│   ├── FAN_CONTROL.md
│   ├── LLM_STACK.md
│   └── SECRETS.md
├── config/
│   ├── loq.conf
│   ├── tlp.d/
│   ├── modprobe.d/
│   └── legion_linux/
├── scripts/
│   ├── loq-mode
│   ├── loq-power-apply
│   ├── loq-power-diag
│   └── unlock-secrets.sh
├── install-scripts/
│   ├── pacmaster.sh
│   ├── config/loq.conf
│   ├── lib/utils.sh
│   └── app/01_*_nvidia.sh ...
├── runtime/
├── manage/
│   └── loq-backup.sh
└── dotfiles/
```

## Secrets Management

⚠️ **NEVER commit secrets to GitHub!**

Use `docs/SECRETS.md` for:
- git-crypt setup
- SOPS configuration
- GitHub Actions Secrets
- Template files

## License

MIT - See LICENSE file