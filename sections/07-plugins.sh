#!/usr/bin/env bash
# Section 7 — Plugins
# Standalone: bash sections/07-plugins.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_lib.sh"

section "7 — Plugins"

# OpenVPN
try omarchy plugin add https://github.com/HcDuller/omarchy-vpn.git --enable

# Atrium (requires manual setup after)
try omarchy plugin add https://github.com/bitshiftxr/atrium.git --enable
echo "[!] Run atrium setup manually: ${BUILD_DIR}/io.github.bitshiftxr.atrium/setup"

# Todoist
try omarchy plugin add https://github.com/xak47d/omarchy-todoist.git --enable

# Activity Monitor
try omarchy plugin add https://github.com/stappmus/omarchy-activity-monitor.git --enable

# Better Workspaces (replace default)
try omarchy plugin add https://github.com/LukasTrust/betterWorkspaces.git --enable
omarchy plugin disable omarchy.workspaces

# Better Lock
try omarchy plugin add https://github.com/BibekBhusal0/omarchy-better-lock.git --enable

# KDE Connect Quick Reply
#omarchy plugin add https://github.com/UnderStackDev/omarchy_kdeconnect_quick_reply.git --enable

#Foamy notifications
try omarchy plugin add https://github.com/foamrider/foamy-notifications.git --enable

# OmaMigrate (with custom binding)
try omarchy plugin add https://github.com/luneth90/omamigrate.git --enable
echo 'o.bind("SUPER + CTRL + M", "OmaMigrate", "omarchy-shell shell toggle luneth90.omamigrate")' \
    >> ~/.config/hypr/bindings.lua
omarchy restart shell

# KDE Connect plugin + firewall
try omarchy plugin add https://github.com/seb-krz/omarchy-connect.git --enable
sudo ufw allow 1714:1764/tcp

# Rclone OneDrive
try omarchy plugin add https://github.com/jason-watts/omarchy-rclone-onedrive.git --enable
