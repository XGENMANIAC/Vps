#!/usr/bin/env bash
set -euo pipefail

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing dependency: $1" >&2
    exit 1
  }
}

need curl

echo "=== Public exit ==="
IP="$(curl -4 -fsS --max-time 10 https://ifconfig.co/ip | tr -d '\r\n')"
echo "IPv4: ${IP}"

echo
echo "=== Geolocation reported for this IP ==="
if command -v jq >/dev/null 2>&1; then
  curl -fsS --max-time 10 https://ipinfo.io/json |     jq '{ip, city, region, country, org, timezone}'
else
  curl -fsS --max-time 10 https://ipinfo.io/json
  echo
fi

echo
echo "=== WireGuard ==="
if command -v wg >/dev/null 2>&1; then
  wg show || true
else
  echo "wg command not installed on this device."
fi

echo
echo "Remember: GPS, SIM country, locale, account history and device attestation are separate from IP geolocation."
