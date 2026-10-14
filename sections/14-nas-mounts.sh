#!/usr/bin/env bash
# Section 14 — Mount NAS shares (pool + media) via fstab
# Server: Tailscale IP if configured, else the LAN name (NAS_IP).
# Standalone: bash sections/14-nas-mounts.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_lib.sh"

section "Mounting NAS shares via fstab"

if [ -z "${MOUNT_SERVER}" ]; then
    echo "No NAS server configured (NAS_IP and NAS_TAILSCALE_IP both empty) — skipping."
else
    if ! grep -q "//${MOUNT_SERVER}/pool" /etc/fstab 2>/dev/null; then
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
//${MOUNT_SERVER}/pool   /mnt/pool   cifs   x-systemd.automount,x-systemd.idle-timeout=60,soft,nofail,username=${FSTAB_USER},password=${FSTAB_PASS},uid=1000,gid=1000,iocharset=utf8,file_mode=0775,dir_mode=0775,nomapposix,cache=none   0 0
//${MOUNT_SERVER}/media  /mnt/media  cifs   x-systemd.automount,x-systemd.idle-timeout=60,soft,nofail,username=${FSTAB_USER},password=${FSTAB_PASS},uid=1000,gid=1000,iocharset=utf8,file_mode=0775,dir_mode=0775,nomapposix,cache=none   0 0
FSTAB

        sudo mount -a 2>/dev/null && echo "   ✓ NAS shares mounted (server: ${MOUNT_SERVER})." || echo "mount -a failed — check credentials."
    else
        echo "NAS fstab entries already present for ${MOUNT_SERVER} — skipping."
    fi
fi

mark_section_done "$(basename "${BASH_SOURCE[0]}" .sh)"
