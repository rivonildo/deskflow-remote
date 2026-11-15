# Deskflow Remote

[![CI](https://github.com/rivonildo/barrier-remote-control/actions/workflows/ci.yml/badge.svg)](https://github.com/rivonildo/barrier-remote-control/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Deskflow](https://img.shields.io/badge/backend-Deskflow-5b8def)](https://github.com/deskflow/deskflow)

Use one keyboard and mouse across several computers — Windows, macOS and Linux — with a guided setup built around the actively maintained **Deskflow** project.

> **Why Deskflow instead of Barrier?** Barrier 2.4.0 is unmaintained and no longer receives security fixes. Deskflow is maintained, supports TLS by default, supports Wayland and remains network-compatible with Barrier for gradual migration.

## The workflow

**Copy here. Move there. Paste.**

Keep your editor, terminals, browsers, AI tools and test environments on the computers where they belong while one keyboard, mouse and clipboard follow your focus across the desk. This is the practical “pega na mão” layer around Deskflow: safer installation, explicit roles, diagnostics and real-world guidance.

## What this repository adds

- Simple installers for Windows, macOS and Linux.
- Guided server/client setup: the helpers generate a server layout, then open Deskflow for the user to select the role and import/apply settings.
- One server with multiple clients.
- LAN by default; optional Tailscale for computers on different networks.
- Direct core launches are avoided; users retain Deskflow's default TLS and peer-fingerprint settings in the GUI.
- A scoped Windows firewall rule is created only when the exact `deskflow-server.exe` path can be identified; otherwise no rule is created.
- Non-interactive flags suitable for Hermes and other automation agents.
- No embedded IP addresses, machine names, credentials or authentication keys.

## Requirements

- **Windows:** Windows 10 1809+ or Windows 11, with WinGet.
- **macOS:** macOS 12+ and Homebrew. Accessibility permission is required.
- **Linux:** a supported package manager or Flatpak. Wayland may require desktop portal approval.
- All computers must be reachable over the LAN or an optional private network such as Tailscale.

## Fast installation

### Windows

Download the repository, open PowerShell in its folder and run:

```powershell
.\install.ps1 -Role server -Client laptop,desktop
```

On each controlled computer:

```powershell
.\install.ps1 -Role client -Server YOUR-SERVER-NAME -ScreenName laptop
```

### macOS and Linux

```bash
git clone https://github.com/rivonildo/barrier-remote-control.git
cd barrier-remote-control
chmod +x install.sh
./install.sh install --role server --client laptop --client desktop
```

On each controlled computer:

```bash
./install.sh install --role client --server YOUR-SERVER-NAME --screen-name laptop
```

## Install with Hermes

Send Hermes this repository URL and a precise instruction:

```text
Install this repository on this computer:
https://github.com/rivonildo/barrier-remote-control

Role: client
Server: YOUR-SERVER-NAME
Screen name: laptop
Transport: lan
Run the repository tests first. Do not disable TLS and do not accept an unknown fingerprint for me.
```

For the computer with the physical keyboard and mouse:

```text
Install https://github.com/rivonildo/barrier-remote-control
as server, with clients laptop and desktop, using LAN.
Run tests first and show me any permission prompt that requires my approval.
```

Hermes can execute the process, but it must not silently approve a new TLS fingerprint, macOS Accessibility permission or Tailscale login. Those actions establish trust and remain with the user.

The helpers do not automate Deskflow's role selection or TLS trust. After installation, select the requested role in the Deskflow GUI, import/apply the displayed layout, port and server address, keep the default TLS settings enabled, and review the peer fingerprint.

## Common options

### PowerShell

```powershell
.\install.ps1 `
  -Role server `
  -ScreenName workstation `
  -Client laptop,desktop `
  -Transport tailscale `
  -NonInteractive
```

### Shell

```bash
./install.sh install \
  --role server \
  --screen-name workstation \
  --client laptop \
  --client desktop \
  --transport tailscale \
  --non-interactive
```

Supported options:

- `server` or `client` role;
- custom screen name;
- multiple server-side clients;
- `lan` or `tailscale` transport;
- custom TCP port;
- non-interactive mode;
- dry-run mode;
- install without starting Deskflow;
- `doctor` diagnostics.

Run `./install.sh --help` or `Get-Help .\install.ps1 -Detailed` for the local interface.

## Three-computer example

```text
                      encrypted TCP/TLS :24800
Notebook A (client) ─────────┐
                             ├── Desktop (server: keyboard + mouse)
Notebook B (client) ─────────┘
```

Server:

```bash
./install.sh install --role server \
  --screen-name desktop \
  --client notebook-a \
  --client notebook-b
```

Clients:

```bash
./install.sh install --role client --server desktop --screen-name notebook-a
./install.sh install --role client --server desktop --screen-name notebook-b
```

The generated default layout places clients to the right in the order supplied. You can rearrange them visually in Deskflow.

## Optional Tailscale

Tailscale is useful when computers are on different networks. It is **not required** for a normal LAN.

1. Install and authenticate Tailscale using its official application on every computer.
2. Prefer a stable MagicDNS name as `--server` instead of committing a `100.x` address.
3. Use Tailscale grants/ACLs to allow only intended clients to reach TCP port 24800.
4. Keep Deskflow TLS enabled as defense in depth.

This repository never accepts, stores or commits Tailscale authentication keys.

## Security model

- The helpers do not pass core TLS flags or launch core binaries; verify that Deskflow's default TLS setting remains enabled in the GUI.
- A new peer fingerprint must be reviewed before trust is established.
- When `deskflow-server.exe` is discoverable, Windows inbound access is limited to that executable, the configured TCP port, Private profile and either local subnet or Tailscale CGNAT range. If it is not discoverable, the helper creates no firewall rule.
- Downloads use the operating system package manager instead of executing an arbitrary mutable URL.
- Generated files live outside the repository.

Read [SECURITY.md](SECURITY.md) before deploying on an untrusted or corporate network. See the [product roadmap](ROADMAP.md) for clipboard confidence tests, professional profiles, lab deployment and the guided desktop experience. Portuguese real-world examples are available in [docs/USE_CASES.pt-BR.md](docs/USE_CASES.pt-BR.md).

## Troubleshooting

Run diagnostics:

```powershell
.\install.ps1 doctor
```

```bash
./install.sh doctor
```

Frequent checks:

- screen names are case-sensitive and must match the server layout;
- Scroll Lock can prevent switching;
- macOS needs Accessibility and, on recent versions, Local Network permission;
- Linux Wayland needs compatible `libei`/`libportal`; Flatpak is the recommended fallback;
- an enterprise firewall policy can override local rules;
- do not expose TCP 24800 directly to the public Internet.

## Project status and scope

This repository is an installer/configuration helper. Deskflow itself is developed by the [Deskflow project](https://github.com/deskflow/deskflow). No Deskflow or Barrier binaries are redistributed here.

Legacy scripts and deployment configuration were removed because they installed an unmaintained release, disabled application TLS and contained deployment-specific identifiers.

## Contributing

Issues and pull requests are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md). Please do not include real IP addresses, hostnames, usernames, logs with personal data, certificates, tokens or authentication URLs.

## License

The helper scripts and documentation in this repository are available under the [MIT License](LICENSE). Deskflow is a separate GPL-2.0 project with its own license and OpenSSL exception.
