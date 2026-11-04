# Owner checklist — turning `relay-releases` into `releases`

Do these in order.

1. **Merge** the `shared-releases` branch into `main` (PR, or a local merge + push).
2. **Rename the repo:**
   ```sh
   gh repo rename releases --repo Hotel-Assistant/relay-releases
   ```
   GitHub redirects the old name (git remotes, release download URLs, API).
3. **Enable GitHub Pages** (branch `main`, folder `/`):
   ```sh
   gh api -X POST repos/Hotel-Assistant/releases/pages -f 'source[branch]=main' -f 'source[path]=/'
   ```
   Then confirm `https://hotel-assistant.github.io/releases/relay/stable.json` answers 200
   (the first build takes a minute or two). `.nojekyll` is already in the repo.
4. **`RELEASES_TOKEN` still targets the repo.** The fine-grained PAT binds by repository id, so the
   rename should not affect it — check under GitHub → Settings → Developer settings →
   Fine-grained tokens that it lists `Hotel-Assistant/releases` with Contents: read and write.
   The same token is needed as a secret by both `Hotel-Assistant/pms-relay` and `iezhkov/pms`.
5. **GHCR package `hotel-assistant/pms`** (exists after the first PMS image push): Packages
   settings → visibility **Public**, and "Connect repository" → `Hotel-Assistant/releases`.
6. **Pages live → relay release.** Cut the first relay release through the new workflow
   (`relay-<version>-r<build>`); it overwrites `relay/stable.json`, adds `relay/stable.json.sig`,
   and replaces `relay/install.sh` / `install.ps1`. Check the Pages install one-liner afterwards.
7. **→ PMS release.** Tag `pms-<version>`; the workflow writes `pms/stable.json`, `.sig` and
   `pms/notes/<version>.md`. Then `npm run release:apply -- <version>` against prod.
