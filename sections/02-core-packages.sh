#!/usr/bin/env bash
# Section 2 — Core packages (official repos)
# Standalone: bash sections/02-core-packages.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_lib.sh"

section "2 — Core packages (official)"
try omarchy install browser brave-origin
try omarchy install editor vscode
try omarchy pkg add rclone 
try omarchy pkg add corectrl 
try omarchy pkg add file-roller
try omarchy pkg add syncthing
try omarchy pkg add gnome-calendar
try omarchy pkg add nano
try omarchy pkg add remmina
try omarchy pkg add kdeconnect
try omarchy pkg add sunshine
try omarchy pkg add flatpak
try omarchy pkg add thunderbird

# flea file manager
try omarchy pkg add flea
try flea --default

mark_section_done "$(basename "${BASH_SOURCE[0]}" .sh)"
