#!/usr/bin/env bash
# Section 5 — Voxtype (keyboard layout)
# Standalone: bash sections/05-voxtype.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_lib.sh"

section "5 — Voxtype"
try omarchy voxtype install
try omarchy voxtype config
