#!/bin/sh
# Copied verbatim from the v0.6.0-r16 release assets; the next relay release overwrites this file.
# PMS relay — mac/linux one-line installer.
# Usage (from the PMS's Integrations page):
#   curl -fsSL https://github.com/Hotel-Assistant/relay-releases/releases/latest/download/install.sh | sh
# Removes any PREVIOUS install first (service + machine directory), then downloads
# the current build and starts the browser setup page. curl adds no quarantine flag
# and the file lands outside any TCC-protected folder, so the two macOS traps of a
# manual download (Gatekeeper on ~/Downloads, root's missing Full Disk Access)
# never arise. The setup page handles pairing and the elevated service install.
set -eu

os=$(uname -s)
arch=$(uname -m)
case "$os-$arch" in
  Darwin-arm64) asset="relay-darwin-arm64" ;;
  Linux-x86_64) asset="relay-linux-x64" ;;
  Linux-aarch64 | Linux-arm64) asset="relay-linux-arm64" ;;
  *)
    echo "No prebuilt relay for $os/$arch. Use the portable bundle (needs Node 24+):"
    echo "  https://github.com/Hotel-Assistant/relay-releases/releases/latest/download/relay.js"
    exit 1
    ;;
esac

dir="${TMPDIR:-/tmp}/pms-relay-install"
mkdir -p "$dir"
bin="$dir/$asset"

echo "Downloading the PMS relay ($asset)..."
curl -fsSL -o "$bin" "https://github.com/Hotel-Assistant/relay-releases/releases/latest/download/$asset"
chmod +x "$bin"

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
