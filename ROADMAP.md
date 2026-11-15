# Product roadmap

## Product thesis

Deskflow already provides the cross-platform input engine. This project should not duplicate that mature codebase. Its opportunity is the missing **experience layer**: installation, safe pairing, diagnostics and practical workflows for people who use several computers every day.

The signature workflow is simple:

> Copy on one computer, move the pointer to another screen, paste — without sending yourself a message, opening cloud storage or changing keyboards.

## Audience

- Developers and vibe-coding professionals running editors, terminals, browsers and AI tools across several machines.
- IT support, infrastructure and security professionals operating isolated labs.
- Content creators with an editing workstation plus capture, streaming or reference computers.
- QA teams testing Windows, macOS and Linux together.
- Home-office users combining personal and corporate computers without installing remote-desktop software.

## Principles

1. **Companion, not fork:** reuse maintained Deskflow and contribute engine fixes upstream.
2. **Five-minute success:** guide users from repository link to a working first paste.
3. **Trust is visible:** no silent peer selection, TLS downgrade or fingerprint approval.
4. **Cross-platform first:** Windows, macOS and Linux are equal targets.
5. **Practical diagnostics:** explain exactly what failed and how to fix it.
6. **No lock-in:** generated configuration remains readable and exportable.

## v1 — Easy Setup

- [x] Windows, macOS and Linux installers.
- [x] Explicit server/client roles.
- [x] Multiple-client layouts.
- [x] LAN and optional Tailscale modes.
- [x] TLS and fingerprint verification retained.
- [x] Dry-run, non-interactive and doctor commands.
- [x] Hermes-ready installation instructions.
- [ ] Signed release scripts and checksum manifest.
- [ ] Animated setup demo and real three-computer validation matrix.
- [ ] Automatic release artifacts with one file per operating system.

## v1.1 — Clipboard Confidence

- [ ] Clipboard health test: copy a generated nonce, cross the screen and verify without storing clipboard contents in logs.
- [ ] Detect competing clipboard synchronizers such as KDE Connect, remote desktop and virtualization tools.
- [ ] Configurable clipboard size limit with a warning for large images that can cause handoff stutter.
- [ ] Per-computer clipboard enable/disable profiles.
- [ ] Privacy mode hotkey to pause clipboard sharing before handling passwords or confidential data.
- [ ] Metadata-only diagnostics: type, byte size, generation and hash — never content.

## v1.2 — Pro Workflows

- [ ] Profiles: `coding`, `support`, `streaming`, `lab` and `privacy`.
- [ ] Quick device switch and cycle hotkeys.
- [ ] Emergency release shortcut documented and tested on every platform.
- [ ] Sleep/wake and reconnect diagnostics.
- [ ] Keyboard-layout checks for AltGr, dead keys, ABNT2 and international layouts.
- [ ] Multi-monitor layout validator and visual topology export.
- [ ] Latency test with LAN-versus-Tailscale recommendation.

## v1.3 — Team and Lab Edition

- [ ] Export/import a sanitized deployment bundle.
- [ ] Generate Tailscale grant/ACL examples for exact devices and TCP 24800.
- [ ] Fleet inventory with device names, OS, Deskflow version and health only.
- [ ] Policy checks for TLS, firewall scope and unsupported versions.
- [ ] Idempotent unattended deployment examples for common management tools.
- [ ] Offline installation manifest for controlled environments.

## v2 — Guided Desktop Experience

- [ ] Small cross-platform setup wizard around the same validated CLI model.
- [ ] Drag-and-drop visual screen layout.
- [ ] Pairing code plus human-verifiable fingerprint comparison.
- [ ] Live connection map and clear recovery actions.
- [ ] Optional update notifications without background telemetry.

## Explicit non-goals

- Reimplementing Deskflow's keyboard/mouse protocol.
- Shipping a hidden remote-control agent.
- Automatically trusting devices or authentication prompts.
- Recording clipboard contents, keystrokes or usage telemetry.
- Promising file drag-and-drop where the underlying platform does not support it.

## How features are selected

Prioritize changes that shorten time-to-first-success, make clipboard handoff reliable, prevent security mistakes or solve a repeatedly documented multi-computer workflow. Every feature should have a reproducible test across at least two operating systems before it is advertised as supported.
