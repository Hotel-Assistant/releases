# pms-relay releases

Binary releases of the PMS on-prem relay (closed source). Each release carries:

- `relay-win-x64.exe`, `relay-linux-x64`, `relay-linux-arm64`, `relay-darwin-arm64` — self-contained binaries (no Node required)
- `relay.js` — portable single-file bundle (needs Node ≥ 24)
- `manifest.json` — `{version, builtAt, files: {platform: {path, sha256, bytes, kind}}}`

Install: download from your PMS (Settings → Integrations → Download relay), then run the one-line install command shown there. Published automatically from the private `pms-relay` repo on every push to main.
