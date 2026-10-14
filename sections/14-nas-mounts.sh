#!/usr/bin/env bash
# Section 14 — Mount NAS shares (pool + media) via fstab
# Server: Tailscale IP if configured, else the LAN name (NAS_IP).
# Credentials come from omarchy-build.ini or the orchestrator's upfront prompt;
# no mid-run reads. Standalone: bash sections/14-nas-mounts.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_lib.sh"

section "Mounting NAS shares via fstab"

if [ -z "${MOUNT_SERVER}" ]; then
    echo "No NAS server configured (NAS_IP and NAS_TAILSCALE_IP both empty) — skipping."
elif [ -z "${SMB_USER}" ] || [ -z "${SMB_PASS}" ]; then
    warn "No SMB credentials — skipping mounts (set in omarchy-build.ini or answer the upfront prompt)."
else
    if ! grep -q "//${MOUNT_SERVER}/pool" /etc/fstab 2>/dev/null; then
        sudo mkdir -p /mnt/pool /mnt/media

        cat <<FSTAB | sudo tee -a /etc/fstab
//${MOUNT_SERVER}/pool   /mnt/pool   cifs   x-systemd.automount,x-systemd.idle-timeout=60,soft,nofail,username=${SMB_USER},password=${SMB_PASS},uid=1000,gid=1000,iocharset=utf8,file_mode=0775,dir_mode=0775,nomapposix,cache=none   0 0
//${MOUNT_SERVER}/media  /mnt/media  cifs   x-systemd.automount,x-systemd.idle-timeout=60,soft,nofail,username=${SMB_USER},password=${SMB_PASS},uid=1000,gid=1000,iocharset=utf8,file_mode=0775,dir_mode=0775,nomapposix,cache=none   0 0
FSTAB

        sudo mount -a 2>/dev/null && echo "   ✓ NAS shares mounted (server: ${MOUNT_SERVER})." || warn "mount -a failed — check credentials."
    else
        echo "NAS fstab entries already present for ${MOUNT_SERVER} — skipping."
    fi

    mark_section_done "$(basename "${BASH_SOURCE[0]}" .sh)"
fi
