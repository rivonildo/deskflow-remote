#!/usr/bin/env sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT"

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "PASS: $*"; }

sh -n install.sh
pass 'install.sh parses as POSIX shell'

./install.sh --help >/dev/null
pass 'help command works'

./install.sh doctor >/dev/null
pass 'doctor command works'

out=$(./install.sh install --role server --screen-name server --client client-a --client client-b --port 24801 --non-interactive --dry-run)
printf '%s' "$out" | grep -q 'right = client-a' || fail 'first client layout missing'
printf '%s' "$out" | grep -q 'right = client-b' || fail 'second client layout missing'
printf '%s' "$out" | grep -q 'TCP port to 24801' || fail 'custom port guidance missing'
printf '%s' "$out" | grep -q 'Opening the Deskflow GUI' || fail 'supported GUI launch path missing'
if printf '%s' "$out" | grep -Eq 'deskflow-(server|client)|--address|--name'; then
  fail 'direct Deskflow core launch detected'
fi
pass 'multi-client server dry-run uses GUI and preserves custom-port guidance'

if ./install.sh install --role server --screen-name server --client client-a --client client-a --non-interactive --dry-run --no-start >/dev/null 2>&1; then
  fail 'duplicate client names should fail'
fi
pass 'duplicate client names are rejected'

if DESKFLOW_REMOTE_TAILSCALE_COMMAND=definitely-missing-tailscale ./install.sh install --role server --screen-name server --transport tailscale --non-interactive --dry-run --no-start >/dev/null 2>&1; then
  fail 'missing Tailscale should fail in non-interactive mode'
fi
pass 'non-interactive Tailscale transport fails closed when unavailable'

state=$(mktemp -d)
trap 'rm -rf "$state"' EXIT HUP INT TERM
mkdir -p "$state/bin"
printf '#!/bin/sh\nexit 0\n' > "$state/bin/deskflow"
chmod +x "$state/bin/deskflow"
PATH="$state/bin:$PATH" HOME="$state" XDG_CONFIG_HOME="$state/config" ./install.sh install --role server --screen-name server --client client-a --non-interactive --no-start >/dev/null
config="$state/config/deskflow-remote/server.conf"
[ -f "$config" ] || fail 'server config was not generated'
last_byte=$(od -An -t u1 "$config" | tr -s ' ' '\n' | sed '/^$/d' | tail -n 1)
[ "$last_byte" = 10 ] || fail 'generated server config must end with a newline'
pass 'generated config ends with a newline'

if ./install.sh install --role client --non-interactive --dry-run --no-start >/dev/null 2>&1; then
  fail 'client without server should fail'
fi
pass 'non-interactive mode fails closed on missing server'

if ./install.sh install --role server --screen-name '../bad' --non-interactive --dry-run --no-start >/dev/null 2>&1; then
  fail 'invalid screen name should fail'
fi
pass 'screen names are validated'

if grep -RInE --exclude-dir=.git --exclude='test.sh' '(--disable-crypto|ExecutionPolicy Bypass|BEGIN (RSA|OPENSSH|EC|DSA) PRIVATE KEY|tailscale.*auth.*key[[:space:]]*=)' .; then
  fail 'unsafe pattern found'
fi
pass 'unsafe transport and credential patterns are absent'

for f in README.md SECURITY.md CONTRIBUTING.md LICENSE install.ps1 install.sh; do
  [ -s "$f" ] || fail "$f is missing or empty"
done
pass 'required project files exist'
