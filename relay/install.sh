#!/bin/sh
# PMS relay — mac/linux one-line installer.
# Usage (from the PMS's Integrations page):
#   curl -fsSL https://hotel-assistant.github.io/releases/relay/install.sh | sh
# Removes any PREVIOUS install first (service + machine directory), then downloads
# the current build and starts the browser setup page. curl adds no quarantine flag
# and the file lands outside any TCC-protected folder, so the two macOS traps of a
# manual download (Gatekeeper on ~/Downloads, root's missing Full Disk Access)
# never arise. The setup page handles pairing and the elevated service install.
#
# "The current build" is whatever relay/stable.json on the releases site names (the
# releases repo holds several components, so GitHub's releases/latest means nothing):
# the asset is downloaded by that manifest's exact url and its sha256 checked — a
# mismatch refuses. The manifest itself is verified against the vendor release key
# below when an OpenSSL 3 `openssl` is on PATH (Ed25519 needs `pkeyutl -rawin`; the
# LibreSSL macOS ships cannot) — best effort: without one the check is skipped with a
# note, and the relay still refuses any self-update the vendor did not sign.
#
# Env: RELAY_RELEASES_SITE overrides the site (tests, mirrors);
#      RELAY_INSTALL_DRY_RUN=1 stops after the verified download (touches nothing else).
set -eu

site="${RELAY_RELEASES_SITE:-https://hotel-assistant.github.io/releases}"
manifest_url="$site/relay/stable.json"

# EXACTLY apps/relay/src/releaseKey.ts RELEASE_PUBLIC_KEY_PEM (a test keeps them equal).
release_public_key='-----BEGIN PUBLIC KEY-----
MCowBQYDK2VwAyEAg/1JeLVfEbAPxc6foUODJup4vggSBMhKXEPkKUuJAFU=
-----END PUBLIC KEY-----'

dir="${TMPDIR:-/tmp}/pms-relay-install"
mkdir -p "$dir"
manifest="$dir/stable.json"

# One field of one files entry. The manifest is machine-written by publish.mjs with
# JSON.stringify(…, null, 2): one key per line, each files entry a `"<platform>": {` line
# followed by its fields up to the closing `}` — so awk suffices and jq is not needed.
manifest_field() {
  awk -v key="\"$1\": {" -v field="\"$2\": \"" '
    index($0, key) { inside = 1; next }
    inside && /}/ { exit }
    inside && (i = index($0, field)) {
      v = substr($0, i + length(field)); sub(/".*$/, "", v); print v; exit
    }' "$manifest"
}

echo "Reading the current relay release ($manifest_url)..."
curl -fsSL -o "$manifest" "$manifest_url"

if openssl version 2>/dev/null | grep -q '^OpenSSL [3-9]'; then
  curl -fsSL -o "$dir/stable.json.sig.b64" "$manifest_url.sig"
  printf '%s\n' "$release_public_key" >"$dir/release-key.pem"
  openssl base64 -d -A -in "$dir/stable.json.sig.b64" -out "$dir/stable.json.sig"
  if ! openssl pkeyutl -verify -pubin -inkey "$dir/release-key.pem" -rawin \
    -in "$manifest" -sigfile "$dir/stable.json.sig" >/dev/null 2>&1; then
    echo "ERROR: $manifest_url is not signed by the vendor release key. Refusing to install."
    exit 1
  fi
  echo "Release manifest signature verified."
else
  echo "Note: no OpenSSL 3 found — skipping the release manifest signature check (the download is still checked against its sha256)."
fi

os=$(uname -s)
arch=$(uname -m)
case "$os-$arch" in
  Darwin-arm64) platform="darwin-arm64" ;;
  Linux-x86_64) platform="linux-x64" ;;
  Linux-aarch64 | Linux-arm64) platform="linux-arm64" ;;
  *)
    echo "No prebuilt relay for $os/$arch. Use the portable bundle (needs Node 24+):"
    echo "  $(manifest_field bundle url)"
    echo "  sha256 $(manifest_field bundle sha256)"
    exit 1
    ;;
esac

url=$(manifest_field "$platform" url)
expected=$(manifest_field "$platform" sha256)
if [ -z "$url" ] || [ -z "$expected" ]; then
  echo "ERROR: $manifest_url has no $platform build. Refusing to install."
  exit 1
fi
asset=$(manifest_field "$platform" path)
bin="$dir/${asset:-relay-$platform}"

echo "Downloading the PMS relay ($platform)..."
curl -fsSL -o "$bin" "$url"
if command -v sha256sum >/dev/null 2>&1; then
  actual=$(sha256sum "$bin" | awk '{print $1}')
elif command -v shasum >/dev/null 2>&1; then
  actual=$(shasum -a 256 "$bin" | awk '{print $1}')
else
  echo "ERROR: neither sha256sum nor shasum is available to check the download. Refusing to install."
  exit 1
fi
if [ "$actual" != "$expected" ]; then
  rm -f "$bin"
  echo "ERROR: the download does not match the release manifest (sha256 $actual, expected $expected). Refusing to install."
  exit 1
fi
chmod +x "$bin"
echo "Download verified (sha256 $actual)."
if [ "${RELAY_INSTALL_DRY_RUN:-}" = "1" ]; then
  echo "RELAY_INSTALL_DRY_RUN=1: stopping before any change to this machine ($bin)."
  exit 0
fi

# A previous install? Clean it COMPLETELY before setting up — service, config,
# spool, old binary — so a reinstall never inherits a half-broken state.
# (sudo reads its password from the terminal even when this script arrives on a
# pipe, which is exactly the curl | sh case.)
if [ "$os" = "Darwin" ]; then machine_dir="/Library/Application Support/pms-relay"; else machine_dir="/etc/pms-relay"; fi
if [ -d "$machine_dir" ]; then
  echo "A previous install exists — removing it first (your admin password may be asked)."
  sudo "$bin" uninstall --purge </dev/tty || true
  # VERIFY, never assume: one silent sudo/launchctl hiccup here previously led to
  # "Starting setup" → "already configured" → nothing visibly happening at all.
  if [ -d "$machine_dir" ]; then
    echo ""
    echo "ERROR: the previous install could not be removed ($machine_dir still exists)."
    echo "Run this, then paste the install command again:"
    echo "  sudo \"$bin\" uninstall --purge"
    exit 1
  fi
fi

echo "Starting setup — your browser will open."
exec "$bin" setup </dev/tty
