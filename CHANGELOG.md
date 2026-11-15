# Changelog

All notable changes to this project are documented here.

## Unreleased

### Changed

- Replaced the unmaintained Barrier installer path with maintained Deskflow.
- Added Windows, macOS and Linux installation helpers.
- Added role/layout inputs and GUI guidance; role selection and settings import remain explicit user actions in Deskflow.
- Made Tailscale optional instead of mandatory.
- Avoided direct core launches so Deskflow GUI defaults control TLS; users must verify TLS and peer fingerprints.
- Scoped Windows firewall access only when the exact server executable is discoverable; otherwise no rule is created.
- Removed deployment-specific hostnames, usernames, network addresses and logs.

### Added

- Hermes-ready installation instructions.
- Security policy, contribution guide, MIT license and CI checks.
- Dry-run, diagnostics and non-interactive modes.
