#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run as root: sudo bash server/install.sh <us|uk>" >&2
  exit 1
fi

REGION="${1:-}"
case "${REGION}" in
  us)
    VPN_CIDR="10.77.0.0/24"
    SERVER_TUNNEL_IP="10.77.0.1"
    ;;
  uk)
    VPN_CIDR="10.78.0.0/24"
    SERVER_TUNNEL_IP="10.78.0.1"
    ;;
  *)
    echo "Usage: sudo bash server/install.sh <us|uk>" >&2
    exit 2
    ;;
esac

WG_IF="${WG_IF:-rvpn0}"
WG_PORT="${WG_PORT:-51820}"
WG_DIR="/etc/wireguard"
ENV_FILE="/etc/research-vpn.env"

if [[ -e "${WG_DIR}/${WG_IF}.conf" && "${FORCE:-0}" != "1" ]]; then
  echo "${WG_DIR}/${WG_IF}.conf already exists. Refusing to overwrite it." >&2
  echo "Set FORCE=1 only if you intentionally want to replace the current server configuration." >&2
  exit 3
fi

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y wireguard wireguard-tools iptables curl qrencode ca-certificates

WAN_IF="${WAN_IF:-$(ip -4 route show default | awk 'NR==1 {print $5}')}"
if [[ -z "${WAN_IF}" ]]; then
  echo "Could not determine the public network interface. Set WAN_IF manually." >&2
  exit 4
fi

PUBLIC_IP="${PUBLIC_IP:-$(curl -4 -fsS --max-time 10 https://ifconfig.co/ip | tr -d '\r\n' || true)}"
if [[ -z "${PUBLIC_IP}" ]]; then
  echo "Could not determine the VPS public IPv4 address." >&2
  echo "Retry as: sudo PUBLIC_IP=x.x.x.x bash server/install.sh ${REGION}" >&2
  exit 5
fi

install -d -m 700 "${WG_DIR}"
umask 077

SERVER_PRIVATE_KEY="$(wg genkey)"
SERVER_PUBLIC_KEY="$(printf '%s' "${SERVER_PRIVATE_KEY}" | wg pubkey)"
printf '%s\n' "${SERVER_PRIVATE_KEY}" > "${WG_DIR}/${WG_IF}.key"
printf '%s\n' "${SERVER_PUBLIC_KEY}" > "${WG_DIR}/${WG_IF}.pub"

cat > "${WG_DIR}/${WG_IF}.conf" <<EOF
[Interface]
Address = ${SERVER_TUNNEL_IP}/24
ListenPort = ${WG_PORT}
PrivateKey = ${SERVER_PRIVATE_KEY}
SaveConfig = false
PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -A FORWARD -o %i -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT; iptables -t nat -A POSTROUTING -o ${WAN_IF} -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -D FORWARD -o %i -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT; iptables -t nat -D POSTROUTING -o ${WAN_IF} -j MASQUERADE
EOF
chmod 600 "${WG_DIR}/${WG_IF}.conf"

cat > /etc/sysctl.d/99-research-vpn.conf <<EOF
net.ipv4.ip_forward=1
net.ipv6.conf.all.forwarding=1
EOF
sysctl --system >/dev/null

cat > "${ENV_FILE}" <<EOF
REGION=${REGION}
VPN_CIDR=${VPN_CIDR}
SERVER_TUNNEL_IP=${SERVER_TUNNEL_IP}
WG_IF=${WG_IF}
WG_PORT=${WG_PORT}
WAN_IF=${WAN_IF}
PUBLIC_IP=${PUBLIC_IP}
EOF
chmod 600 "${ENV_FILE}"

systemctl enable "wg-quick@${WG_IF}" >/dev/null
systemctl restart "wg-quick@${WG_IF}"

echo
echo "Research VPN ${REGION^^} exit is running."
echo "Endpoint: ${PUBLIC_IP}:${WG_PORT}"
echo "Server public key: ${SERVER_PUBLIC_KEY}"
echo
echo "Next:"
echo "  sudo bash server/new-client.sh laptop <client-ip> linux"
echo "  sudo bash server/new-client.sh phone  <client-ip> android"
