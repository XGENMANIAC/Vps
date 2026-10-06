# Research VPN Lab

A personal, full-device WireGuard lab for routing research/testing traffic through **US** and **UK** exit servers.

> Designed for your own devices, research, privacy, and authorized app/network testing. It does **not** bypass app permissions, device security, or service access controls.

## What it does

- Routes **all device traffic**, including normal apps and embedded webviews, through a chosen US or UK VPS.
- Changes the public egress IP to the selected VPS IP. Most IP-geolocation services will therefore infer the VPS country.
- Supports a fail-closed workflow:
  - **Linux:** generated client profiles include firewall kill-switch rules.
  - **Android:** use WireGuard plus Android **Always-on VPN** + **Block connections without VPN**.
- Keeps US and UK identities separate.
- Provides quick exit verification.
- Stores no secrets in Git. WireGuard keys/configs are generated at deployment time.

## Architecture

```
Laptop / Android
      |
      | WireGuard tunnel
      v
+------------------+       +------------------+
| US VPS           |       | UK VPS           |
| New York/Ashburn |       | London           |
| public US IP     |       | public UK IP     |
+---------+--------+       +---------+--------+
          |                          |
          +---------- Internet ------+
```

You need **two small Linux VPSs**:
1. one physically/geolocated in the United States;
2. one physically/geolocated in the United Kingdom.

Ubuntu 22.04/24.04 is recommended.

## 1. Clone this repository

```bash
git clone https://github.com/XGENMANIAC/Vps.git
cd Vps
```

## 2. Install the US exit

SSH into the US VPS, then:

```bash
git clone https://github.com/XGENMANIAC/Vps.git
cd Vps
sudo bash server/install.sh us
```

Create profiles:

```bash
sudo bash server/new-client.sh laptop 10.77.0.10 linux
sudo bash server/new-client.sh phone 10.77.0.11 android
```

## 3. Install the UK exit

On the UK VPS:

```bash
git clone https://github.com/XGENMANIAC/Vps.git
cd Vps
sudo bash server/install.sh uk
sudo bash server/new-client.sh laptop 10.78.0.10 linux
sudo bash server/new-client.sh phone 10.78.0.11 android
```

The generated client files are written under:

```
/root/research-vpn/clients/
```

Copy the two laptop profiles to your laptop and rename them:

```bash
scp root@US_SERVER_IP:/root/research-vpn/clients/laptop.conf ~/research-us.conf
scp root@UK_SERVER_IP:/root/research-vpn/clients/laptop.conf ~/research-uk.conf
```

After importing a profile, remove the exported client file from the server if you do not want a recoverable copy of the client private key there.

## 4. Laptop setup — Arch / Omarchy

```bash
git clone https://github.com/XGENMANIAC/Vps.git
cd Vps
sudo bash client/laptop/install-arch.sh
sudo install -m 600 ~/research-us.conf /etc/wireguard/research-us.conf
sudo install -m 600 ~/research-uk.conf /etc/wireguard/research-uk.conf
sudo install -m 755 client/laptop/research-vpn /usr/local/bin/research-vpn
```

Switch country:

```bash
sudo research-vpn us
sudo research-vpn status
sudo research-vpn uk
sudo research-vpn off
```

For suspicious-app/network testing, turn on the persistent lab lock **before** launching the app:

```bash
sudo research-vpn lock on
sudo research-vpn us
# launch/test the app
sudo research-vpn uk
# continue through the UK exit
sudo research-vpn off       # tunnel down; lab lock still blocks direct egress
sudo research-vpn lock off  # restore normal networking only after the app is closed
```

Verify the exit:

```bash
bash tools/verify-exit.sh
```

## 5. Android phone

Use the official WireGuard Android app. Generate the phone profiles on each VPS with `new-client.sh`.

Copy/import `phone.conf` for each server into WireGuard and name the tunnels:

- `Research-US`
- `Research-UK`

For suspicious-app testing, enable Android's VPN lockdown:

**Settings → Network & internet → VPN → WireGuard → Always-on VPN → Block connections without VPN**

Exact menu wording varies by Android vendor.

That means an app cannot silently fall back to your normal mobile/Wi-Fi route if the tunnel drops.

### Termux verification

```bash
pkg update
pkg install -y curl git jq
git clone https://github.com/XGENMANIAC/Vps.git
cd Vps
bash tools/verify-exit.sh
```

## Suspicious-app lab workflow

A VPN changes and constrains network egress, but it does **not** make a suspicious app safe.

For unknown APKs, prefer:
1. a spare phone or Android emulator;
2. no personal Google account, banking apps, SIM, password manager, or private files;
3. WireGuard Android lockdown enabled **before** opening the APK;
4. only the minimum app permissions needed for the test;
5. uninstall/reset the test environment afterwards.

For higher-risk samples, use an emulator/VM rather than your daily phone.

## Country/IP caveat

The public IP becomes the VPS public address. Country detection is performed by third-party IP-geolocation databases, so choose VPS regions explicitly advertised as US or London/UK and verify with `tools/verify-exit.sh`. A service can still use non-IP signals such as GPS permission, SIM country, locale, account history, or device attestation.

## Security

See [SECURITY.md](SECURITY.md).

## Repository layout

```
server/
  install.sh
  new-client.sh
client/
  laptop/install-arch.sh
  laptop/research-vpn
  android/README.md
tools/
  verify-exit.sh
.gitignore
SECURITY.md
```
