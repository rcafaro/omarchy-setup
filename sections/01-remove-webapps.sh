#!/usr/bin/env bash
# Section 1 — Remove unwanted webapps
# Standalone: bash sections/01-remove-webapps.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_lib.sh"

section "1 — Remove unwanted webapps"
for app in hey HEY X Basecamp "Google Messages" Zoom; do
    echo "Removing webapp: $app"
    try omarchy webapp remove "$app"
done
