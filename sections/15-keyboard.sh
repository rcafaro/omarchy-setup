#!/usr/bin/env bash
# Section 15 — Keyboard (Hyprland input.lua)
# Standalone: bash sections/15-keyboard.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_lib.sh"

section "15 — Keyboard"

INPUT_LUA="${HOME}/.config/hypr/input.lua"

# US International layout with a traditional Caps Lock.
# Omarchy's default input.lua sets kb_options="compose:caps,shift:both_capslock_cancel",
# and it loads BEFORE this file — so kb_options MUST be overridden with an explicit
# empty string. Deleting the key (leaving it unset) does NOT clear the default.
# Skipped when the user already set a custom kb_layout.
if [[ -f "${INPUT_LUA}" ]] && grep -qE '^[[:space:]]*kb_layout[[:space:]]*=' "${INPUT_LUA}"; then
    warn "input.lua already has a custom kb_layout — leaving it untouched."
else
    mkdir -p "$(dirname "${INPUT_LUA}")"
    cat > "${INPUT_LUA}" <<'EOF'
-- Keep only your personal input overrides here. Uncommented settings below
-- replace Omarchy's defaults.

-- Keyboard layout and options.
-- See https://wiki.hypr.land/Configuring/Basics/Variables/#input
hl.config({
  input = {
    -- US International (with diacritics) — matches naboo.
    kb_layout = "us",
    kb_variant = "intl",

    -- Traditional Caps Lock. Omarchy's default ships
    -- "compose:caps,shift:both_capslock_cancel"; an explicit empty string
    -- clears it. Omitting the key does NOT — defaults load first.
    kb_options = "",
  },
})

-- hl.config({
--   input = {
--     -- Use multiple keyboard layouts and switch between them with Left Alt + Right Alt.
--     kb_layout = "us,dk,eu",
--     kb_options = "compose:caps,shift:both_capslock_cancel,grp:alts_toggle",
--
--     -- Use a specific keyboard variant if needed (e.g. intl for international keyboards).
--     kb_variant = "intl",
--
--     -- Change speed of keyboard repeat.
--     repeat_rate = 40,
--     repeat_delay = 250,
--
--     -- Start with numlock on by default.
--     numlock_by_default = true,
--
--     -- Increase sensitivity for mouse/trackpad (default: 0).
--     sensitivity = 0.35,
--
--     -- Turn off mouse acceleration (default: adaptive).
--     accel_profile = "flat",
--
--     touchpad = {
--       -- Use natural (inverse) scrolling.
--       natural_scroll = true,
--
--       -- Use two-finger clicks for right-click instead of lower-right corner.
--       clickfinger_behavior = true,
--
--       -- Control the speed of your scrolling.
--       scroll_factor = 0.4,
--
--       -- Enable the touchpad while typing.
--       disable_while_typing = false,
--
--       -- Left-click-and-drag with three fingers.
--       drag_3fg = 1,
--     },
--   },
-- })

-- App-specific touchpad scroll speeds.
-- o.window("(Alacritty|kitty|foot)", { scroll_touchpad = 1.5 })
-- o.window("com.mitchellh.ghostty", { scroll_touchpad = 0.2 })

-- Enable touchpad gestures for changing workspaces.
-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Gestures/
-- hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

-- Enable touchpad gestures for moving focus (helpful on scrolling layout).
-- hl.gesture({ fingers = 3, direction = "left", action = function() hl.dispatch(hl.dsp.focus({ direction = "l" })) end })
-- hl.gesture({ fingers = 3, direction = "right", action = function() hl.dispatch(hl.dsp.focus({ direction = "r" })) end })
EOF
fi

# Apply immediately if a Hyprland session is running (no-op on fresh installs).
if command -v hyprctl >/dev/null 2>&1; then
    SIG=$(ls "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr/" 2>/dev/null | head -1)
    if [[ -n "${SIG}" ]]; then
        HYPRLAND_INSTANCE_SIGNATURE="${SIG}" try hyprctl reload
    fi
fi

mark_section_done "$(basename "${BASH_SOURCE[0]}" .sh)"
