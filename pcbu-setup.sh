#!/bin/bash
# Optional module: PC Bio Unlock (unlock this PC with your phone's
# fingerprint/face over sudo, lock screens, and polkit prompts).
#
# Not run automatically by setup.sh — pairing your phone requires clicking
# through the app's own GUI, so this can't be fully unattended. Run this
# script by hand whenever you're ready:
#   ./pcbu-setup.sh
#
# What it does, in order:
#   1. Downloads the latest Linux AppImage and launches its installer.
#      -> You pair your phone and tick the sudo/polkit/login-manager
#         integration boxes yourself in that GUI.
#   2. Once you're done in the GUI, patches sudo/gtklock/hyprlock/polkit-1
#      so a normal password always works instantly, with the phone only
#      used as a fallback if the password is wrong/empty. Without this,
#      those prompts block on the phone first with no way to type instead.
#      (sddm gets this pattern automatically from pcbu's own installer.)
#   3. Adds a udev rule so pcbu's Ctrl+Alt cancel shortcut also works
#      through kanata (kanata grabs the real keyboard exclusively and
#      re-emits key events on its own virtual device, which pcbu's raw
#      evdev scanner can't see without this symlink). Harmless/inert if
#      kanata isn't set up.

set -e

install_pcbu() {
    echo "Downloading PC Bio Unlock..."
    local URL
    URL=$(curl -s "https://api.github.com/repos/MeisApps/pcbu-desktop/releases/latest" \
        | grep -o '"browser_download_url": *"[^"]*PCBioUnlock-x64\.AppImage"' \
        | cut -d'"' -f4)
    if [ -z "$URL" ]; then
        echo "Could not find the AppImage download URL. Aborting." >&2
        return 1
    fi

    mkdir -p ~/Downloads
    curl -L -o ~/Downloads/PCBioUnlock-x64.AppImage "$URL"
    chmod +x ~/Downloads/PCBioUnlock-x64.AppImage

    echo ""
    echo "Launching the installer GUI. In it:"
    echo "  - Pair your phone (QR code or pairing code)"
    echo "  - Under Linux settings, tick 'Enable sudo integration',"
    echo "    'Enable polkit integration' and 'Enable login manager integration'"
    echo "Close the app when you're done."
    ~/Downloads/PCBioUnlock-x64.AppImage
}

# Prepend "try the real password first, phone only as fallback" to a
# PAM file that pcbu's installer already patched with a bare
# `auth sufficient pam_pcbiounlock.so` line. Idempotent and a no-op if
# that line isn't there yet (integration box wasn't ticked) or the
# fallback is already wired in.
patch_pcbu_dual_auth() {
    local FILE=$1
    if [ ! -f "$FILE" ]; then
        echo "  $FILE not found, skipping."
        return
    fi
    if ! grep -q "pam_pcbiounlock.so" "$FILE"; then
        echo "  $FILE has no pcbu line yet (integration box not ticked?), skipping."
        return
    fi
    if grep -q "pam_unix.so try_first_pass likeauth nullok" "$FILE"; then
        echo "  $FILE already has the password-first fallback, skipping."
        return
    fi
    sudo cp "$FILE" "$FILE.bak"
    sudo sed -i '/pam_pcbiounlock\.so/i auth\t\t[success=1 default=ignore]\tpam_unix.so try_first_pass likeauth nullok' "$FILE"
    echo "  Patched $FILE (backup at $FILE.bak)."
}

configure_pcbu_dual_auth() {
    echo "Wiring password-first / phone-fallback into PAM..."
    for f in /etc/pam.d/sudo /etc/pam.d/gtklock /etc/pam.d/hyprlock /etc/pam.d/polkit-1; do
        patch_pcbu_dual_auth "$f"
    done
}

# Lets pcbu's Ctrl+Alt cancel shortcut see keypresses through kanata.
install_pcbu_kanata_compat() {
    echo "Adding pcbu/kanata compatibility udev rule..."
    local RULE=/etc/udev/rules.d/99-pcbu-kanata-kbd.rules
    if [ ! -f "$RULE" ]; then
        echo 'SUBSYSTEM=="input", KERNEL=="event*", ATTRS{name}=="kanata", SYMLINK+="input/by-path/virtual-kanata-event-kbd"' | sudo tee "$RULE" >/dev/null
        sudo udevadm control --reload
        sudo udevadm trigger --subsystem-match=input
    fi
}

install_pcbu
read -rp $'\nPress Enter once pairing + integration checkboxes are done in the GUI... '
configure_pcbu_dual_auth
install_pcbu_kanata_compat

echo ""
echo "PC Bio Unlock setup complete."
