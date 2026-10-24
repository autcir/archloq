#!/bin/bash
# =============================================================================
# LOQ MASTER INSTALLER
# =============================================================================
# Main orchestrator for Lenovo LOQ setup on Arch Linux
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=install-scripts/lib/utils.sh
source "$SCRIPT_DIR/lib/utils.sh"

# Default configuration
CONFIG_FILE="${CONFIG_FILE:-$SCRIPT_DIR/config/loq.conf}"
# shellcheck source=/dev/null
[[ -f "$CONFIG_FILE.local" ]] && source "$CONFIG_FILE.local"
# shellcheck source=/dev/null
[[ -f "$CONFIG_FILE" ]] && source "$CONFIG_FILE"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

say() { printf '\n%b==>%b %s\n' "$BLUE" "$NC" "$*"; }
ok() { printf '  %b✓%b %s\n' "$GREEN" "$NC" "$*"; }
warn() { printf '  %b!%b %s\n' "$YELLOW" "$NC" "$*"; }
error() { printf '  %b✗%b %s\n' "$RED" "$NC" "$*"; }

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root"
        exit 1
    fi
}

# Check prerequisites
check_prerequisites() {
    say "Checking prerequisites..."
    
    # Check for yay
    if ! command -v yay &> /dev/null; then
        warn "yay not found - AUR packages will be skipped"
    fi
    
    # Check for internet
    if ! ping -c1 1.1.1.1 &> /dev/null; then
        error "No internet connection"
        exit 1
    fi
    
    ok "Prerequisites met"
}

# Main installation flow
main() {
    say "Starting Lenovo LOQ setup..."
    
    check_root
    check_prerequisites
    
    # Step 1: Kernel and NVIDIA
    if [[ "${SKIP_KERNEL:-0}" != "1" ]]; then
        bash "$SCRIPT_DIR/app/01_kernel_nvidia.sh"
    fi
    
    # Step 2: Power management
    if [[ "${SKIP_POWER:-0}" != "1" ]]; then
        bash "$SCRIPT_DIR/app/02_power_management.sh"
    fi
    
    # Step 3: CPU tuning (undervolt)
    if [[ "${SKIP_UNDERVOLT:-0}" != "1" ]]; then
        bash "$SCRIPT_DIR/app/03_cpu_tuning.sh"
    fi
    
    # Step 4: GPU switching
    if [[ "${SKIP_GPU:-0}" != "1" ]]; then
        bash "$SCRIPT_DIR/app/04_gpu_switching.sh"
    fi
    
    # Step 5: Fan control
    if [[ "${SKIP_FAN:-0}" != "1" ]]; then
        bash "$SCRIPT_DIR/app/05_fan_control.sh"
    fi
    
    # Step 6: System performance
    if [[ "${SKIP_PERF:-0}" != "1" ]]; then
        bash "$SCRIPT_DIR/app/06_system_perf.sh"
    fi
    
    # Step 7: Scripts and configs
    if [[ "${SKIP_SCRIPTS:-0}" != "1" ]]; then
        bash "$SCRIPT_DIR/app/07_install_scripts.sh"
    fi
    
    # Step 8: Local LLM setup
    if [[ "${SKIP_LLM:-0}" != "1" ]]; then
        bash "$SCRIPT_DIR/app/08_local_llm.sh"
    fi
    
    # Step 9: Safe reboot check
    bash "$SCRIPT_DIR/app/99_safe_reboot_check.sh"
    
    say "Installation complete!"
    say "Run verify-boot.sh before rebooting"
}

main "$@"