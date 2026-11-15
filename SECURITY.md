# Security Policy

## Supported scope

This project maintains only the installer and configuration helpers in this repository. Deskflow and Tailscale are independent upstream projects with their own security policies.

## Report a vulnerability

Please use GitHub's private vulnerability reporting feature for this repository. Do not open a public issue containing credentials, private keys, authentication URLs, private hostnames, IP addresses or exploitable details.

Include the affected commit, operating system, reproduction steps and impact. Remove personal data from logs.

## Deployment rules

- Never expose TCP 24800 directly to the public Internet.
- Keep Deskflow TLS and fingerprint checking enabled.
- Review a new peer fingerprint through a trusted channel before accepting it.
- Restrict LAN firewall scope or Tailscale grants/ACLs to intended machines.
- Never place Tailscale auth keys, certificates or tokens in command-line arguments, repository files or issue reports.
- On managed computers, obtain administrator approval before modifying packages or firewall rules.

## Threat model

This tool helps install and configure software that transports keyboard input and clipboard data. A compromised authorized peer can observe or inject sensitive content. TLS protects traffic but does not make an untrusted endpoint safe. Use dedicated device identities, least-privilege network policy and current software.

## Privacy

Generated state is stored outside the repository. Do not commit logs, hostnames, usernames, IP addresses, fingerprints or generated configuration from real deployments.
