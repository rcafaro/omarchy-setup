#!/usr/bin/env bash
# Section 14 — Mount NAS shares (pool + media) via Tailscale — fstab entries
# Standalone: bash sections/14-nas-mounts.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_lib.sh"

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
