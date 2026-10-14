#!/usr/bin/env bash
###############################################################################
# Omarchy Fresh Build — shared library (sourced by orchestrator + every section)
#
# Provides: strict mode, config variables, helpers, asset check, and the
# Tailscale install choice. Idempotent — safe to source multiple times.
###############################################################################

if [[ -n "${OMARCHY_LIB_LOADED:-}" ]]; then return 0; fi
OMARCHY_LIB_LOADED=1

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"   # repo root (parent of sections/)
ASSETS_DIR="${SCRIPT_DIR}/assets"

# ── Network & host variables ───────────────────────────────────────────────
NAS_IP="nas.local"
LAN_SUBNET="192.168.200.0/24"
TAILSCALE_NET="100.64.0.0/10"

# ── SMB font server (NAS) ──────────────────────────────────────────────────
SMB_SERVER="${NAS_IP}"
SMB_SHARE_PATH="pool/installer/Apps/linux/windowsFonts"
SMB_USER=""          # Set your NAS username here, or skip section 12/13
SMB_PASS=""          # Set your NAS password here

# ── Tailscale IP of the NAS (for fstab CIFS mounts) ────────────────────────
NAS_TAILSCALE_IP=""   # e.g. "100.64.231.90" — leave empty to skip fstab mounts

# ── Paths ──────────────────────────────────────────────────────────────────
BUILD_DIR="${HOME}/.config/omarchy/plugins"  # for plugin paths
PULSE_DIR="${HOME}/pulse-omarchy"           # pulse scripts live here (copied during build)
UNAGUI_LOGO="${ASSETS_DIR}/screensaver_logo.png"
UNAGUI_LOGO_INV="${ASSETS_DIR}/login_logo.png"

# ─── Helpers ────────────────────────────────────────────────────────────────
section() { echo ""; echo "═══════════════════════════════════════"; echo "  $1"; echo "═══════════════════════════════════════"; }
warn()    { echo "[!] $*" >&2; }
try()     { if ! "$@"; then warn "step failed (continuing): $*"; fi; }

# ── Verify required assets (exit 1 if any missing) ─────────────────────────
check_required_assets() {
    local MISSING=0 f
    for f in os-release.kubuntu screensaver_logo.png login_logo.png; do
        if [ ! -f "${ASSETS_DIR}/${f}" ]; then
            warn "Missing asset: ${ASSETS_DIR}/${f}"
            MISSING=1
        fi
    done
    if [ "$MISSING" -eq 1 ]; then
        echo "Place required files in ${ASSETS_DIR}/ and re-run." >&2
        exit 1
    fi
}

# ── Tailscale install choice (sets INSTALL_TAILSCALE; no-op if already set) ─
# SKIP_TAILSCALE=1 → never install. Interactive TTY + tailscaled not active → ask.
# Non-interactive default: install (original behavior).
resolve_tailscale_choice() {
    if [[ -n "${INSTALL_TAILSCALE:-}" ]]; then return 0; fi
    if [[ "${SKIP_TAILSCALE:-0}" == "1" ]]; then
        INSTALL_TAILSCALE=0
    elif [[ -t 0 ]] && ! systemctl is-active --quiet tailscaled; then
        local _ans
        read -r -p "Install Tailscale? (y/N) " _ans
        case "${_ans,,}" in
            y|yes) INSTALL_TAILSCALE=1 ;;
            *)     INSTALL_TAILSCALE=0 ;;
        esac
    else
        INSTALL_TAILSCALE=1
    fi
}
