# GPU Setup

## NVIDIA Blackwell (RTX 5060 Laptop)

### Driver Requirements

- **Minimum**: Driver 570+
- **Recommended**: Driver 590+
- **CUDA**: 12.8+
- **PyTorch**: nightly cu128

### Install

```bash
yay -S nvidia-dkms nvidia-utils-dkms cuda-dkms
```

### Required Kernel Parameters

```bash
# Add to /etc/kernel/cmdline
nvidia_drm.modeset=1

# Rebuild UKI
mkinitcpio -P
bootctl install
```

### Verify

```bash
nvidia-smi
# Should show: NVIDIA-SMI 570.x.xx   Driver Version: 570.x.xx   CUDA Version: 12.8
```

---

## GPU Switching Methods

### envycontrol (Recommended)

```bash
yay -S envycontrol

# Switch modes
enjoycontrol-gpu-switch hybrid    # PRIME offloading
enjoycontrol-gpu-switch integrated # Intel only
enjoycontrol-gpu-switch discrete   # NVIDIA only
```

### loq-control (GUI)

```bash
# Requires legion_laptop module
cd runtime/loq-control
pip install -r requirements.txt
python main.py
```

Features:
- Real-time monitoring
- Temperature history
- Performance profiles
- GPU mode switching

### Manual prime-run

```bash
# Run single app with NVIDIA
prime-run firefox
```

---

## CUDA Setup for Blackwell

### Environment

```bash
# Add to ~/.bashrc
export CUDA_PATH=/usr/lib/cuda
export PATH=$CUDA_PATH/bin:$PATH
export LD_LIBRARY_PATH=$CUDA_PATH/lib64:$LD_LIBRARY_PATH
```

### PyTorch for Blackwell

```bash
# Install PyTorch nightly with CUDA 12.8
pip install torch --index-url https://download.pytorch.org/whl/nightly/cu128
```

### Verify CUDA

```bash
nvidia-smi -q | grep -i cuda
nvcc --version
```

---

## Troubleshooting

### Blackwell Not Detected

```bash
# Check driver version
nvidia-smi | grep "Driver Version"

# Must be 570+ for sm_120 support

# Check kernel module
lsmod | grep nvidia
```

### CUDA Not Working

```bash
# Recreate initramfs
mkinitcpio -P

# Check CUDA installation
ls /usr/lib/cuda/

# Verify nvidia-drm modeset
cat /sys/module/nvidia_drm/parameters/modeset
```

### Wayland + NVIDIA Issues

```bash
# NVIDIA offload not supported on Wayland
# Use Intel-Only mode for battery life
enjoycontrol-gpu-switch integrated

# Or use X11 session
```

---

## Performance Notes

### RTX 5060 Blackwell Limitations

1. **No VAAPI** - NVIDIA offload doesn't work with VAAPI on Wayland
2. **Driver 570+** - Required for sm_120 support
3. **CUDA 12.8+** - Required for latest features

### Power Consumption

| Mode | GPU Power | Notes |
|------|-----------|-------|
| Hybrid | 15-30W | PRIME offloading |
| Intel-Only | 0-5W | No NVIDIA |
| NVIDIA-Only | 45-80W | Full power |