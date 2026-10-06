# Security notes

## Intended use

This repository is for personal privacy, research, and authorized app/network testing on devices and servers you control.

## What the VPN protects

WireGuard encrypts traffic between the client device and your chosen exit VPS. The destination sees the VPS public IP rather than the client's normal public IP.

## What it does not protect

A VPN does not make an unknown app safe. Depending on permissions and platform controls, an app may still access local files, contacts, sensors, clipboard contents, account data, accessibility services, notification content, or other device resources.

IP country is also not the same thing as complete device-location identity. Apps may use GPS, Wi-Fi/cell data, SIM country, locale, time zone, account history, Play Integrity/device attestation, or their own historical risk signals.

## Suspicious-app testing

Prefer a disposable Android emulator/VM or spare physical device.

For a phone test environment:

- do not sign into personal accounts;
- remove banking/password-manager apps;
- avoid a personal SIM;
- copy in only the files required for the test;
- enable Android Always-on VPN and Block connections without VPN before launching the test app;
- reset or wipe the environment after higher-risk tests.

For the Linux host, `research-vpn lock on` installs an explicit output firewall chain that permits the two WireGuard endpoints and the active tunnel interfaces while rejecting other egress. Leave the lock enabled while a suspicious program is running.

## Key handling

The server-side helper generates client private keys for convenience. After importing a client profile, securely delete the exported profile from the VPS:

```bash
sudo shred -u /root/research-vpn/clients/CLIENT.conf
```

Never commit generated `.conf`, `.key`, `.psk`, or secret files. The repository's `.gitignore` blocks these extensions.

If a client is lost or suspected compromised, remove its peer from the server and issue a new profile.

## VPS trust

Your VPS provider can observe connection metadata at the exit and destinations still see normal application traffic unless the application itself uses HTTPS/TLS (most modern apps do). Treat the VPS as part of your trust boundary.
