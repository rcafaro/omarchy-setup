#!/usr/bin/env bash
###############################################################################
# Omarchy Fresh Build — Consolidated Automation Script
#
# Combines:
#   - Vault note "Omarchy fresh install steps" (base system, packages, plugins)
#   - ~/code/omarchy-build/pulse-omarchy/  (Pulse Secure launcher + sudoers)
#   - ~/code/omarchy-build/waydroid/       (Waydroid + bindfs + JW handler)
#   - ~/code/omarchy-build/install_fonts.sh (Windows fonts via SMB)
#
# PREREQUISITES:
#   • assets/ directory alongside this script containing:
#       os-release.kubuntu    (md5: 9e0dcb60cca740a8733d71ecd5a93f8d)
#       screensaver_logo.png  (Unagui logo for ASCII screensaver)
#       login_logo.png        (Unagui inverted logo for Plymouth boot screen)
#     Note: os-release.omarchy is captured live from /etc/os-release at runtime.
#   • SMB credentials for the font server (NAS, 192.168.200.201) — prompted at
#     runtime, section 12. Skip that step if you don't need Windows fonts.
#
# Usage: bash omarchy-fresh-build.sh
###############################################################################
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ASSETS_DIR="${SCRIPT_DIR}/assets"

# ── Network & host variables ───────────────────────────────────────────────
NAS_IP="nas.local"
LAN_SUBNET="192.168.200.0/24"
TAILSCALE_NET="100.64.0.0/10"

# ── SMB font server (NAS) ──────────────────────────────────────────────────
SMB_SERVER="${NAS_IP}"
SMB_SHARE_PATH="pool/installer/Apps/linux/windowsFonts"
SMB_USER=""          # Set your NAS username here, or skip section 12/13
SMB_PASS=""          # Set your NAS password here

# ── Tailscale IP of the NAS (for fstab CIFS mounts) ────────────────────────
NAS_TAILSCALE_IP=""   # e.g. "100.64.231.90" — leave empty to skip fstab mounts

# ── Paths ──────────────────────────────────────────────────────────────────
BUILD_DIR="${HOME}/.config/omarchy/plugins"  # for plugin paths
PULSE_DIR="${HOME}/pulse-omarchy"           # pulse scripts live here (copied during build)
UNAGUI_LOGO="${ASSETS_DIR}/screensaver_logo.png"
UNAGUI_LOGO_INV="${ASSETS_DIR}/login_logo.png"

# ── Verify required assets ────────────────────────────────────────────────
MISSING=0
for f in os-release.kubuntu screensaver_logo.png login_logo.png; do
    if [ ! -f "${ASSETS_DIR}/${f}" ]; then
        echo "Missing asset: ${ASSETS_DIR}/${f}"
        MISSING=1
    fi
done
if [ "$MISSING" -eq 1 ]; then
    echo "Place required files in ${ASSETS_DIR}/ and re-run." >&2
    exit 1
fi

# ─── Helpers ────────────────────────────────────────────────────────────────
section() { echo ""; echo "═══════════════════════════════════════"; echo "  $1"; echo "═══════════════════════════════════════"; }
echo()    { echo "[!] $*" >&2; }

###############################################################################
# 0. SECURITY & SSH
###############################################################################
section "0 — Security & SSH"
omarchy setup security sshd

###############################################################################
# 1. REMOVE UNWANTED WEBAPPS
###############################################################################
section "1 — Remove unwanted webapps"
for app in hey HEY X Basecamp "Google Messages" Zoom; do
    echo "Removing webapp: $app"
    omarchy webapp remove "$app"
done

###############################################################################
# 2. CORE PACKAGES (official repos)
###############################################################################
section "2 — Core packages (official)"
omarchy install browser brave-origin
omarchy install editor vscode
omarchy pkg add rclone corectl file-roller syncthing gnome-calendar nano remmina kdeconnect sunshine

# flea file manager
omarchy pkg add flea && flea --default

###############################################################################
# 3. AUR PACKAGES
###############################################################################
section "3 — AUR packages"
for pkg in todoist-appimage teams-for-linux-bin zoom arduino-ide-bin \
           epson-inkjet-printer-201207w epson-printer-utility \
           seafile-client bindfs; do
    echo "Installing from AUR: $pkg"
    omarchy pkg aur add "$pkg"
done

###############################################################################
# 4. SERVICES (user + system)
###############################################################################
section "4 — Enable services"
systemctl --user enable --now syncthing.service
sudo systemctl enable --now ecbd.service   # Epson printer daemon

