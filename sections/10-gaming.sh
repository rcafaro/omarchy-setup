#!/usr/bin/env bash
# Section 10 — Gaming (Steam/Lutris/Heroic + Sunshine firewall)
# Standalone: bash sections/10-gaming.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_lib.sh"

# Standalone guard: the orchestrator skips gaming on laptop profiles, so exit
# here only ever fires on a direct run. No state mark — desktop re-runs work.
resolve_device_type
if [[ "${DEVICE_TYPE}" == "laptop" ]]; then
    echo "   Gaming skipped on laptop profile."
    exit 0
fi

section "10 — Gaming"

try omarchy install gaming steam
try omarchy install gaming lutris
try omarchy install gaming heroic
try omarchy install gaming battlenet
try omarchy install gaming xbox-controllers

# Sunshine firewall (local LAN + Tailscale)
sudo ufw allow from "${LAN_SUBNET}" to any port 47984,47989,47990,48010 proto tcp
sudo ufw allow from "${LAN_SUBNET}" to any port 47998,47999,48000,48010 proto udp
sudo ufw allow from "${TAILSCALE_NET}"   to any port 47984,47989,47990,48010 proto tcp
sudo ufw allow from "${TAILSCALE_NET}"   to any port 47998,47999,48000,48010 proto udp
sudo ufw reload

mark_section_done "$(basename "${BASH_SOURCE[0]}" .sh)"
