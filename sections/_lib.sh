#!/usr/bin/env bash
###############################################################################
# Omarchy Fresh Build — shared library (sourced by orchestrator + every section)
#
# Provides: strict mode, config variables (from omarchy-build.ini), helpers,
# asset check, upfront decision resolvers, and build-state tracking.
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
SMB_USER="$(ini_get SMB_USER "")"          # or entered at the upfront prompt
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

# ask_yn "Question" [default y|n] → echoes y or n.
# TTY-safe: without a terminal it returns the default silently, so unattended
# runs never hang on a prompt and never die on read's non-zero exit.
ask_yn() {
    local q="$1" def="${2:-y}" ans=""
    if [[ -t 0 ]]; then
        read -r -p "${q} [${def}] " ans || ans=""
    fi
    case "${ans,,}" in
        y|yes) echo y ;;
        n|no)  echo n ;;
        *)     echo "$def" ;;
    esac
}

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

# ─── Upfront decision resolvers ─────────────────────────────────────────────
# Every one of these is a no-op when its variable is already set, so the
# orchestrator resolves them once (with prompts) before the loop and sections
# inherit the decisions. Standalone section runs resolve their own defaults.

# resolve_device_type → sets DEVICE_TYPE (desktop|laptop). env > ini > ask.
# Non-TTY without a value: assumes desktop with a warning.
resolve_device_type() {
    if [[ -n "${DEVICE_TYPE:-}" ]]; then return 0; fi
    local ini_val ans=""
    case "$(ini_get DEVICE_TYPE "")" in
        d|desktop) DEVICE_TYPE=desktop; return 0 ;;
        l|laptop)  DEVICE_TYPE=laptop;  return 0 ;;
    esac
    if [[ -t 0 ]]; then
        read -r -p "Device type — (d)esktop or (l)aptop [d] " ans || ans=""
    else
        warn "No TTY and no DEVICE_TYPE set — assuming desktop."
    fi
    case "${ans,,}" in l|laptop) DEVICE_TYPE=laptop ;; *) DEVICE_TYPE=desktop ;; esac
}

# resolve_install_pulse → sets INSTALL_PULSE 1|0. env > ini > ask (default yes).
resolve_install_pulse() {
    if [[ -n "${INSTALL_PULSE:-}" ]]; then return 0; fi
    case "$(ini_get INSTALL_PULSE "")" in
        1|true|yes|y)   INSTALL_PULSE=1; return 0 ;;
        0|false|no|n)   INSTALL_PULSE=0; return 0 ;;
    esac
    if [[ "$(ask_yn "Install Pulse Secure (VPN launcher)? " y)" == "y" ]]; then
        INSTALL_PULSE=1
    else
        INSTALL_PULSE=0
    fi
}

# resolve_tailscale_choice → sets INSTALL_TAILSCALE 1|0. NO prompt — the device
# profile decides: laptop installs Tailscale, desktop skips it. Explicit env
# wins for automation: INSTALL_TAILSCALE=0/1 or SKIP_TAILSCALE=1.
resolve_tailscale_choice() {
    if [[ -n "${INSTALL_TAILSCALE:-}" ]]; then return 0; fi
    if [[ "${SKIP_TAILSCALE:-0}" == "1" ]]; then INSTALL_TAILSCALE=0; return 0; fi
    case "$(ini_get TAILSCALE_INSTALL "")" in
        1|true|yes|y)   INSTALL_TAILSCALE=1; return 0 ;;
        0|false|no|n)   INSTALL_TAILSCALE=0; return 0 ;;
    esac
    if [[ "${DEVICE_TYPE:-desktop}" == "laptop" ]]; then
        INSTALL_TAILSCALE=1
    else
        INSTALL_TAILSCALE=0
    fi
}

# resolve_fonts_choice → sets INSTALL_FONTS 1|0. env > ini > ask (default no).
resolve_fonts_choice() {
    if [[ -n "${INSTALL_FONTS:-}" ]]; then return 0; fi
    case "$(ini_get INSTALL_FONTS "")" in
        1|true|yes|y)   INSTALL_FONTS=1; return 0 ;;
        0|false|no|n)   INSTALL_FONTS=0; return 0 ;;
    esac
    if [[ "$(ask_yn "Install Windows fonts from NAS? " n)" == "y" ]]; then
        INSTALL_FONTS=1
    else
        INSTALL_FONTS=0
    fi
}

# collect_smb_creds → fills SMB_USER/SMB_PASS via prompt when missing.
# TTY-safe: without a terminal it leaves them empty (callers skip gracefully).
collect_smb_creds() {
    if [[ -n "${SMB_USER}" && -n "${SMB_PASS}" ]]; then return 0; fi
    if [[ -t 0 ]]; then
        read -rp "NAS SMB username: " SMB_USER || SMB_USER=""
        read -rsp "NAS SMB password: " SMB_PASS || SMB_PASS=""
        echo ""
    fi
    return 0   # never fail the caller — empty creds are a valid (skip) outcome
}