###############################################################################
# 5. VOXTYPE (keyboard layout)
###############################################################################
section "5 — Voxtype"
omarchy voxtype install
omarchy voxtype config

###############################################################################
# 6. SERVICES: Tailscale, Spotify
###############################################################################
section "6 — Tailscale & Spotify"
omarchy install service tailscale
omarchy install service spotify

###############################################################################
# 7. PLUGINS
###############################################################################
section "7 — Plugins"

# OpenVPN
omarchy plugin add https://github.com/HcDuller/omarchy-vpn.git --enable

# Atrium (requires manual setup after)
omarchy plugin add https://github.com/bitshiftxr/atrium.git --enable
echo "[!] Run atrium setup manually: ${BUILD_DIR}/io.github.bitshiftxr.atrium/setup"

# Todoist
omarchy plugin add https://github.com/xak47d/omarchy-todoist.git --enable

# Activity Monitor
omarchy plugin add https://github.com/stappmus/omarchy-activity-monitor.git --enable

# Better Workspaces (replace default)
omarchy plugin add https://github.com/LukasTrust/betterWorkspaces.git --enable
omarchy plugin disable omarchy.workspaces

# Better Lock
omarchy plugin add https://github.com/BibekBhusal0/omarchy-better-lock.git --enable

# KDE Connect Quick Reply
#omarchy plugin add https://github.com/UnderStackDev/omarchy_kdeconnect_quick_reply.git --enable

#Foamy notifications
omarchy plugin add https://github.com/foamrider/foamy-notifications.git --enable

# OmaMigrate (with custom binding)
omarchy plugin add https://github.com/luneth90/omamigrate.git --enable
echo 'o.bind("SUPER + CTRL + M", "OmaMigrate", "omarchy-shell shell toggle luneth90.omamigrate")' \
    >> ~/.config/hypr/bindings.lua
omarchy restart shell

# KDE Connect plugin + firewall
omarchy plugin add https://github.com/seb-krz/omarchy-connect.git --enable
sudo ufw allow 1714:1764/tcp

# Rclone OneDrive
omarchy plugin add https://github.com/jason-watts/omarchy-rclone-onedrive.git --enable

###############################################################################
# 8. PULSE SECURE (full install + launcher)
###############################################################################
section "8 — Pulse Secure"

# Dependencies
omarchy pkg add gtkmm3
omarchy pkg aur add webkit2gtk
omarchy pkg aur add pulse-secure

# Patch PKGBUILD for latest version
PULSE_CACHE="${HOME}/.cache/yay/pulse-secure"
if [ -f "${PULSE_CACHE}/PKGBUILD" ]; then
    sed -i 's/pkgver=22\.8r5_b41063/pkgver=22.8r6_b44527/' "${PULSE_CACHE}/PKGBUILD"
    sed -i 's/ps-pulse-linux-22\.8r5-b41063-installer\.rpm/ps-pulse-linux-22.8r6-b44527-installer.rpm/' \
        "${PULSE_CACHE}/PKGBUILD"
    sed -i "s/md5sums_x86_64=('93a073f8ff0f30d71bb603388dadb417')/md5sums_x86_64=('1bc19c9d6f883d698af4c9f48de2f4a0')/" \
        "${PULSE_CACHE}/PKGBUILD"
    cd "${PULSE_CACHE}" && makepkg -si
else
    echo "PKGBUILD not found at ${PULSE_CACHE} — Pulse may already be installed."
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
    echo "Sudoers syntax error — skipping."
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

###############################################################################
# 9. WAYDROID
###############################################################################
section "9 — Waydroid"

omarchy pkg aur add waydroid binder_linux-dkms

# Load kernel module + persist across reboots
sudo modprobe binder_linux devices="binder,hwbinder,vndbinder"
echo "binder_linux" | sudo tee /etc/modules-load.d/waydroid.conf >/dev/null
echo 'options binder_linux devices="binder,hwbinder,vndbinder"' \
    | sudo tee /etc/modprobe.d/waydroid.conf >/dev/null

sudo systemctl restart waydroid-container
sudo waydroid init -s GAPPS

# Multi-window mode
waydroid session start
waydroid prop set persist.waydroid.multi_windows true

# Firewall for Waydroid (DHCP + DNS + FORWARD)
sudo ufw allow 67
sudo ufw allow 53
sudo ufw default allow FORWARD

