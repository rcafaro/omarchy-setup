#!/usr/bin/env bash
# Section 4 — Enable services (user + system)
# Standalone: bash sections/04-services.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_lib.sh"

section "4 — Enable services"
systemctl --user enable --now syncthing.service
sudo systemctl enable --now ecbd.service   # Epson printer daemon
