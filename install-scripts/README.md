# LOQ Installation Scripts

Modular installation scripts for Lenovo LOQ on Arch Linux.

## Structure

```
install-scripts/
├── pacmaster.sh           # Main orchestrator
├── config/
│   └── loq.conf           # Configuration file
├── lib/
│   └── utils.sh           # Shared utilities
└── app/
    ├── 01_kernel_nvidia.sh      # Kernel + NVIDIA drivers
    ├── 02_power_management.sh   # TLP + legion_linux
    ├── 03_cpu_tuning.sh         # Intel undervolt
    ├── 04_gpu_switching.sh      # envycontrol + GPU modes
    ├── 05_fan_control.sh        # legiond + fan curves
    ├── 06_system_perf.sh        # Makepkg + sysctl + I/O
    ├── 07_install_scripts.sh    # LOQ scripts + configs
    ├── 08_local_llm.sh          # Ollama + llama.cpp
    └── 99_safe_reboot_check.sh  # Pre-reboot verification
```

## Usage

```bash
# Run all steps
sudo bash install-scripts/pacmaster.sh

# Skip specific steps
sudo SKIP_LLM=1 bash install-scripts/pacmaster.sh

# Run individual steps
sudo bash install-scripts/app/01_kernel_nvidia.sh
```

## Configuration

Edit `config/loq.conf` before running:

```bash
LOQ_HOSTNAME="loq"
LOQ_USERNAME="yourname"
LOQ_TIMEZONE="Europe/Rome"
LOQ_ENABLE_OLLAMA="1"
LOQ_ENABLE_UNDERVOLT="1"
```

## Secrets Management

**NEVER commit secrets to GitHub!**

1. Check `.gitignore` - it excludes:
   - SSH keys
   - `.env` files
   - API keys
   - Chrome login data
   - GPG keys

2. Use templates:
   - Copy `.claude.json.example` → `~/.claude.json`
   - Fill in your actual keys

3. Backup secrets securely:
   ```bash
   bash manage/loq-backup.sh
   # Produces: secrets.tar.zst.gpg (encrypted)
   ```

4. For UKI boot, protect your boot partition:
   - Use systemd-boot with UKI
   - Set BIOS password
   - Consider LUKS encryption