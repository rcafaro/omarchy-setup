#!/usr/bin/env bash
# Section 11 — Branding (screensaver + boot screen)
# Standalone: bash sections/11-branding.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_lib.sh"

section "11 — Branding"

if [ -f "$UNAGUI_LOGO" ]; then
    omarchy transcode ascii "$UNAGUI_LOGO" \
        ~/.config/omarchy/branding/screensaver.txt --width 80
else
    warn "Unagui logo not found at $UNAGUI_LOGO — skipping screensaver."
fi

if [ -f "$UNAGUI_LOGO_INV" ]; then
    omarchy plymouth set '#000000' '#aa90cf' "$UNAGUI_LOGO_INV"
else
    warn "Unagui logo (inverted) not found — skipping boot screen."
fi

mark_section_done "$(basename "${BASH_SOURCE[0]}" .sh)"
