#!/usr/bin/env sh
set -eu

PROJECT="Deskflow Remote"
VERSION="1.27.0"
PORT="24800"
ROLE=""
SERVER=""
SCREEN_NAME="$(hostname 2>/dev/null | cut -d. -f1)"
CLIENTS=""
TRANSPORT="lan"
NON_INTERACTIVE=0
START=1
DRY_RUN=0
TAILSCALE_COMMAND="${DESKFLOW_REMOTE_TAILSCALE_COMMAND:-tailscale}"

usage() {
  cat <<'EOF'
Deskflow Remote — installer and configuration helper

Usage:
  ./install.sh install [options]
  ./install.sh doctor

Options:
  --role server|client       Configure this computer's role
  --server HOST[:PORT]       Server address (required for clients)
  --screen-name NAME         Deskflow screen name (default: hostname)
  --client NAME              Add a server-side client; repeatable
  --transport lan|tailscale  Network transport (default: lan)
  --port PORT                TCP port (default: 24800)
  --no-start                 Install/configure without launching
  --non-interactive          Never prompt; fail if data is missing
  --dry-run                  Print actions without changing the system
  -h, --help                 Show this help

Examples:
  ./install.sh install --role server --client laptop --client desktop
  ./install.sh install --role client --server 100.64.0.10 --screen-name laptop
EOF
}

fail() { printf 'ERROR: %s\n' "$*" >&2; exit 2; }
info() { printf '==> %s\n' "$*"; }
run() { if [ "$DRY_RUN" -eq 1 ]; then printf '+ %s\n' "$*"; else "$@"; fi; }
valid_name() { printf '%s' "$1" | grep -Eq '^[A-Za-z0-9][A-Za-z0-9._-]{0,62}$'; }
valid_port() { case "$1" in *[!0-9]*|'') return 1;; esac; [ "$1" -ge 1 ] && [ "$1" -le 65535 ]; }

COMMAND="${1:-install}"
case "$COMMAND" in -h|--help) usage; exit 0;; esac
[ "$#" -gt 0 ] && shift || true
while [ "$#" -gt 0 ]; do
  case "$1" in
    --role) [ "$#" -ge 2 ] || fail '--role needs a value'; ROLE="$2"; shift 2 ;;
    --server) [ "$#" -ge 2 ] || fail '--server needs a value'; SERVER="$2"; shift 2 ;;
    --screen-name) [ "$#" -ge 2 ] || fail '--screen-name needs a value'; SCREEN_NAME="$2"; shift 2 ;;
    --client) [ "$#" -ge 2 ] || fail '--client needs a value'; CLIENTS="${CLIENTS}${CLIENTS:+ }$2"; shift 2 ;;
    --transport) [ "$#" -ge 2 ] || fail '--transport needs a value'; TRANSPORT="$2"; shift 2 ;;
    --port) [ "$#" -ge 2 ] || fail '--port needs a value'; PORT="$2"; shift 2 ;;
    --non-interactive) NON_INTERACTIVE=1; shift ;;
    --no-start) START=0; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) fail "unknown option: $1" ;;
  esac
done

find_deskflow() {
  for b in deskflow; do
    command -v "$b" 2>/dev/null && return 0
  done
  return 1
}

install_deskflow() {
  if find_deskflow >/dev/null 2>&1; then info 'Deskflow is already installed'; return; fi
  OS="$(uname -s)"
  case "$OS" in
    Darwin)
      command -v brew >/dev/null 2>&1 || fail 'Homebrew is required on macOS: https://brew.sh'
      run brew tap deskflow/tap
      run brew install deskflow
      ;;
    Linux)
      if command -v flatpak >/dev/null 2>&1; then
        run flatpak install -y flathub org.deskflow.deskflow
      elif command -v apt-get >/dev/null 2>&1; then
        run sudo apt-get update
        run sudo apt-get install -y deskflow
      elif command -v dnf >/dev/null 2>&1; then run sudo dnf install -y deskflow
      elif command -v pacman >/dev/null 2>&1; then run sudo pacman -S --needed --noconfirm deskflow
      elif command -v zypper >/dev/null 2>&1; then run sudo zypper --non-interactive install deskflow
      else fail 'No supported package manager found. Install Deskflow from https://github.com/deskflow/deskflow/releases'; fi
      ;;
    *) fail "unsupported operating system: $OS" ;;
  esac
}

config_home() {
  case "$(uname -s)" in
    Darwin) printf '%s/Library/Application Support/DeskflowRemote' "$HOME" ;;
    *) printf '%s/deskflow-remote' "${XDG_CONFIG_HOME:-$HOME/.config}" ;;
  esac
}

