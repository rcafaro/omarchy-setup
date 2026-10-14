#!/usr/bin/env bash
# Section 0 — Security & SSH
# Standalone: bash sections/00-security-ssh.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_lib.sh"

section "0 — Security & SSH"
if systemctl is-active --quiet sshd 2>/dev/null && [ -s "${HOME}/.ssh/authorized_keys" ]; then
    echo "   SSH server active and authorized_keys present — skipping key setup."
else
    omarchy setup security sshd
fi
