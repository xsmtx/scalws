#!/bin/sh
# ScalWS installer: adds the signed ScalWS apt repository and installs the scalws package.
#
#   curl -fsSL https://raw.githubusercontent.com/xsmtx/scalws/main/install.sh | sudo sh
#
# On a cPanel server the installer offers to let ScalWS replace Apache; answer up front with
#   curl -fsSL https://raw.githubusercontent.com/xsmtx/scalws/main/install.sh | sudo sh -s -- --panel=cpanel
# (--panel=none leaves Apache alone). Without cPanel the option has no effect.
#
# Ubuntu 24.04+ or Debian 13+, amd64. The package starts the server on ports 80 and 443;
# then publish a site with: sudo scalwsctl site add example.com
set -eu

KEYRING=/usr/share/keyrings/scalws-archive-keyring.gpg
FINGERPRINT=0B49CE4488DC3A3E4F631218CBBBF99C69B99EF0

fail() { echo "scalws install: $*" >&2; exit 1; }

usage() { echo "usage: install.sh [--panel=cpanel|none]" >&2; }

PANEL=""
for arg in "$@"; do
    case "$arg" in
        --panel=cpanel) PANEL=cpanel ;;
        --panel=none) PANEL=none ;;
        -h|--help) usage; exit 0 ;;
        *) usage; fail "unknown argument: $arg" ;;
    esac
done

[ "$(id -u)" -eq 0 ] || fail "run as root, e.g.: curl -fsSL https://raw.githubusercontent.com/xsmtx/scalws/main/install.sh | sudo sh"
[ -r /etc/os-release ] || fail "unsupported system (no /etc/os-release)"
. /etc/os-release
case "${ID:-}" in
    ubuntu) min=24.04 ;;
    debian) min=13 ;;
    *) fail "unsupported system: ${PRETTY_NAME:-unknown} (needs Ubuntu 24.04+ or Debian 13+)" ;;
esac
if [ "$(printf '%s\n%s\n' "$min" "${VERSION_ID:-0}" | sort -V | head -n1)" != "$min" ]; then
    fail "${PRETTY_NAME:-this system} is too old (needs ${ID} ${min} or later)"
fi
[ "$(dpkg --print-architecture)" = amd64 ] || fail "only amd64 packages are published"

export DEBIAN_FRONTEND=noninteractive
if ! command -v curl >/dev/null 2>&1; then
    apt-get update -qq && apt-get install -y -qq curl ca-certificates
fi

echo "Adding the ScalWS apt repository"
tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT
curl -fsSL https://apt.scalws.com/scalws-archive-keyring.gpg -o "$tmp"
# Check the signing key's fingerprint when gpg is available.
if command -v gpg >/dev/null 2>&1; then
    gpg --show-keys --with-colons "$tmp" 2>/dev/null | grep -q "^fpr:*${FINGERPRINT}:" \
        || fail "the downloaded repository key does not have fingerprint ${FINGERPRINT}"
fi
install -m 0644 "$tmp" "$KEYRING"
echo "deb [signed-by=${KEYRING}] https://apt.scalws.com stable main" > /etc/apt/sources.list.d/scalws.list

echo "Installing scalws"
apt-get update -qq
apt-get install -y scalws

enable_panel() {
    if ! scalwsctl panel enable cpanel; then
        echo "ScalWS is installed, but switching from Apache failed. The error above says what was undone and whether Apache (httpd) serves port 80 again. Fix the cause, then retry: sudo scalwsctl panel enable cpanel" >&2
        exit 1
    fi
}

if [ -x /usr/local/cpanel/cpanel ]; then
    case "$PANEL" in
        cpanel) enable_panel ;;
        none) ;;
        *)
            if ( : </dev/tty ) 2>/dev/null; then
                printf 'cPanel found. Let ScalWS replace Apache? [y/N] ' >/dev/tty
                read -r answer </dev/tty || answer=""
                case "$answer" in
                    [yY]*) enable_panel ;;
                    *) echo "Later: sudo scalwsctl panel enable cpanel" ;;
                esac
            else
                echo "cPanel found. To let ScalWS replace Apache: sudo scalwsctl panel enable cpanel"
            fi ;;
    esac
fi
