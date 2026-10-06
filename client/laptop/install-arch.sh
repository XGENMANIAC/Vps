#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run with sudo: sudo bash client/laptop/install-arch.sh" >&2
  exit 1
fi

if ! command -v pacman >/dev/null 2>&1; then
  echo "This installer is for Arch-based systems. Install wireguard-tools, iptables, curl, jq and a resolvconf provider manually." >&2
  exit 2
fi

pacman -S --needed --noconfirm wireguard-tools iptables openresolv curl jq
install -d -m 700 /etc/wireguard

echo "Installed WireGuard client dependencies."
echo "Next, place research-us.conf and research-uk.conf in /etc/wireguard with mode 600."
