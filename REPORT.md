# Historical implementation report

The first prototype automated a two-computer Windows deployment using Barrier 2.4.0 and Tailscale. It demonstrated that one physical keyboard and mouse could control multiple machines across a private network.

A subsequent security review found that the prototype was not suitable for public reuse:

- Barrier 2.4.0 is unmaintained and no longer receives security fixes.
- Application-layer TLS was disabled.
- Firewall rules were broader than intended.
- Remote installers were executed without integrity verification.
- Peer discovery could select the wrong machine.
- The implementation was Windows-only and limited to one client.
- Deployment-specific machine and network identifiers appeared in documentation and history.

The current project uses maintained Deskflow, supports Windows/macOS/Linux, avoids direct core launches, guides users through role selection and layout import in the GUI, and requires them to retain TLS defaults and review peer fingerprints. It allows multiple explicit clients, makes Tailscale optional, uses package managers and keeps generated state outside the repository. On Windows it creates a firewall rule only when the exact server executable can be identified.

No passwords, API keys, private keys or authentication tokens were found during the audit. Historical identifiers were privacy-sensitive but were not credentials.
