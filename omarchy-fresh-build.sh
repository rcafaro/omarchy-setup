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
#   • SMB credentials for the font server (NAS, 192.168.200.201) — prompted at
#     runtime, section 12. Skip that step if you don't need Windows fonts.
#
# Config: omarchy-build.ini (repo root) — network, SMB credentials, paths.
# State:  ~/.omarchy-build-state — completed sections are skipped on re-run;
#         delete the file to force a full rebuild.
#
# Usage: bash omarchy-fresh-build.sh
###############################################################################
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SECTIONS_DIR="${SCRIPT_DIR}/sections"

source "${SECTIONS_DIR}/_lib.sh"

check_required_assets

# Ask up front whether to install Tailscale (honors SKIP_TAILSCALE=1).
resolve_tailscale_choice
export INSTALL_TAILSCALE

###############################################################################
# Run sections in order. Each is also independently runnable:
#   bash sections/NN-name.sh
# Sourced (not exec'd) so state passes between modules — e.g. the SMB
# credentials entered in 12 are reused by 14.
# Completed sections (see ~/.omarchy-build-state) are skipped on re-run.
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
    14-nas-mounts
do
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