generate_server_config() {
  DIR="$(config_home)"; CFG="$DIR/server.conf"
  [ "$DRY_RUN" -eq 1 ] || mkdir -p "$DIR"
  TMP="${TMPDIR:-/tmp}/deskflow-remote.$$.conf"
  {
    echo 'section: screens'
    printf '\t%s:\n' "$SCREEN_NAME"
    for c in $CLIENTS; do printf '\t%s:\n' "$c"; done
    echo 'end'; echo; echo 'section: links'
    prev="$SCREEN_NAME"
    for c in $CLIENTS; do
      printf '\t%s:\n\t\tright = %s\n' "$prev" "$c"
      printf '\t%s:\n\t\tleft = %s\n' "$c" "$prev"
      prev="$c"
    done
    echo 'end'; echo; echo 'section: options'; echo 'end'
  } > "$TMP"
  if [ "$DRY_RUN" -eq 1 ]; then info "would write $CFG"; cat "$TMP"; rm -f "$TMP"; else mv "$TMP" "$CFG"; chmod 600 "$CFG"; fi
  printf '%s' "$CFG"
}

launch() {
  [ "$START" -eq 1 ] || return 0
  info "Opening the Deskflow GUI. Select the $ROLE role and keep the default TLS/fingerprint settings enabled."
  [ "$ROLE" != server ] || info "Import the generated layout from: $(config_home)/server.conf"
  info "Set the Deskflow TCP port to $PORT in the GUI settings."
  [ "$ROLE" != client ] || info "Set the Deskflow server address to $SERVER in the GUI."
  if command -v deskflow >/dev/null 2>&1; then
    run deskflow >/dev/null 2>&1 &
  elif command -v flatpak >/dev/null 2>&1; then run flatpak run org.deskflow.deskflow >/dev/null 2>&1 &
  elif [ "$DRY_RUN" -eq 1 ]; then printf '+ open Deskflow GUI\n'
  else fail 'Deskflow GUI launcher was not found; open Deskflow from the desktop application menu'; fi
}

doctor() {
  info "$PROJECT diagnostics"
  printf 'OS: %s\n' "$(uname -srm)"
  if find_deskflow >/dev/null 2>&1; then printf 'Deskflow: found (%s)\n' "$(find_deskflow)"; else printf 'Deskflow: not found\n'; fi
  if command -v "$TAILSCALE_COMMAND" >/dev/null 2>&1; then printf 'Tailscale: found\n'; else printf 'Tailscale: optional / not found\n'; fi
  printf 'Config directory: %s\n' "$(config_home)"
}

[ "$COMMAND" = doctor ] && { doctor; exit 0; }
[ "$COMMAND" = install ] || fail "unknown command: $COMMAND"
[ "$ROLE" = server ] || [ "$ROLE" = client ] || {
  [ "$NON_INTERACTIVE" -eq 0 ] || fail '--role is required in non-interactive mode'
  printf 'Role [server/client]: '; read -r ROLE
}
[ "$ROLE" = server ] || [ "$ROLE" = client ] || fail 'role must be server or client'
valid_name "$SCREEN_NAME" || fail 'invalid screen name'
valid_port "$PORT" || fail 'invalid port'
[ "$TRANSPORT" = lan ] || [ "$TRANSPORT" = tailscale ] || fail 'transport must be lan or tailscale'
SEEN_CLIENTS=' '
for c in $CLIENTS; do
  valid_name "$c" || fail "invalid client name: $c"
  [ "$c" != "$SCREEN_NAME" ] || fail 'client and server names must differ'
  case "$SEEN_CLIENTS" in *" $c "*) fail "duplicate client name: $c";; esac
  SEEN_CLIENTS="$SEEN_CLIENTS$c "
done
if [ "$ROLE" = client ] && [ -z "$SERVER" ]; then
  [ "$NON_INTERACTIVE" -eq 0 ] || fail '--server is required for a client in non-interactive mode'
  printf 'Server hostname or IP: '; read -r SERVER
fi
if [ "$TRANSPORT" = tailscale ] && ! command -v "$TAILSCALE_COMMAND" >/dev/null 2>&1; then
  [ "$NON_INTERACTIVE" -eq 0 ] || fail 'Tailscale was selected but is not installed. Install and authenticate it before a non-interactive run.'
  info 'Tailscale was selected but is not installed. Install it from https://tailscale.com/download, sign in, then continue.'
fi
install_deskflow
[ "$ROLE" = server ] && generate_server_config
launch
info 'Setup files are ready. In Deskflow, select the role, import/apply the settings above, and verify the TLS fingerprint before accepting input.'
[ "$(uname -s)" != Darwin ] || info 'macOS: grant Accessibility and Local Network permissions when prompted.'
