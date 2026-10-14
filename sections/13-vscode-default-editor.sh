#!/usr/bin/env bash
# Section 13 — Set VS Code as default text editor (mimeapps.list)
# Standalone: bash sections/13-vscode-default-editor.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_lib.sh"

section "Setting VS Code as default for text/* and shell scripts"

MIMEAPPS_FILE="${HOME}/.config/mimeapps.list"
if [ -f "${MIMEAPPS_FILE}" ]; then
    cp "${MIMEAPPS_FILE}" "${MIMEAPPS_FILE}.bak.$(date +%Y%m%d%H%M%S)"
fi

# Add code.desktop as default for text/* and application/x-shellscript
mkdir -p "$(dirname "${MIMEAPPS_FILE}")"
if ! grep -q "code\.desktop" "${MIMEAPPS_FILE}" 2>/dev/null; then
    cat >> "${MIMEAPPS_FILE}" <<'EOF'

[Default Applications]
text/plain=code.desktop
text/x-shellscript=code.desktop
text/x-python=code.desktop
text/html=code.desktop
text/xml=code.desktop
text/css=code.desktop
text/csv=code.desktop
application/json=code.desktop
application/javascript=code.desktop
EOF
    echo "   mimeapps.list updated with code.desktop defaults."
else
    echo "code.desktop already present in mimeapps.list — skipping."
fi

update-desktop-database "${HOME}/.local/share/applications" 2>/dev/null || true

# Verify
for mime in text/plain text/x-shellscript text/x-python; do
    result=$(gio mime "$mime" 2>/dev/null)
    if [[ "$result" == *"code.desktop"* ]]; then
        echo "   ✓ ${mime} → code.desktop"
    else
        echo "${mime} → ${result:-unknown}"
    fi
done

mark_section_done "$(basename "${BASH_SOURCE[0]}" .sh)"
