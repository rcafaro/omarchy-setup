#!/usr/bin/env bash
###############################################################################
# Omarchy Fresh Build — shared library (sourced by orchestrator + every section)
#
# Provides: strict mode, config variables (from omarchy-build.ini), helpers,
# asset check, Tailscale install choice, and build-state tracking.
# Idempotent — safe to source multiple times.
###############################################################################

if [[ -n "${OMARCHY_LIB_LOADED:-}" ]]; then return 0; fi
OMARCHY_LIB_LOADED=1

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"   # repo root (parent of sections/)
ASSETS_DIR="${SCRIPT_DIR}/assets"
INI_FILE="${SCRIPT_DIR}/omarchy-build.ini"

# ── INI reader: ini_get KEY [DEFAULT] ───────────────────────────────────────
# Flat key=value lookup in omarchy-build.ini; first match wins, empty value →
# default. ${HOME} inside values is expanded. Section headers and # comments
# are ignored (a commented-out "# KEY=..." never matches).
ini_get() {
    local val=""
    if [ -f "${INI_FILE}" ]; then
        val=$(grep -E "^[[:space:]]*$1[[:space:]]*=" "${INI_FILE}" 2>/dev/null | head -n1 \
              | cut -d= -f2- | sed 's/^[[:space:]]*//; s/[[:space:]]*$//') || true
    fi
    val="${val/\$\{HOME\}/${HOME}}"
    echo "${val:-${2-}}"
}

# ── Network & host variables (defaults overridable in omarchy-build.ini) ───
NAS_IP="$(ini_get NAS_IP "nas.local")"
LAN_SUBNET="$(ini_get LAN_SUBNET "192.168.200.0/24")"
TAILSCALE_NET="$(ini_get TAILSCALE_NET "100.64.0.0/10")"

# ── SMB font server (NAS) ───────────────────────────────────────────────────
SMB_SERVER="$(ini_get SMB_SERVER "${NAS_IP}")"
SMB_SHARE_PATH="$(ini_get SMB_SHARE_PATH "pool/installer/Apps/linux/windowsFonts")"
SMB_USER="$(ini_get SMB_USER "")"          # or enter at runtime (section 12)
SMB_PASS="$(ini_get SMB_PASS "")"

# ── NAS mount server: Tailscale IP preferred, LAN name as fallback ──────────
NAS_TAILSCALE_IP="$(ini_get NAS_TAILSCALE_IP "")"   # e.g. "100.64.231.90"
MOUNT_SERVER="${NAS_TAILSCALE_IP:-${NAS_IP}}"

# ── Paths ───────────────────────────────────────────────────────────────────
BUILD_DIR="$(ini_get BUILD_DIR "${HOME}/.config/omarchy/plugins")"  # for plugin paths
PULSE_DIR="$(ini_get PULSE_DIR "${HOME}/pulse-omarchy")"            # pulse scripts live here (copied during build)
UNAGUI_LOGO="${ASSETS_DIR}/screensaver_logo.png"
UNAGUI_LOGO_INV="${ASSETS_DIR}/login_logo.png"

# ── Build-state tracking: skip fully-completed sections on re-run ───────────
# Each section marks itself done at the end of its body (mark_section_done).
# A fatal error aborts before the mark, so failed sections are retried next run.
# Reset by deleting STATE_FILE; point OMARCHY_STATE_FILE elsewhere to test.
STATE_FILE="${OMARCHY_STATE_FILE:-${HOME}/.omarchy-build-state}"
section_done()     { grep -qxF "$1" "${STATE_FILE}" 2>/dev/null; }
mark_section_done(){ mkdir -p "$(dirname "${STATE_FILE}")"; echo "$1" >> "${STATE_FILE}"; }

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
