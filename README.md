# Hotel-Assistant releases

The public releases repository of the Hotel-Assistant components. It holds **artifacts,
manifests, installers and release notes only — zero source code**. The source of every
component is closed and lives elsewhere; each component's own release workflow publishes here.

This repo is served by GitHub Pages at <https://hotel-assistant.github.io/releases/>.
(It was called `Hotel-Assistant/relay-releases`; GitHub redirects the old name.)

## Components

| component | what | tag scheme | pointer |
|---|---|---|---|
| `relay` | the on-prem PMS relay (self-contained binaries + a Node bundle) | `relay-<version>-r<build>` | [`relay/stable.json`](https://hotel-assistant.github.io/releases/relay/stable.json) |
| `pms` | Tape Chart, the hotel PMS (Vercel prebuilt bundle + Docker image) | `pms-<version>` (calendar, e.g. `2026.11.0`) | [`pms/stable.json`](https://hotel-assistant.github.io/releases/pms/stable.json) |

The relay's older tags `v<version>-r<build>` (up to `v0.6.0-r16`) stay as history; new relay
releases use `relay-<version>-r<build>`.

Release assets per tag (GitHub Releases of this repo):

- relay: `relay-<platform>[.exe]`, `relay.js`, `manifest.json`, each with `<asset>.sig`, plus `install.sh`, `install.ps1`
- pms: `pms-vercel-<version>.tgz`, `manifest.json`, each with `<asset>.sig`

## How "latest" works here

Several components share this repo, so GitHub's `releases/latest` means nothing and no consumer
uses it. Each component has its own pointer on GitHub Pages:

```
https://hotel-assistant.github.io/releases/<component>/stable.json
https://hotel-assistant.github.io/releases/<component>/stable.json.sig
```

`stable.json` names the exact `tag`, `version`, `builtAt` and, per file, the absolute `url`,
`sha256` and `bytes`. Consumers download **by that exact tag**, check sha256, and verify the
signature. A component's release workflow writes `stable.json` only **after** the GitHub Release
and all its assets exist, so the pointer never names a missing asset. Unknown keys in
`stable.json` are ignored by every consumer.

## The PMS Docker image

The image is not a release asset. It lives in GHCR:

```
ghcr.io/hotel-assistant/pms:<version>       # linux/amd64 + linux/arm64, public
```

Tags are per version only (`:latest` is not moved automatically). `pms/stable.json` carries the
exact digest under `image.digest`; pin `ghcr.io/hotel-assistant/pms@sha256:…` if you want to be
byte-exact.

## Verifying a signature

Every asset has `<asset>.sig` and every `stable.json` has `stable.json.sig`. A `.sig` file is the
base64 of a 64-byte Ed25519 signature (followed at most by a newline), made with the vendor's
release key. The public key:

```
-----BEGIN PUBLIC KEY-----
MCowBQYDK2VwAyEAg/1JeLVfEbAPxc6foUODJup4vggSBMhKXEPkKUuJAFU=
-----END PUBLIC KEY-----
```

What is signed (the message bytes, UTF-8, `\n` = a single line feed, no trailing newline):

| what | message |
|---|---|
| relay asset | `pms-relay-release:v1\n<version>\n<platform>\n<sha256 hex of the asset>` |
| PMS asset | `tape-chart-release:v1\n<version>\n<asset name>\n<sha256 hex of the asset>` |
| any `stable.json` | the raw file bytes, as served |

`<platform>` is the key in the relay manifest's `files` (`win-x64`, `linux-x64`, `linux-arm64`,
`darwin-arm64`, `bundle`); the sha256 is lower-case hex.

Example with OpenSSL 3 (save the key above as `release-key.pem`):

```sh
# a relay asset
f=relay-linux-x64; v=0.6.0; p=linux-x64; tag=v0.6.0-r16
base=https://github.com/Hotel-Assistant/releases/releases/download/$tag
curl -fsSLO "$base/$f" && curl -fsSLO "$base/$f.sig"
sha=$(openssl dgst -sha256 -r "$f" | cut -d' ' -f1)
printf 'pms-relay-release:v1\n%s\n%s\n%s' "$v" "$p" "$sha" > msg.bin
base64 -d < "$f.sig" > sig.bin      # macOS: base64 -D
openssl pkeyutl -verify -pubin -inkey release-key.pem -rawin -in msg.bin -sigfile sig.bin
# → "Signature Verified Successfully"

# a stable.json pointer (the file itself is the message)
site=https://hotel-assistant.github.io/releases
curl -fsSLO "$site/pms/stable.json" && curl -fsSLO "$site/pms/stable.json.sig"
base64 -d < stable.json.sig > sig.bin
openssl pkeyutl -verify -pubin -inkey release-key.pem -rawin -in stable.json -sigfile sig.bin
```

## Installing the relay

macOS / Linux:

```sh
curl -fsSL https://hotel-assistant.github.io/releases/relay/install.sh | sh
```

Windows (PowerShell):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "irm https://hotel-assistant.github.io/releases/relay/install.ps1 | iex"
```

Your PMS shows the same commands under Settings → Integrations → Download relay. The relay's
self-update verifies every `.sig` before swapping anything.

## Updating the PMS

Vercel deployments — from a PMS checkout:

```sh
npm run release:apply -- <version>          # e.g. 2026.11.0; --stable = whatever pms/stable.json says
```

or, without the source, from an extracted `pms-vercel-<version>.tgz`:

```sh
node scripts/release/apply-vercel.mjs --version <version>
```

Both verify the signatures, run the bundle's bootstrap (database migrations first), then deploy
the prebuilt output (`vercel deploy --prebuilt --prod`). They need `VERCEL_TOKEN`,
`VERCEL_ORG_ID`, `VERCEL_PROJECT_ID` (the target project) and the deployment's four variables.
Rollback = the previous version by the same command (the database is never rolled back; a
release never carries a destructive migration).

Docker compose — set the image tag in your compose file to the new version
(`ghcr.io/hotel-assistant/pms:<version>`), then:

```sh
docker compose pull && docker compose up -d
```

Release notes: `pms/notes/<version>.md` (BG + EN).
