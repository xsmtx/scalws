#!/bin/sh
# ScalWS installer: adds the signed ScalWS repository of this system (apt, dnf, zypper or apk)
# and installs the scalws package.
#
#   curl -fsSL https://raw.githubusercontent.com/xsmtx/scalws/main/install.sh | sudo sh
#   wget -qO- https://raw.githubusercontent.com/xsmtx/scalws/main/install.sh | sh    # Alpine, as root
#
# On a cPanel, DirectAdmin or Plesk server the first install lets ScalWS take over the panel's web
# server (undo: sudo scalwsctl panel disable); --panel=none leaves it alone:
#   curl -fsSL https://raw.githubusercontent.com/xsmtx/scalws/main/install.sh | sudo sh -s -- --panel=none
#
# Systems (x86_64): Debian 12 and 13, Ubuntu 22.04, 24.04 and 26.04 (apt); AlmaLinux, Rocky Linux
# and Oracle Linux 8, 9 and 10, Fedora 44 (dnf); openSUSE Leap 15.6 and 16.0, SLES 15 SP7 and 16
# (zypper); Alpine Linux 3.24 (apk). The package starts the server on ports 80 and 443; then
# publish a site with: sudo scalwsctl site add example.com
set -eu

FINGERPRINT=0B49CE4488DC3A3E4F631218CBBBF99C69B99EF0
APT_KEYRING=/usr/share/keyrings/scalws-archive-keyring.gpg
APK_KEY=scalws-apk@scb.network-6ae1d45e.rsa.pub
APK_KEY_SHA256=d809d59bdec7e7e440558fd4b648a48dfbc69c96ee0bbc21dc853808d516abc1
APK_REPO=https://apt.scalws.com/alpine/v3.24/main

fail() { echo "scalws install: $*" >&2; exit 1; }

usage() { echo "usage: install.sh [--panel=none]" >&2; }

# Downloads URL $1 to file $2 (curl, or wget where curl is missing, as on Alpine).
fetch() {
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$1" -o "$2"
    else
        wget -qO "$2" "$1"
    fi
}

# Fingerprints of the primary keys in an OpenPGP key file, one per line.
primary_keys() {
    gpg --batch --show-keys --with-colons "$1" 2>/dev/null \
        | awk -F: '$1=="pub"{p=1;next} p&&$1=="fpr"{print $10;p=0}'
}

# Writes the repository key from the downloaded file $1 to $1.pinned, failing closed: the file
# must hold exactly one primary key, the pinned one, and the output holds only that key
# (re-exported from a scratch gpg home), never the downloaded file itself. $2 = armor: ASCII.
pin_key() {
    [ "$(primary_keys "$1")" = "$FINGERPRINT" ] \
        || fail "the downloaded repository key is not exactly the key ${FINGERPRINT}"
    armor=""
    [ "${2:-}" = armor ] && armor=--armor
    gh=$(mktemp -d)
    # shellcheck disable=SC2086
    if GNUPGHOME=$gh gpg --batch --quiet --import "$1" 2>/dev/null \
        && GNUPGHOME=$gh gpg --batch $armor --export "$FINGERPRINT" > "$1.pinned" 2>/dev/null; then
        rm -rf "$gh"
    else
        rm -rf "$gh"
        fail "could not extract the repository key ${FINGERPRINT}"
    fi
    [ "$(primary_keys "$1.pinned")" = "$FINGERPRINT" ] \
        || fail "could not extract the repository key ${FINGERPRINT}"
}

# True if version $1 is at least $2 (dotted numbers).
at_least() { [ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -n1)" = "$2" ]; }

PANEL=""
for arg in "$@"; do
    case "$arg" in
        --panel=none) PANEL=none ;;
        --panel=*) usage; fail "unknown panel option: $arg (the panel takeover is automatic; --panel=none skips it)" ;;
        -h|--help) usage; exit 0 ;;
        *) usage; fail "unknown argument: $arg" ;;
    esac
done

[ "$(id -u)" -eq 0 ] || fail "run as root, e.g.: curl -fsSL https://raw.githubusercontent.com/xsmtx/scalws/main/install.sh | sudo sh"
[ -r /etc/os-release ] || fail "unsupported system (no /etc/os-release)"
. /etc/os-release
[ "$(uname -m)" = x86_64 ] || fail "only x86_64 (amd64) packages are published"

