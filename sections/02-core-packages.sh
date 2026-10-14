#!/usr/bin/env bash
# Section 2 — Core packages (official repos)
# Standalone: bash sections/02-core-packages.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_lib.sh"

section "2 — Core packages (official)"
try omarchy install browser brave-origin
try omarchy install editor vscode
try omarchy pkg add rclone corectrl file-roller syncthing gnome-calendar nano remmina kdeconnect sunshine
# separate line: one bad name must not sink the whole transaction (pacman validates all targets up front)
try omarchy pkg add thunderbird

# flea file manager
try omarchy pkg add flea
try flea --default

mark_section_done "$(basename "${BASH_SOURCE[0]}" .sh)"
