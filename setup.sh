#!/bin/bash

# -e: abort on error; -E: make the ERR trap fire inside functions too.
set -eE

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Tee all output to a timestamped log so failures are reviewable after the run.
LOGFILE="/tmp/arch-hyprland-setup-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOGFILE") 2>&1

# On any failure, report exactly what failed and where, then point at the log.
on_error() {
    local rc=$?
    echo "" >&2
    echo "✗ setup FAILED (exit $rc)" >&2
    echo "  failing command: ${BASH_COMMAND}" >&2
    echo "  call stack: ${FUNCNAME[*]:1}" >&2
    echo "  full log: $LOGFILE" >&2
    exit "$rc"  # report once, then stop (prevents ERR re-firing up the stack)
}
trap on_error ERR

# shellcheck source=configs.sh
source "$SCRIPT_DIR/configs.sh"
# shellcheck source=packages.sh
source "$SCRIPT_DIR/packages.sh"

# Override with: DOTFILES_REPO=git@github.com:youruser/dotfiles.git ./setup.sh
DOTFILES_REPO="${DOTFILES_REPO:-git@github.com:IslamEssam01/dotfiles.git}"

# Full system sync + upgrade once up front (avoids partial-upgrade breakage on
# rolling Arch), and install prereqs needed before the first interactive step
# (gh device flow) and the dotfiles clone — all in one transaction.
echo "Syncing/upgrading system and installing prerequisites..."
sudo pacman -Syu --needed --noconfirm git base-devel openssh github-cli stow

# Set up SSH key + register with GitHub via gh device flow
setup_ssh_key

# Clone dotfiles via SSH (idempotent)
if [ ! -d ~/dotfiles ]; then
    echo "Cloning dotfiles from $DOTFILES_REPO ..."
    git clone "$DOTFILES_REPO" ~/dotfiles
else
    echo "~/dotfiles already exists. Skipping clone."
fi

# Install yay (idempotent)
if ! command -v yay >/dev/null 2>&1; then
    echo "Installing yay AUR helper..."
    git clone https://aur.archlinux.org/yay.git /tmp/yay
    (cd /tmp/yay && makepkg -si --noconfirm)
    rm -rf /tmp/yay
fi

# Run package installations
install_core_packages
install_hyprland_packages
install_audio_packages
install_utilities
install_fonts

# Conditional NVIDIA driver configuration
configure_nvidia_drivers

# Run configurations
install_oh_my_zsh
install_tpm
stow_dotfiles
configure_services
configure_sysctl

echo "Setup complete! Reboot recommended."