ver=${VERSION_ID:-0}
major=${ver%%.*}
case "${ID:-}" in
    debian) [ "$major" -ge 12 ] 2>/dev/null || fail "${PRETTY_NAME:-this system} is not supported (Debian 12 or later)"; kind=apt ;;
    ubuntu) at_least "$ver" 22.04 || fail "${PRETTY_NAME:-this system} is not supported (Ubuntu 22.04 or later)"; kind=apt ;;
    almalinux|rocky|ol|rhel)
        case "$major" in 8|9|10) kind=dnf ;; *) fail "${PRETTY_NAME:-this system} is not supported (version 8, 9 or 10)" ;; esac ;;
    fedora) [ "$major" -ge 44 ] 2>/dev/null || fail "${PRETTY_NAME:-this system} is not supported (Fedora 44 or later)"; kind=dnf ;;
    opensuse-leap|sles|sled)
        case "$ver" in 15.6|15.7|16.*) kind=zypper ;; *) fail "${PRETTY_NAME:-this system} is not supported (Leap 15.6 or 16.0, SLES 15 SP7 or 16)" ;; esac ;;
    alpine)
        case "$ver" in 3.24|3.24.*) kind=apk ;; *) fail "${PRETTY_NAME:-this system} is not supported (Alpine Linux 3.24)" ;; esac ;;
    *) fail "unsupported system: ${PRETTY_NAME:-unknown} (see https://scalws.com/docs/guide/installation/#supported-systems)" ;;
esac

tmp=$(mktemp)
trap 'rm -f "$tmp" "$tmp.pinned"' EXIT

case $kind in
apt)
    export DEBIAN_FRONTEND=noninteractive
    if ! command -v curl >/dev/null 2>&1; then
        apt-get update -qq && apt-get install -y -qq curl ca-certificates
    fi
    # The repository key is installed only after its fingerprint is checked: no gpg, no install.
    if ! command -v gpg >/dev/null 2>&1; then
        apt-get update -qq && apt-get install -y -qq gnupg || true
    fi
    command -v gpg >/dev/null 2>&1 || fail "gpg is needed to verify the repository key (apt-get install gnupg)"
    echo "Adding the ScalWS apt repository"
    fetch https://apt.scalws.com/scalws-archive-keyring.gpg "$tmp"
    pin_key "$tmp"
    install -m 0644 "$tmp.pinned" "$APT_KEYRING"
    echo "deb [signed-by=${APT_KEYRING}] https://apt.scalws.com stable main" > /etc/apt/sources.list.d/scalws.list
    echo "Installing scalws"
    apt-get update -qq
    if [ "$PANEL" = none ]; then
        # The package's postinstall reads it: no panel takeover.
        SCALWS_PANEL=none apt-get install -y scalws
    else
        apt-get install -y scalws
    fi
    ;;
dnf|zypper)
    if ! command -v gpg >/dev/null 2>&1; then
        if [ $kind = dnf ]; then dnf -y -q install gnupg2 || true; else zypper -n -q install gpg2 || true; fi
    fi
    command -v gpg >/dev/null 2>&1 || fail "gpg is needed to verify the repository key"
    # The key goes into rpm's keyring only after its fingerprint is checked, so neither dnf nor
    # zypper ever asks to trust a key.
    echo "Adding the ScalWS rpm repository"
    fetch https://rpm.scalws.com/RPM-GPG-KEY-scalws "$tmp"
    pin_key "$tmp" armor
    rpm --import "$tmp.pinned"
    if [ $kind = dnf ]; then
        fetch https://rpm.scalws.com/scalws.repo "$tmp"
        install -m 0644 "$tmp" /etc/yum.repos.d/scalws.repo
        echo "Installing scalws"
        if [ "$PANEL" = none ]; then SCALWS_PANEL=none dnf -y install scalws; else dnf -y install scalws; fi
    else
        zypper -n removerepo scalws >/dev/null 2>&1 || true
        zypper -n addrepo https://rpm.scalws.com/scalws.repo
        echo "Installing scalws"
        zypper -n refresh scalws
        if [ "$PANEL" = none ]; then SCALWS_PANEL=none zypper -n install scalws; else zypper -n install scalws; fi
    fi
    ;;
apk)
    # apk trusts the key file only if its SHA-256 is the pinned one.
    echo "Adding the ScalWS apk repository"
    fetch "https://apt.scalws.com/alpine/$APK_KEY" "$tmp"
    echo "$APK_KEY_SHA256  $tmp" | sha256sum -c -s \
        || fail "the downloaded repository key is not the pinned one (SHA-256 ${APK_KEY_SHA256})"
    install -m 0644 "$tmp" "/etc/apk/keys/$APK_KEY"
    grep -qxF "$APK_REPO" /etc/apk/repositories || echo "$APK_REPO" >> /etc/apk/repositories
    echo "Installing scalws"
    apk update -q
    apk add scalws
    ;;
esac

if [ -f /var/lib/scalws-panel/state.json ]; then
    scalwsctl panel status || true
fi