# ── Bindfs mount: Waydroid Download → /mnt/waydroid ────────────────────────
DOWNLOAD_SRC="${HOME}/.local/share/waydroid/data/media/0/Download"
CURRENT_UID=$(id -u)
FSTAB_LINE="${DOWNLOAD_SRC}	/mnt/waydroid	fuse.bindfs	mirror=${CURRENT_UID},nofail,x-systemd.automount	0	0"

sudo mkdir -p /mnt/waydroid
if ! grep -qF "/mnt/waydroid" /etc/fstab 2>/dev/null; then
    echo "$FSTAB_LINE" | sudo tee -a /etc/fstab >/dev/null
    echo "   fstab entry added (UID ${CURRENT_UID})"
else
    echo "   /mnt/waydroid already in fstab — skipping."
fi

# ── JW Library URL handler ────────────────────────────────────────────────
cat > /tmp/waydroid-jwlibrary-handler << 'JW_HANDLER'
#!/bin/bash
URL="$1"
waydroid app intent android.intent.action.VIEW "$URL"
JW_HANDLER
sudo install -m 0755 /tmp/waydroid-jwlibrary-handler /usr/local/bin/waydroid-jwlibrary-handler
rm -f /tmp/waydroid-jwlibrary-handler

cat > ~/.local/share/applications/jwlibrary-url-handler.desktop << 'JW_DESKTOP'
[Desktop Entry]
Name=JW Library URL Handler
Exec=/usr/local/bin/waydroid-jwlibrary-handler %u
Type=Application
Terminal=false
MimeType=x-scheme-handler/jwlibrary;
JW_DESKTOP

xdg-mime default jwlibrary-url-handler.desktop x-scheme-handler/jwlibrary || true
VERIFIED=$(xdg-mime query default x-scheme-handler/jwlibrary 2>/dev/null || echo "<não verificado>")
echo "   JW handler verification: ${VERIFIED}"

###############################################################################
# 10. GAMING
###############################################################################
section "10 — Gaming"

omarchy install gaming steam
omarchy install gaming lutris
omarchy install gaming heroic
omarchy install gaming battlenet
omarchy install gaming xbox-controllers

# Sunshine firewall (local LAN + Tailscale)
sudo ufw allow from "${LAN_SUBNET}" to any port 47984,47989,47990,48010 proto tcp
sudo ufw allow from "${LAN_SUBNET}" to any port 47998,47999,48000,48010 proto udp
sudo ufw allow from "${TAILSCALE_NET}"   to any port 47984,47989,47990,48010 proto tcp
sudo ufw allow from "${TAILSCALE_NET}"   to any port 47998,47999,48000,48010 proto udp
sudo ufw reload

###############################################################################
# 11. BRANDING (screensaver + boot screen)
###############################################################################
section "11 — Branding"

if [ -f "$UNAGUI_LOGO" ]; then
    omarchy transcode ascii "$UNAGUI_LOGO" \
        ~/.config/omarchy/branding/screensaver.txt --width 80
else
    echo "Unagui logo not found at $UNAGUI_LOGO — skipping screensaver."
fi

if [ -f "$UNAGUI_LOGO_INV" ]; then
    omarchy plymouth set '#000000' '#aa90cf' "$UNAGUI_LOGO_INV"
else
    echo "Unagui logo (inverted) not found — skipping boot screen."
fi

###############################################################################
# 12. WINDOWS FONTS (SMB from NAS)
###############################################################################
section "12 — Windows fonts (optional, requires SMB credentials)"

read -rp "Install Windows fonts from NAS? [y/N] " FONT_ANSWER
if [[ "$FONT_ANSWER" =~ ^[Yy]$ ]]; then
    if [ -z "${SMB_USER}" ]; then
        read -rp "NAS SMB username: " SMB_USER
        read -rsp "NAS SMB password: " SMB_PASS
        echo ""
    fi

    TMP_DIR=$(mktemp -d)
    trap "rm -rf $TMP_DIR" EXIT

    smbclient "//${SMB_SERVER}/${SMB_SHARE_PATH}" \
        -U "${SMB_USER}%${SMB_PASS}" \
        -c 'prompt; mget *' -o "$TMP_DIR" 2>/dev/null || {
        echo "Failed to fetch fonts from SMB share."
    }

    FONT_COUNT=$(find "$TMP_DIR" -maxdepth 1 \
        \( -iname '*.ttf' -o -iname '*.otf' -o -iname '*.woff' -o -iname '*.woff2' \) | wc -l)

    if [ "$FONT_COUNT" -gt 0 ]; then
        mkdir -p "${HOME}/.local/share/fonts"
        find "$TMP_DIR" -maxdepth 1 \
            \( -iname '*.ttf' -o -iname '*.otf' -o -iname '*.woff' -o -iname '*.woff2' \) \
            -exec mv {} "${HOME}/.local/share/fonts/" \;
        fc-cache -fv "${HOME}/.local/share/fonts" >/dev/null
        echo "   ✓ ${FONT_COUNT} font(s) installed."
    else
        echo "No font files found in the share."
    fi
