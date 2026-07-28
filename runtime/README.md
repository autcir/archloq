# Runtime Repositories

This directory contains cloned repositories for Lenovo LOQ setup.

## Repositories (9 total)

### Lenovo Hardware

| Repo | Stars | Purpose |
|------|-------|---------|
| `LenovoLegionLinux/` | 3.2k | Kernel module, legiond, AUR packages |
| `loq-control/` | - | PyQt5 GUI for LOQ (i7-14700HX + RTX 5060 tested) |
| `legion-linux-toolkit/` | - | PyQt6 GUI for Arch/KDE Plasma 6 |

### Intel CPU Tuning

| Repo | Purpose |
|------|---------|
| `intel-undervolt/` | CPU undervolt config + systemd service |
| `intel-pstate-states/` | HWP diagnostics tool |

### NVIDIA Blackwell

| Repo | Purpose |
|------|---------|
| `rtx5060-setup/` | CUDA/PyTorch guide for Blackwell sm_120 |
| `ollama/` | Local LLM runtime |
| `llama.cpp/` | GPU-accelerated inference |
| `open-webui/` | Web UI for models |

## Usage

These are reference repositories. The actual configs are integrated into:

- `config/` - Kernel modules, TLP, modprobe
- `install-scripts/app/*.sh` - Installation scripts
- `scripts/` - Power management scripts

## Keeping Updated

```bash
# Update all repos
for dir in */; do
    (cd "$dir" && git pull)
done
```

## Why These Repos?

1. **LenovoLegionLinux** - Most comprehensive Legion/LOQ support
2. **loq-control** - Specific to LOQ model, tested with RTX 5060
3. **legion-linux-toolkit** - Arch/KDE integration
4. **intel-undervolt** - Best undervolt implementation
5. **intel-pstate-states** - HWP state exploration
6. **rtx5060-setup** - Blackwell-specific CUDA notes
7. **ollama** - Standard local LLM
8. **llama.cpp** - GPU inference backend
9. **open-webui** - Web interface

## Excluded Repos

These were cloned but excluded (duplicates or unnecessary):

- `lenovo-vantage-features-for-linux` - Duplicate of LenovoLegionLinux
- `undervolt` - Duplicate of intel-undervolt
- `nvidia-open-gpu-kernel-modules` - 16GB source, not needed on Arch (AUR packages suffice)