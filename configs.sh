#!/bin/bash

# Set up SSH key for GitHub
setup_ssh_key() {
    echo "Setting up SSH key for GitHub..."

    # Check if SSH key already exists
    if [ ! -f ~/.ssh/id_ed25519 ]; then
        # Prompt for email
        echo "Enter your email for the SSH key comment (e.g., your_email@example.com):"
        read -r EMAIL
        if [ -z "$EMAIL" ]; then
            EMAIL="your_email@example.com"  # Default if empty
        fi

        ssh-keygen -t ed25519 -C "$EMAIL" -f ~/.ssh/id_ed25519 -N ""
        eval "$(ssh-agent -s)"
        ssh-add ~/.ssh/id_ed25519
    else
        echo "Existing SSH key found at ~/.ssh/id_ed25519. Skipping generation."
    fi

    # Display public key and prompt user to add to GitHub
    echo "Your public SSH key is:"
    cat ~/.ssh/id_ed25519.pub
    echo ""
    echo "1. Copy the above key."
    echo "2. Go to GitHub > Settings > SSH and GPG keys > New SSH key."
    echo "3. Paste the key and save."
    echo "Press Enter once added to GitHub..."
    read -r

    # Test SSH connection
    ssh -T git@github.com
    echo "SSH setup complete."
}

# NVIDIA driver configuration (inspired by Omarchy)
configure_nvidia_drivers() {
    if lspci | grep -i nvidia &> /dev/null; then
        echo "NVIDIA hardware detected. Configuring drivers..."

        # Driver Selection
        if echo "$(lspci | grep -i 'nvidia')" | grep -q -E "RTX [2-9][0-9]|GTX 16"; then
            NVIDIA_DRIVER_PACKAGE="nvidia-open-dkms"
        else
            NVIDIA_DRIVER_PACKAGE="nvidia-dkms"
        fi

        # Check which kernel is installed and set appropriate headers package
        KERNEL_HEADERS="linux-headers" # Default
        if pacman -Q linux-zen &>/dev/null; then
            KERNEL_HEADERS="linux-zen-headers"
        elif pacman -Q linux-lts &>/dev/null; then
            KERNEL_HEADERS="linux-lts-headers"
        elif pacman -Q linux-hardened &>/dev/null; then
            KERNEL_HEADERS="linux-hardened-headers"
        fi

        # Enable multilib repository for 32-bit libraries
        if ! grep -q "^\[multilib\]" /etc/pacman.conf; then
            sudo sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' /etc/pacman.conf
            sudo pacman -Sy  # Sync after enabling multilib
        fi

        # Install packages using our install_packages function
        PACKAGES_TO_INSTALL=(
            "${KERNEL_HEADERS}"
            "${NVIDIA_DRIVER_PACKAGE}"
            "nvidia-utils"
            "lib32-nvidia-utils"
            "egl-wayland"
            "libva-nvidia-driver" # For VA-API hardware acceleration
            "qt5-wayland"
            "qt6-wayland"
        )
        install_packages "${PACKAGES_TO_INSTALL[@]}"

        # Configure modprobe for early KMS
        echo "options nvidia_drm modeset=1" | sudo tee /etc/modprobe.d/nvidia.conf >/dev/null

        # Configure mkinitcpio for early loading
        MKINITCPIO_CONF="/etc/mkinitcpio.conf"

        # Define modules
        NVIDIA_MODULES="nvidia nvidia_modeset nvidia_uvm nvidia_drm"

        # Create backup
        sudo cp "$MKINITCPIO_CONF" "${MKINITCPIO_CONF}.backup"

        # Remove any old nvidia modules to prevent duplicates
        sudo sed -i -E 's/ nvidia_drm//g; s/ nvidia_uvm//g; s/ nvidia_modeset//g; s/ nvidia//g;' "$MKINITCPIO_CONF"
        # Add the new modules at the start of the MODULES array
        sudo sed -i -E "s/^(MODULES=\\()/\\1${NVIDIA_MODULES} /" "$MKINITCPIO_CONF"
        # Clean up potential double spaces
        sudo sed -i -E 's/  +/ /g' "$MKINITCPIO_CONF"

        sudo mkinitcpio -P

        echo "NVIDIA drivers configured. Reboot to apply changes."
    else
        echo "No NVIDIA hardware detected. Skipping NVIDIA configuration."
    fi
}

# Stow dotfiles
stow_dotfiles() {
    echo "Stowing dotfiles..."
    cd ~/dotfiles
    stow -v -t ~ *  # Stow all subdirectories to home; adjust if needed (e.g., specific dirs like 'stow hyprland zsh')
    echo "Dotfiles stowed. If conflicts occurred, resolve them manually."
}

# Enable services
configure_services() {
    echo "Enabling services..."
    sudo systemctl enable sddm
    sudo systemctl enable NetworkManager
    sudo systemctl enable bluetooth
    sudo systemctl start bluetooth
}

# Sysctl hack for realistic copy times to flash drives
configure_sysctl() {
    echo "Configuring sysctl for vm.dirty_bytes..."
    sudo mkdir -p /etc/sysctl.d
    echo "vm.dirty_background_bytes=524288" | sudo tee /etc/sysctl.d/dirty.conf
    echo "vm.dirty_bytes=1048576" | sudo tee -a /etc/sysctl.d/dirty.conf
    sudo sysctl --load=/etc/sysctl.d/dirty.conf
}

# oh-my-zsh and plugins (post-zsh install)
install_oh_my_zsh() {
    echo "Installing oh-my-zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
    echo "Add 'plugins=(zsh-autosuggestions)' to ~/.zshrc"
}
