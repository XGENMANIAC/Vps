# Android setup

The phone side uses the official **WireGuard** Android VPN app. This is intentional: a normal Termux process cannot create a full-device Android VPN on an unrooted phone.

## Install

From Termux you can open the official Play Store listing:

```bash
termux-open-url 'https://play.google.com/store/apps/details?id=com.wireguard.android'
```

Install WireGuard, then import the two generated `phone.conf` files (or scan the QR codes printed by `server/new-client.sh`).

Recommended tunnel names:

- Research-US
- Research-UK

## Required fail-closed setting for suspicious-app tests

On Android, open the system VPN settings for WireGuard and enable:

1. **Always-on VPN**
2. **Block connections without VPN**

The exact path varies by vendor, but on standard Android it is under:

`Settings → Network & internet → VPN → WireGuard`

With lockdown enabled, Android blocks app traffic instead of falling back to the normal Wi-Fi/mobile route when the VPN is unavailable.

## Verify from Termux

```bash
pkg update
pkg install -y curl git jq
git clone https://github.com/XGENMANIAC/Vps.git
cd Vps
bash tools/verify-exit.sh
```

## Test-lab hygiene

For an unknown APK, prefer a spare phone or emulator. Do not keep personal Google accounts, banking apps, password managers, private photos/documents, or an active personal SIM in the test environment.

The VPN controls **network egress**. It does not prevent an app from accessing data or permissions you grant locally.
