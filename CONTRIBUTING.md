# Contributing

Thank you for improving Deskflow Remote.

## Development workflow

1. Fork the repository and create a focused branch.
2. Keep Windows PowerShell 5.1 compatibility in `install.ps1`.
3. Keep `install.sh` compatible with POSIX `sh`.
4. Run `./tests/test.sh` before opening a pull request.
5. Explain the operating systems and modes you tested.

## Security and privacy requirements

Pull requests must not:

- disable Deskflow TLS or fingerprint checks;
- execute downloads without package-manager or integrity controls;
- broaden firewall rules without a documented reason;
- silently select an arbitrary network peer;
- include real credentials, tokens, auth URLs, private keys or certificates;
- include personal hostnames, usernames, IP addresses or unsanitized logs.

Use neutral fixture names such as `server`, `client-a` and `client-b`, and documentation ranges such as `192.0.2.0/24` when an example address is necessary.

## Style

- Fail closed when security validation is uncertain.
- Keep interactive and non-interactive behavior deterministic.
- Every success message must follow a checked postcondition.
- Prefer explicit arguments over discovery when identity matters.
