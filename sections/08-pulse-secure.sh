#!/usr/bin/env bash
# Section 8 — Pulse Secure (full install + launcher)
# Standalone: bash sections/08-pulse-secure.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_lib.sh"

section "8 — Pulse Secure"

# Dependencies
try omarchy pkg add gtkmm3

# WebKitGTK: prefer the prebuilt package shipped in assets/ (saves HOURS of
# source compilation). Fall back to an AUR build only if it can't be installed.
WEBKIT_PKG="$(ls -1 "${ASSETS_DIR}/webkit2gtk/"*.pkg.tar.zst 2>/dev/null | head -n1)"
if [ -n "${WEBKIT_PKG}" ]; then
    if sudo pacman -U --noconfirm "${WEBKIT_PKG}"; then
        echo "   Installed prebuilt webkit2gtk from ${WEBKIT_PKG}"
    else
        warn "Prebuilt webkit2gtk install failed — building from AUR source instead."
        try omarchy pkg aur add webkit2gtk
    fi
else
    echo "   No prebuilt webkit2gtk in assets/ — building from AUR source (this takes HOURS)."
    try omarchy pkg aur add webkit2gtk
fi

try omarchy pkg aur add pulse-secure

# Patch PKGBUILD for latest version
PULSE_CACHE="${HOME}/.cache/yay/pulse-secure"
if [ -f "${PULSE_CACHE}/PKGBUILD" ]; then
    sed -i 's/pkgver=22\.8r5_b41063/pkgver=22.8r6_b44527/' "${PULSE_CACHE}/PKGBUILD"
    sed -i 's/ps-pulse-linux-22\.8r5-b41063-installer\.rpm/ps-pulse-linux-22.8r6_b44527-installer.rpm/' \
        "${PULSE_CACHE}/PKGBUILD"
    sed -i "s/md5sums_x86_64=('93a073f8ff0f30d71bb603388dadb417')/md5sums_x86_64=('1bc19c9d6f883d698af4c9f48de2f4a0')/" \
        "${PULSE_CACHE}/PKGBUILD"
    ( cd "${PULSE_CACHE}" && makepkg -si )   # subshell: don't leak cwd into later modules
else
    warn "PKGBUILD not found at ${PULSE_CACHE} — Pulse may already be installed."
fi

sudo systemctl daemon-reload
sudo systemctl enable --now pulsesecure

# ── Install launcher (os-release swap + sudoers + .desktop) ────────────────
mkdir -p "${PULSE_DIR}"

# Copy os-release profiles into pulse-omarchy/
sudo cp /etc/os-release "${PULSE_DIR}/os-release.omarchy"   # live snapshot of this system
cp "${ASSETS_DIR}/os-release.kubuntu" "${PULSE_DIR}/os-release.kubuntu"

# Write launcher script
cat > "${PULSE_DIR}/launch-pulse.sh" << 'LAUNCHER'
#!/bin/bash
set -euo pipefail

PULSE_DIR="$HOME/pulse-omarchy"
OS_RELEASE="/etc/os-release"
BACKUP_OS="${PULSE_DIR}/os-release.backup"

cleanup() {
    echo "[pulse-launcher] Stopping pulsesecure service..."
    sudo systemctl stop pulsesecure.service 2>/dev/null || true
    echo "[pulse-launcher] Restoring Omarchy os-release..."
    if [ -f "$BACKUP_OS" ]; then
        sudo cp "$BACKUP_OS" "$OS_RELEASE"
        rm -f "$BACKUP_OS"
    fi
    # Safety net: ensure canonical copy exists
    if [ ! -f "${PULSE_DIR}/os-release.omarchy" ] || \
       ! cmp -s "${PULSE_DIR}/os-release.omarchy" "$OS_RELEASE"; then
        sudo cp "$OS_RELEASE" "${PULSE_DIR}/os-release.omarchy" 2>/dev/null || true
    fi
    echo "[pulse-launcher] Cleanup complete."
}

trap cleanup EXIT

echo "[pulse-launcher] Backing up /etc/os-release..."
sudo cp "$OS_RELEASE" "$BACKUP_OS"
echo "[pulse-launcher] Swapping to Kubuntu profile..."
sudo cp "${PULSE_DIR}/os-release.kubuntu" "$OS_RELEASE"
echo "[pulse-launcher] Starting pulsesecure..."
sudo systemctl start pulsesecure.service
echo "[pulse-launcher] Launching Pulse UI..."
/opt/pulsesecure/bin/pulseUI &
wait $! 2>/dev/null || true
LAUNCHER
chmod +x "${PULSE_DIR}/launch-pulse.sh"

# Sudoers drop-in (NOPASSWD for launcher commands only)
SUDOERS_CONTENT="# NOPASSWD for Ivanti Pulse launcher (${PULSE_DIR}/launch-pulse.sh)
${USER} ALL=(ALL) NOPASSWD: /usr/bin/systemctl start pulsesecure.service
${USER} ALL=(ALL) NOPASSWD: /usr/bin/systemctl stop pulsesecure.service
${USER} ALL=(ALL) NOPASSWD: /bin/cp ${PULSE_DIR}/os-release.kubuntu /etc/os-release
${USER} ALL=(ALL) NOPASSWD: /bin/cp /etc/os-release ${PULSE_DIR}/os-release.backup
${USER} ALL=(ALL) NOPASSWD: /bin/cp ${PULSE_DIR}/os-release.backup /etc/os-release
${USER} ALL=(ALL) NOPASSWD: /bin/cp /etc/os-release ${PULSE_DIR}/os-release.omarchy"

TMPFILE=$(mktemp)
echo "$SUDOERS_CONTENT" > "$TMPFILE"
if ! visudo -cf "$TMPFILE" &>/dev/null; then
    warn "Sudoers syntax error — skipping."
    rm -f "$TMPFILE"; exit 1
fi
sudo cp "$TMPFILE" /etc/sudoers.d/pulse
sudo chown root:root /etc/sudoers.d/pulse
sudo chmod 0440 /etc/sudoers.d/pulse
rm -f "$TMPFILE"

# Desktop entry
mkdir -p "${HOME}/.local/share/applications"
cat > "${HOME}/.local/share/applications/pulse.desktop" << DESKTOP
[Desktop Entry]
Version=1.0
Name=Ivanti Secure Access Client
Comment=Ivanti Secure Access Client for Linux
Exec=${PULSE_DIR}/launch-pulse.sh
Icon=/opt/pulsesecure/resource/ivanti.png
Terminal=false
Type=Application
Categories=Network;Security;
StartupWMClass=pulseUI
Keywords=Pulse;Ivanti;ISAC;VPN;
DESKTOP

mark_section_done "$(basename "${BASH_SOURCE[0]}" .sh)"
