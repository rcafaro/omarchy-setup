#!/usr/bin/env bash
# Section 6 — Tailscale & Spotify
# Standalone: bash sections/06-tailscale-spotify.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_lib.sh"

# Ask (or honor env/orchestrator decision) if not already resolved.
resolve_tailscale_choice

section "6 — Tailscale & Spotify"
if [[ "${INSTALL_TAILSCALE}" == "1" ]]; then
    if systemctl is-active --quiet tailscaled && omarchy-pkg-present tailscale; then
        echo "   Tailscale already active — skipping."
    else
        try omarchy install service tailscale
    fi
else
    echo "   Tailscale not installed (declined at start or SKIP_TAILSCALE=1)."
fi
try omarchy install service spotify
