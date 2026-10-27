#!/usr/bin/env bash
# Section 3 — AUR packages
# Standalone: bash sections/03-aur-packages.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_lib.sh"

section "3 — AUR packages"
for pkg in todoist-appimage teams-for-linux-bin zoom arduino-ide-bin \
           epson-inkjet-printer-201207w epson-printer-utility \
           seafile-client bindfs hyprmon-bin remmina-plugin-rdesktop \
           artcraft-launcher-appimage; do
    echo "Installing from AUR: $pkg"
    try omarchy pkg aur add "$pkg"
done

mark_section_done "$(basename "${BASH_SOURCE[0]}" .sh)"
