#!/usr/bin/env bash
###############################################################################
# Omarchy Fresh Build — Consolidated Automation Script (orchestrator)
#
# Modular layout: each numbered section lives in sections/NN-name.sh and can
# be run standalone:   bash sections/08-pulse-secure.sh
# Shared config/helpers live in sections/_lib.sh.
#
# Combines:
#   - Vault note "Omarchy fresh install steps" (base system, packages, plugins)
#   - ~/code/omarchy-build/pulse-omarchy/  (Pulse Secure launcher + sudoers)
#   - ~/code/omarchy-build/waydroid/       (Waydroid + bindfs + JW handler)
#   - ~/code/omarchy-build/install_fonts.sh (Windows fonts via SMB)
#
# PREREQUISITES:
#   • assets/ directory alongside this script containing:
#       os-release.kubuntu    (md5: 9e0dcb60cca740a8733d71ecd5a93f8d)
#       screensaver_logo.png  (Unagui logo for ASCII screensaver)
#       login_logo.png        (Unagui inverted logo for Plymouth boot screen)
#     Note: os-release.omarchy is captured live from /etc/os-release at runtime.
#   • SMB credentials for the font server (NAS, 192.168.200.201) — offered at
#     the upfront prompt; sections needing them skip gracefully without.
#
# Config: omarchy-build.ini (repo root) — network, device profile, component
#         toggles, SMB credentials, paths. Any value pinned there is not asked.
# State:  ~/.omarchy-build-state — completed sections are skipped on re-run;
#         delete the file to force a full rebuild.
#
# All prompts happen in the upfront block below; once the section loop starts
# it runs unattended (non-TTY safe).
#
# Usage: bash omarchy-fresh-build.sh
###############################################################################
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SECTIONS_DIR="${SCRIPT_DIR}/sections"

source "${SECTIONS_DIR}/_lib.sh"

check_required_assets

###############################################################################
# UPFRONT DECISIONS — every prompt lives here, so the loop below never stops.
# Precedence everywhere: env var > omarchy-build.ini > interactive question.
###############################################################################
section "Build options (all prompts happen now)"

resolve_device_type          # desktop|laptop → drives package selection
export DEVICE_TYPE
echo "   Device profile : ${DEVICE_TYPE}"

resolve_install_pulse        # 1|0, default yes
export INSTALL_PULSE
echo "   Pulse Secure   : $([[ "${INSTALL_PULSE}" == "1" ]] && echo yes || echo no)"

resolve_tailscale_choice     # derived from device profile; env overrides win
export INSTALL_TAILSCALE
echo "   Tailscale      : $([[ "${INSTALL_TAILSCALE}" == "1" ]] && echo yes || echo no)  (laptop installs, desktop skips)"

resolve_fonts_choice         # 1|0, default no
if [[ -n "${MOUNT_SERVER}" && -z "${SMB_USER}" ]]; then
    if [[ "$(ask_yn "Configure NAS access (fonts + mounts need SMB credentials)? " y)" == "y" ]]; then
        collect_smb_creds
    fi
fi
if [[ "${INSTALL_FONTS}" == "1" && ( -z "${SMB_USER}" || -z "${SMB_PASS}" ) ]]; then
    warn "No SMB credentials — Windows fonts will be skipped."
    INSTALL_FONTS=0
fi
export INSTALL_FONTS
echo "   Windows fonts  : $([[ "${INSTALL_FONTS}" == "1" ]] && echo yes || echo no)"

# A section disabled by the choices above is skipped WITHOUT a state mark, so
# flipping the choice later re-runs it. Choice beats stale state: checked first.
section_disabled() { # $1 = section name → echoes reason and returns 0 when disabled
    case "$1" in
        08-pulse-secure)
            [[ "${INSTALL_PULSE}" == "1" ]] || { echo "Pulse Secure declined"; return 0; } ;;
        10-gaming)
            if [[ "${DEVICE_TYPE}" == "laptop" ]]; then echo "laptop profile (no gaming)"; return 0; fi ;;
        12-windows-fonts)
            [[ "${INSTALL_FONTS}" == "1" ]] || { echo "fonts declined or no SMB credentials"; return 0; } ;;
        14-nas-mounts)
            if [[ -z "${MOUNT_SERVER}" ]]; then echo "no NAS server configured"; return 0; fi
            if [[ -z "${SMB_USER}" || -z "${SMB_PASS}" ]]; then echo "no SMB credentials"; return 0; fi ;;
    esac
    return 1
}

###############################################################################
# Run sections in order. Each is also independently runnable:
#   bash sections/NN-name.sh
# Sourced (not exec'd) so state passes between modules — e.g. the SMB
# credentials entered upfront are reused by fonts and mounts.
###############################################################################
for s in \
    00-security-ssh \
    01-remove-webapps \
    02-core-packages \
    03-aur-packages \
    04-services \
    05-voxtype \
    06-tailscale-spotify \
    07-plugins \
    08-pulse-secure \
    09-waydroid \
    10-gaming \
    11-branding \
    12-windows-fonts \
    13-vscode-default-editor \
    14-nas-mounts \
    15-keyboard\
do
    if reason=$(section_disabled "$s"); then
        echo "[skip] ${s} — ${reason}"
        continue
    fi
    if section_done "$s"; then
        echo "[skip] ${s} — already completed (state: ${STATE_FILE})"
        continue
    fi
    source "${SECTIONS_DIR}/${s}.sh"
done

###############################################################################
# DONE
###############################################################################
section "Build complete"
echo ""
echo "Remaining manual steps:"
echo "  • Atrium setup: ${BUILD_DIR}/io.github.bitshiftxr.atrium/setup"
echo "  • DaVinci Resolve: download AppImage, double-click (no sudo)"
echo "  • Photopea PWA: install from browser"
echo "  • Consider: https://github.com/ReidenXerx/omarchy-tile-blueprints"
echo ""
