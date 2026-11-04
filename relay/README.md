# relay

- `stable.json` — the current relay release: `component`, `version`, `tag`, `builtAt`, and per
  platform `path`, `url`, `sha256`, `bytes`, `kind`. Download by the `url` (exact tag), never by
  GitHub's `releases/latest`.
- `install.sh`, `install.ps1` — the one-line installers, served at
  `https://hotel-assistant.github.io/releases/relay/install.sh` (and `.ps1`).

**Seeded by hand.** This `stable.json` was seeded from the `v0.6.0-r16` release's
`manifest.json` (plus `component`, `tag` and absolute `url`s) and has **no `stable.json.sig`**:
the release private key is not available outside the release workflow. The first relay release
through the new workflow (`relay-<version>-r<build>`) overwrites `stable.json` and writes
`stable.json.sig`. Until then installers and consumers treat a missing `.sig` as an **unsigned
pointer**: they may use it, but they must still check each asset's sha256 and its own
`<asset>.sig` (which `v0.6.0-r16` does carry).

`install.sh` / `install.ps1` are verbatim copies of the `v0.6.0-r16` release assets (they still
download via the old repo's `releases/latest`); the next relay release replaces them with the
versions that read `stable.json`.
