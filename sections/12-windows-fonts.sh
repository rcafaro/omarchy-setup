#!/usr/bin/env bash
# Section 12 — Windows fonts (SMB from NAS)
# Decision + credentials come from the orchestrator's upfront block; standalone
# runs resolve their own defaults (env > ini > ask). No mid-run prompts.
# Standalone: bash sections/12-windows-fonts.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_lib.sh"

resolve_fonts_choice
collect_smb_creds   # no-op when credentials present or stdin is not a TTY

section "12 — Windows fonts (optional, requires SMB credentials)"

if [[ "${INSTALL_FONTS}" != "1" ]]; then
    echo "   Skipping fonts."
elif [ -z "${SMB_USER}" ] || [ -z "${SMB_PASS}" ]; then
    warn "No SMB credentials — skipping fonts (set in omarchy-build.ini or answer the upfront prompt)."
else
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
        # Only a successful fetch burns the state mark — an empty/failed share
        # stays retryable on the next run.
        mark_section_done "$(basename "${BASH_SOURCE[0]}" .sh)"
    else
        warn "No font files found in the share (will retry next run)."
    fi
fi
