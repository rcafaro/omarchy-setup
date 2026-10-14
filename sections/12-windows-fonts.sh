#!/usr/bin/env bash
# Section 12 — Windows fonts (SMB from NAS)
# Standalone: bash sections/12-windows-fonts.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_lib.sh"

section "12 — Windows fonts (optional, requires SMB credentials)"

read -rp "Install Windows fonts from NAS? [y/N] " FONT_ANSWER
if [[ "$FONT_ANSWER" =~ ^[Yy]$ ]]; then
    if [ -z "${SMB_USER}" ]; then
        read -rp "NAS SMB username: " SMB_USER
        read -rsp "NAS SMB password: " SMB_PASS
        echo ""
    fi

    TMP_DIR=$(mktemp -d)
    trap "rm -rf $TMP_DIR" EXIT

    smbclient "//${SMB_SERVER}/${SMB_SHARE_PATH}" \
        -U "${SMB_USER}%${SMB_PASS}" \
        -c 'prompt; mget *' -o "$TMP_DIR" 2>/dev/null || {
        warn "Failed to fetch fonts from SMB share."
    }

    FONT_COUNT=$(find "$TMP_DIR" -maxdepth 1 \
        \( -iname '*.ttf' -o -iname '*.otf' -o -iname '*.woff' -o -iname '*.woff2' \) | wc -l)

    if [ "$FONT_COUNT" -gt 0 ]; then
        mkdir -p "${HOME}/.local/share/fonts"
        find "$TMP_DIR" -maxdepth 1 \
            \( -iname '*.ttf' -o -iname '*.otf' -o -iname '*.woff' -o -iname '*.woff2' \) \
            -exec mv {} "${HOME}/.local/share/fonts/" \;
        fc-cache -fv "${HOME}/.local/share/fonts" >/dev/null
        echo "   ✓ ${FONT_COUNT} font(s) installed."
    else
        warn "No font files found in the share."
    fi
else
    echo "   Skipping fonts."
fi

mark_section_done "$(basename "${BASH_SOURCE[0]}" .sh)"
