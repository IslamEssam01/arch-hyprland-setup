# arch-hyprland-setup

Bootstraps a Hyprland desktop on a fresh Arch install: installs the AUR helper
(`yay`), all packages, NVIDIA drivers (if detected), services, and symlinks
dotfiles from a separate dotfiles repo via GNU Stow.

## Usage

On a fresh Arch system, logged in as your regular user:

```sh
sudo pacman -S --needed git
git clone https://github.com/IslamEssam01/arch-hyprland-setup.git
cd arch-hyprland-setup
./setup.sh
```

The only interactive step is the GitHub device-code prompt from `gh auth login`
(a single short code to paste into github.com/login/device). Everything else is
non-interactive — reboot when it finishes.

## Configuration

- `DOTFILES_REPO` — override the dotfiles source. Defaults to
  `git@github.com:IslamEssam01/dotfiles.git`. Example:

  ```sh
  DOTFILES_REPO=git@github.com:youruser/dotfiles.git ./setup.sh
  ```

## What it does

1. Installs prerequisites (`git`, `base-devel`, `openssh`, `github-cli`, `stow`).
2. Generates an Ed25519 SSH key and registers it on GitHub via `gh` device flow.
3. Clones the dotfiles repo to `~/dotfiles`.
4. Bootstraps `yay`, then installs core / Hyprland / audio / fonts packages.
5. Detects NVIDIA hardware and configures DKMS drivers + early KMS if present.
6. Installs `oh-my-zsh` and `zsh-autosuggestions` (plain git clones — does not
   write a template `.zshrc`, so the stowed one stays in effect).
7. Stows dotfiles from `~/dotfiles` into `$HOME` using `stow --adopt` (absorbs
   any pre-existing conflicts, then `git checkout` restores tracked content).
8. Enables `sddm`, `NetworkManager`, `bluetooth`.
9. Drops a `vm.dirty_bytes` sysctl tweak.

Re-running is safe: every step is idempotent.

## tlp.conf

`tlp.conf` in this repo is a **reference template only** — it is not copied
anywhere by `setup.sh`. If you want power management, install `tlp` separately
and copy this file to `/etc/tlp.conf`.
