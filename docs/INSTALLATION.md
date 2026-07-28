# Installation Guide

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Arch Linux from Zero](#arch-linux-from-zero)
3. [Modular Installation](#modular-installation)
4. [Post-Installation](#post-installation)

---

## Prerequisites

- Lenovo LOQ 17IRX10 (i7-13700HX + RTX 5060 Laptop)
- Arch Linux ISO
- USB drive (8GB+)
- Internet connection

---

## Arch Linux from Zero

### Step 1: Boot and Connect

```bash
# Connect to internet
wifi-menu
# or for wired: DHCP is automatic
```

### Step 2: Partition

```bash
# UEFI partitioning
cgdisk /dev/nvme0n1

# Create partitions:
# 1. EFI System Partition: 1G, Type EF00
# 2. Linux filesystem: remaining space, Type 8300
```

### Step 3: Format and Mount

```bash
# Format
mkfs.fat -F32 /dev/nvme0n1p1
mkfs.ext4 /dev/nvme0n1p2

# Mount
mount /dev/nvme0n1p2 /mnt
mkdir -p /mnt/boot
mount /dev/nvme0n1p1 /mnt/boot
```

### Step 4: Install Base System

```bash
# Install base packages
pacstrap /mnt base linux-zen linux-zen-headers linux-firmware

# Generate fstab
genfstab -U /mnt >> /mnt/etc/fstab
```

### Step 5: Chroot

```bash
arch-chroot /mnt

# Set timezone
ln -sf /usr/share/zoneinfo/Europe/Rome /etc/localtime
hwclock --systohc

# Set locale
sed -i 's/^#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Set hostname
echo "loq" > /etc/hostname

# Set root password
passwd

# Configure network
echo "nameserver 1.1.1.1" > /etc/resolv.conf
```

### Step 6: Install Bootloader

```bash
# Install systemd-boot
bootctl install

# Create kernel cmdline
cat > /etc/kernel/cmdline << 'EOF'
root=PARTUUID=xxxxxxxx-xx rw quiet splash loglevel=3 nvidia_drm.modeset=1 mitigations=off
EOF

# Create boot entry
cat > /boot/loader/entries/arch-linux-zen.conf << 'EOF'
title    Arch Linux Zen
linux    /vmlinuz-linux-zen.img
initrd   /initramfs-linux-zen.img
options  root=PARTUUID=xxxxxxxx-xx rw quiet splash loglevel=3 nvidia_drm.modeset=1 mitigations=off
EOF
EOF

# Generate initramfs
mkinitcpio -P

# Enable reflector for mirrors
pacman -S --needed reflector
systemctl enable reflector.timer
```

### Step 7: Install AUR Helper

```bash
# Create user
useradd -m -G wheel yourname
passwd yourname

# Configure sudo
EDITOR=nano visudo  # uncomment %wheel ALL=(ALL) ALL

# Install yay
su - yourname
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si
```

### Step 8: Exit Chroot

```bash
exit
reboot
```

---

## Modular Installation

After base Arch is installed:

```bash
# Clone the repository
git clone https://github.com/yourname/loq.git
cd loq

# Run the installer
sudo bash install-scripts/pacmaster.sh
```

### Individual Steps

```bash
# Kernel and NVIDIA
sudo bash install-scripts/app/01_kernel_nvidia.sh

# Power management
sudo bash install-scripts/app/02_power_management.sh

# CPU tuning
sudo bash install-scripts/app/03_cpu_tuning.sh

# GPU switching
sudo bash install-scripts/app/04_gpu_switching.sh

# Fan control
sudo bash install-scripts/app/05_fan_control.sh

# System performance
sudo bash install-scripts/app/06_system_perf.sh

# Install scripts
sudo bash install-scripts/app/07_install_scripts.sh

# Local LLM
sudo bash install-scripts/app/08_local_llm.sh

# Verify
bash install-scripts/app/99_safe_reboot_check.sh
```

---

## Post-Installation

### Verify Installation

```bash
# Check NVIDIA
nvidia-smi

# Check power management
tlp-stat -b

# Check legiond
systemctl status legiond

# Run diagnostics
loq-power-diag
```

### Enable Services

```bash
systemctl enable --now tlp
systemctl enable --now thermald
systemctl enable --now legiond
systemctl enable --now intel-undervolt
```

### Reboot

```bash
reboot
```

---

## Configuration

Edit `config/loq.conf` before running the installer:

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

### Skip Steps

```bash
# Skip LLM installation
sudo SKIP_LLM=1 bash install-scripts/pacmaster.sh
```