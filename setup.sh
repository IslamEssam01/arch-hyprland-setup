#!/bin/bash

# Exit on error
set -e

# Source other scripts early (but configs.sh functions are called later)
source ./configs.sh  # Source configs.sh here for setup_ssh_key

# Set up SSH key for GitHub
setup_ssh_key

# Clone dotfiles using SSH
echo "Cloning dotfiles via SSH..."
git clone git@github.com:IslamEssam01/dotfiles.git ~/dotfiles
cd ~/dotfiles
# Assuming stow is used for dotfiles; install it early if needed
sudo pacman -S --needed --noconfirm stow

# Source remaining scripts (packages.sh can be sourced now)
source ./packages.sh

# Install AUR helper (yay)
echo "Installing yay AUR helper..."
sudo pacman -S --needed --noconfirm git base-devel
git clone https://aur.archlinux.org/yay.git /tmp/yay
cd /tmp/yay
makepkg -si --noconfirm
cd -

# Run package installations
install_core_packages
install_hyprland_packages
install_audio_packages
install_utilities
install_fonts

# Conditional NVIDIA driver configuration
configure_nvidia_drivers

# Run configurations (including stowing dotfiles)
stow_dotfiles
configure_services
configure_sysctl
install_oh_my_zsh

echo "Setup complete! Reboot recommended."
