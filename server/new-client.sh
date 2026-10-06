#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run as root." >&2
  exit 1
fi

NAME="${1:-}"
CLIENT_IP="${2:-}"
PLATFORM="${3:-linux}"

if [[ -z "${NAME}" || -z "${CLIENT_IP}" ]]; then
  echo "Usage: sudo bash server/new-client.sh <name> <client-ip> [linux|android]" >&2
  exit 2
fi

case "${PLATFORM}" in
  linux|android) ;;
  *)
    echo "Platform must be linux or android." >&2
    exit 3
    ;;
esac

# Conservative name validation because it becomes part of a root-owned path.
if [[ ! "${NAME}" =~ ^[A-Za-z0-9._-]+$ ]]; then
  echo "Client name may contain only letters, numbers, dot, underscore and dash." >&2
  exit 4
fi

source /etc/research-vpn.env

case "${REGION}" in
  us)
    [[ "${CLIENT_IP}" =~ ^10\.77\.0\.[0-9]{1,3}$ ]] || {
      echo "US client IP must be inside 10.77.0.0/24." >&2
      exit 5
    }
    ;;
  uk)
    [[ "${CLIENT_IP}" =~ ^10\.78\.0\.[0-9]{1,3}$ ]] || {
      echo "UK client IP must be inside 10.78.0.0/24." >&2
      exit 5
    }
    ;;
esac

LAST_OCTET="${CLIENT_IP##*.}"
if (( LAST_OCTET < 2 || LAST_OCTET > 254 )); then
  echo "Client address must use a host number from 2 to 254." >&2
  exit 6
fi

CLIENT_DIR="/root/research-vpn/clients"
install -d -m 700 "${CLIENT_DIR}"
CONF="${CLIENT_DIR}/${NAME}.conf"

if [[ -e "${CONF}" ]]; then
  echo "${CONF} already exists. Use a different client name or revoke the old peer first." >&2
  exit 7
fi

umask 077
CLIENT_PRIVATE_KEY="$(wg genkey)"
CLIENT_PUBLIC_KEY="$(printf '%s' "${CLIENT_PRIVATE_KEY}" | wg pubkey)"
PSK="$(wg genpsk)"
SERVER_PUBLIC_KEY="$(cat "/etc/wireguard/${WG_IF}.pub")"

PSK_FILE="$(mktemp)"
trap 'rm -f "${PSK_FILE}"' EXIT
printf '%s\n' "${PSK}" > "${PSK_FILE}"

cat >> "/etc/wireguard/${WG_IF}.conf" <<EOF

# client: ${NAME}
[Peer]
PublicKey = ${CLIENT_PUBLIC_KEY}
PresharedKey = ${PSK}
AllowedIPs = ${CLIENT_IP}/32
EOF

wg set "${WG_IF}" peer "${CLIENT_PUBLIC_KEY}" preshared-key "${PSK_FILE}" allowed-ips "${CLIENT_IP}/32"

cat > "${CONF}" <<EOF
[Interface]
PrivateKey = ${CLIENT_PRIVATE_KEY}
Address = ${CLIENT_IP}/32
DNS = 1.1.1.1, 1.0.0.1
MTU = 1380

[Peer]
PublicKey = ${SERVER_PUBLIC_KEY}
PresharedKey = ${PSK}
Endpoint = ${PUBLIC_IP}:${WG_PORT}
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
EOF

if [[ "${PLATFORM}" == "linux" ]]; then
  # These profile-local rules prevent direct IPv4/IPv6 egress while this tunnel is up.
  # The research-vpn helper also provides a persistent lab lock for safe country switching.
  sed -i '/^MTU = /a PostUp = iptables -I OUTPUT ! -o %i -m mark ! --mark $(wg show %i fwmark) -m addrtype ! --dst-type LOCAL -j REJECT; ip6tables -I OUTPUT ! -o %i -m mark ! --mark $(wg show %i fwmark) -m addrtype ! --dst-type LOCAL -j REJECT\nPostDown = iptables -D OUTPUT ! -o %i -m mark ! --mark $(wg show %i fwmark) -m addrtype ! --dst-type LOCAL -j REJECT; ip6tables -D OUTPUT ! -o %i -m mark ! --mark $(wg show %i fwmark) -m addrtype ! --dst-type LOCAL -j REJECT' "${CONF}"
fi

chmod 600 "${CONF}"

echo
echo "Created ${REGION^^} profile: ${CONF}"
echo "Client public key: ${CLIENT_PUBLIC_KEY}"
echo

if [[ "${PLATFORM}" == "android" ]]; then
  echo "Scan this QR code from the official WireGuard Android app:"
  qrencode -t ansiutf8 < "${CONF}"
  echo
fi

echo "After securely importing the profile, you may remove this exported client config from the VPS:"
echo "  shred -u ${CONF}"
