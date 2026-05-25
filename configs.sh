#!/bin/bash

# Set up SSH key for GitHub via gh CLI device flow (idempotent)
# Requires github-cli and openssh to be installed before this is called.
setup_ssh_key() {
    echo "Setting up SSH key for GitHub..."

    # Generate key if missing
    if [ ! -f ~/.ssh/id_ed25519 ]; then
        local KEY_COMMENT
        KEY_COMMENT="$(git config --global user.email 2>/dev/null || hostname)"
        ssh-keygen -t ed25519 -C "$KEY_COMMENT" -f ~/.ssh/id_ed25519 -N ""
    else
        echo "Existing SSH key found at ~/.ssh/id_ed25519. Skipping generation."
    fi

    eval "$(ssh-agent -s)" >/dev/null
    ssh-add ~/.ssh/id_ed25519 2>/dev/null || true

    # Authenticate gh if needed (device flow: one short code, one browser visit).
    # --skip-ssh-key: don't trigger gh's interactive key-upload prompt here; we
    # upload the key explicitly below. --scopes: needed for `gh ssh-key add`.
    if ! gh auth status -h github.com &>/dev/null; then
        echo "Launching gh device-flow login..."
        gh auth login --git-protocol ssh --hostname github.com --web \
            --scopes "admin:public_key" --skip-ssh-key
    fi

    # Register the public key on GitHub if not already present
    local KEY_TITLE="arch-setup-$(hostname)"
    if gh ssh-key list 2>/dev/null | grep -qF "$KEY_TITLE"; then
        echo "SSH key '$KEY_TITLE' already registered on GitHub. Skipping."
    else
        gh ssh-key add ~/.ssh/id_ed25519.pub --title "$KEY_TITLE"
    fi

    # Smoke test (don't fail the script on the GitHub "successful auth" non-zero exit)
    ssh -T -o StrictHostKeyChecking=accept-new git@github.com || true
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
            # -Syu (not bare -Sy): sync the newly enabled repo AND upgrade, so we
            # never install against a partially-synced DB (avoids broken deps).
            sudo pacman -Syu --noconfirm
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

# Stow dotfiles. The repo is a single flat package whose tree mirrors $HOME, so
# it's stowed with package "." from inside the repo (stow reads the dir itself,
# including hidden entries like .config/.zshrc). --adopt absorbs any pre-existing
# real files, then `git checkout` restores tracked content so the repo wins.
# NOTE: on re-runs this discards uncommitted edits inside ~/dotfiles.
stow_dotfiles() {
    echo "Stowing dotfiles..."
    cd ~/dotfiles
    stow --adopt -v -t ~ .
    git -C ~/dotfiles checkout -- .
    echo "Dotfiles stowed."
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

# Install oh-my-zsh framework + zsh-autosuggestions via plain git clones,
# avoiding the upstream installer (which writes a template ~/.zshrc and would
# clobber the stowed symlink). The dotfiles' .zshrc already loads oh-my-zsh.
install_oh_my_zsh() {
    echo "Installing oh-my-zsh..."
    if [ ! -d ~/.oh-my-zsh ]; then
        git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git ~/.oh-my-zsh
    fi

    local CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
    if [ ! -d "$CUSTOM/plugins/zsh-autosuggestions" ]; then
        git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions \
            "$CUSTOM/plugins/zsh-autosuggestions"
    fi
}