else
    echo "   Skipping fonts."
fi

###############################################################################
# 13. Set VS Code as default text editor (mimeapps.list)
###############################################################################
section "Setting VS Code as default for text/* and shell scripts"

MIMEAPPS_FILE="${HOME}/.config/mimeapps.list"
if [ -f "${MIMEAPPS_FILE}" ]; then
    cp "${MIMEAPPS_FILE}" "${MIMEAPPS_FILE}.bak.$(date +%Y%m%d%H%M%S)"
fi

# Add code.desktop as default for text/* and application/x-shellscript
mkdir -p "$(dirname "${MIMEAPPS_FILE}")"
if ! grep -q "code\.desktop" "${MIMEAPPS_FILE}" 2>/dev/null; then
    cat >> "${MIMEAPPS_FILE}" <<'EOF'

[Default Applications]
text/plain=code.desktop
text/x-shellscript=code.desktop
text/x-python=code.desktop
text/html=code.desktop
text/xml=code.desktop
text/css=code.desktop
text/csv=code.desktop
application/json=code.desktop
application/javascript=code.desktop
EOF
    echo "   mimeapps.list updated with code.desktop defaults."
else
    echo "code.desktop already present in mimeapps.list — skipping."
fi

update-desktop-database "${HOME}/.local/share/applications" 2>/dev/null || true

# Verify
for mime in text/plain text/x-shellscript text/x-python; do
    result=$(gio mime "$mime" 2>/dev/null)
    if [[ "$result" == *"code.desktop"* ]]; then
        echo "   ✓ ${mime} → code.desktop"
    else
        echo "${mime} → ${result:-unknown}"
    fi
done

###############################################################################
# 14. Mount NAS shares (pool + media) via Tailscale — fstab entries
###############################################################################
section "Mounting NAS shares via fstab"

if [ -z "${NAS_TAILSCALE_IP}" ]; then
    echo "NAS_TAILSCALE_IP not set — skipping fstab mounts."
else
    if ! grep -q "//${NAS_TAILSCALE_IP}/pool" /etc/fstab 2>/dev/null; then
        sudo mkdir -p /mnt/pool /mnt/media

        if [ -z "${SMB_USER}" ]; then
            read -rp "NAS username: " FSTAB_USER
            read -rsp "NAS password: " FSTAB_PASS
            echo ""
        else
            FSTAB_USER="${SMB_USER}"
            FSTAB_PASS="${SMB_PASS}"
        fi

        cat <<FSTAB | sudo tee -a /etc/fstab
//${NAS_TAILSCALE_IP}/pool   /mnt/pool   cifs   x-systemd.automount,x-systemd.idle-timeout=60,soft,nofail,username=${FSTAB_USER},password=${FSTAB_PASS},uid=1000,gid=1000,iocharset=utf8,file_mode=0775,dir_mode=0775,nomapposix,cache=none   0 0
//${NAS_TAILSCALE_IP}/media  /mnt/media  cifs   x-systemd.automount,x-systemd.idle-timeout=60,soft,nofail,username=${FSTAB_USER},password=${FSTAB_PASS},uid=1000,gid=1000,iocharset=utf8,file_mode=0775,dir_mode=0775,nomapposix,cache=none   0 0
FSTAB

        sudo mount -a 2>/dev/null && echo "   ✓ NAS shares mounted." || echo "mount -a failed — check credentials."
    else
        echo "NAS fstab entries already present — skipping."
    fi
fi

###############################################################################
# DONE
###############################################################################
section "Build complete"
echo ""
echo "Remaining manual steps:"
echo "  • Atrium setup: ${PULSE_DIR}/io.github.bitshiftxr.atrium/setup"
echo "  • DaVinci Resolve: download AppImage, double-click (no sudo)"
echo "  • Photopea PWA: install from browser"
echo "  • Consider: https://github.com/ReidenXerx/omarchy-tile-blueprints"
echo ""
