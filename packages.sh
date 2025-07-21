#!/bin/bash

# Function to install packages via pacman or yay
# Note: Separation improves efficiency (pacman for repo packages is faster),
# but you can change to 'yay -S --needed --noconfirm "$@"' to use yay for all.
install_packages() {
    local repo_packages=()
    local aur_packages=()
    for pkg in "$@"; do
        if pacman -Si "$pkg" &> /dev/null; then
            repo_packages+=("$pkg")
        else
            aur_packages+=("$pkg")
        fi
    done
    if [ ${#repo_packages[@]} -gt 0 ]; then
        sudo pacman -S --needed --noconfirm "${repo_packages[@]}"
    fi
    if [ ${#aur_packages[@]} -gt 0 ]; then
        yay -S --needed --noconfirm "${aur_packages[@]}"
    fi
}

# Core utilities and tools
install_core_packages() {
    echo "Installing core packages..."
    install_packages stow uwsm htop nvtop sddm hyprland zsh fd zoxide fzf starship pass git-delta ripgrep nnn tree poppler glow ueberzug archivemount zip unzip pmount util-linux udisks2 atool unrar advcpmv rclone fuse2 fuse3 imagemagick zathura xdg-utils yazi eza dragon-drop ouch unarchiver bashmount ffmpegthumbnailer trash-cli selectdefaultapplication-git pamixer playerctl brightnessctl lm_sensors rofi-lbonn-wayland-git networkmanager network-manager-applet vlc 7zip breeze breeze5 dust duf ncdu bat pulsemixer grim slurp hyprshot simple-mtpfs walker bluez bluez-utils blueman ntfs-3g
}

# Hyprland/Wayland-specific packages
install_hyprland_packages() {
    echo "Installing Hyprland packages..."
    install_packages wlr-randr swaybg hypridle wl-clipboard gtklock lxappearance nwg-look qt5ct qt6ct waybar python-gobject dunst xdg-desktop-portal-hyprland hyprpolkitagent sway-audio-idle-inhibit-git qt5-wayland qt6-wayland adw-gtk-theme
}

# Audio packages (preferring Pipewire)
install_audio_packages() {
    echo "Installing audio packages..."
    install_packages pavucontrol pipewire pipewire-jack pipewire-alsa pipewire-audio pipewire-pulse wireplumber
}

# Utilities and extras
install_utilities() {
    echo "Installing utilities..."
    install_packages kanata # fusermount is provided by fuse2/fuse3, so removed redundant entry
}

# Fonts
install_fonts() {
    echo "Installing fonts..."
    install_packages ttf-jetbrains-mono-nerd noto-fonts-emoji otf-font-awesome
}
