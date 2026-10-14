#!/usr/bin/env bash
# Section 9 — Waydroid (container + bindfs + JW Library URL handler)
# Standalone: bash sections/09-waydroid.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_lib.sh"

section "9 — Waydroid"

try omarchy pkg aur add waydroid binder_linux-dkms

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
FSTAB_LINE="${DOWNLOAD_SRC}\t/mnt/waydroid\tfuse.bindfs\tmirror=${CURRENT_UID},nofail,x-systemd.automount\t0\t0"

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
