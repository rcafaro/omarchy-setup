#!/usr/bin/env bash
# Section 2 — Core packages (official repos)
# Standalone: bash sections/02-core-packages.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_lib.sh"

section "2 — Core packages (official)"
try omarchy install browser brave-origin
try omarchy install editor vscode
try omarchy pkg add rclone corectrl file-roller syncthing gnome-calendar nano remmina kdeconnect sunshine

# flea file manager
try omarchy pkg add flea
try flea --default
