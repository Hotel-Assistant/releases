# PMS relay — Windows one-line installer.
# Usage (from the PMS's Integrations page):
#   powershell -NoProfile -ExecutionPolicy Bypass -Command "irm https://hotel-assistant.github.io/releases/relay/install.ps1 | iex"
# Removes any PREVIOUS install first (service + machine directory), then downloads
# the current build and starts the browser setup page. The setup page handles
# pairing and the elevated service install (UAC prompt).
#
# "The current build" is whatever relay/stable.json on the releases site names (the
# releases repo holds several components, so GitHub's releases/latest means nothing):
# the exe is downloaded by that manifest's exact url and its sha256 checked — a
# mismatch refuses. The manifest itself is verified against the vendor release key
# below when an OpenSSL 3 `openssl` is on PATH (.NET on Windows has no Ed25519) —
# best effort: without one the check is skipped with a note, and the relay still
# refuses any self-update the vendor did not sign. Mirrors install.sh.
#
# Env: RELAY_RELEASES_SITE overrides the site (tests, mirrors);
#      RELAY_INSTALL_DRY_RUN=1 stops after the verified download (touches nothing else).
$ErrorActionPreference = "Stop"

$site = if ($env:RELAY_RELEASES_SITE) { $env:RELAY_RELEASES_SITE } else { "https://hotel-assistant.github.io/releases" }
$manifestUrl = "$site/relay/stable.json"

# EXACTLY apps/relay/src/releaseKey.ts RELEASE_PUBLIC_KEY_PEM (a test keeps them equal).
$releasePublicKey = @"
-----BEGIN PUBLIC KEY-----
MCowBQYDK2VwAyEAg/1JeLVfEbAPxc6foUODJup4vggSBMhKXEPkKUuJAFU=
-----END PUBLIC KEY-----
"@

# The manifest is saved as raw bytes (not parsed by irm) because its signature covers exactly
# those bytes.
$manifestFile = Join-Path $env:TEMP "pms-relay-stable.json"
Write-Host "Reading the current relay release ($manifestUrl)..."
Invoke-WebRequest -UseBasicParsing -Uri $manifestUrl -OutFile $manifestFile

$openssl = Get-Command openssl -ErrorAction SilentlyContinue
if ($openssl -and ((& $openssl.Source version) -match '^OpenSSL [3-9]')) {
  $sigB64 = Join-Path $env:TEMP "pms-relay-stable.json.sig.b64"
  $sigFile = Join-Path $env:TEMP "pms-relay-stable.json.sig"
  $keyFile = Join-Path $env:TEMP "pms-relay-release-key.pem"
  Invoke-WebRequest -UseBasicParsing -Uri "$manifestUrl.sig" -OutFile $sigB64
  [IO.File]::WriteAllBytes($sigFile, [Convert]::FromBase64String((Get-Content -Raw $sigB64).Trim()))
  [IO.File]::WriteAllText($keyFile, $releasePublicKey + "`n")
  & $openssl.Source pkeyutl -verify -pubin -inkey $keyFile -rawin -in $manifestFile -sigfile $sigFile | Out-Null
  if ($LASTEXITCODE -ne 0) {
    throw "$manifestUrl is not signed by the vendor release key. Refusing to install."
  }
  Write-Host "Release manifest signature verified."
} else {
  Write-Host "Note: no OpenSSL 3 found - skipping the release manifest signature check (the download is still checked against its sha256)."
}

$manifest = Get-Content -Raw $manifestFile | ConvertFrom-Json
$entry = $manifest.files.'win-x64'
if (-not $entry -or -not $entry.url -or -not $entry.sha256) {
  throw "$manifestUrl has no win-x64 build. Refusing to install."
}

# Download to TEMP, not to the machine dir — the machine dir is exactly what a
# purge deletes, and the installed copy is made by setup's elevated child anyway.
$exe = Join-Path $env:TEMP "pms-relay-setup.exe"

Write-Host "Downloading the PMS relay..."
Invoke-WebRequest -UseBasicParsing -Uri $entry.url -OutFile $exe
$actual = (Get-FileHash -Algorithm SHA256 -Path $exe).Hash.ToLowerInvariant()
if ($actual -ne $entry.sha256.ToLowerInvariant()) {
  Remove-Item -Force $exe
  throw "The download does not match the release manifest (sha256 $actual, expected $($entry.sha256)). Refusing to install."
}
Write-Host "Download verified (sha256 $actual)."
if ($env:RELAY_INSTALL_DRY_RUN -eq "1") {
  Write-Host "RELAY_INSTALL_DRY_RUN=1: stopping before any change to this machine ($exe)."
  return
}

# Strip the Mark-of-the-Web so SmartScreen does not block a file the operator
# explicitly asked for by pasting this command.
Unblock-File -Path $exe

# A previous install? Clean it COMPLETELY before setting up — service, config,
# spool, old binary — so a reinstall never inherits a half-broken state.
$machineDir = Join-Path $env:ProgramData "pms-relay"
if (Test-Path $machineDir) {
  Write-Host "A previous install exists - removing it first (approve the admin prompt)."
  $p = Start-Process -FilePath $exe -ArgumentList "uninstall", "--purge" -Verb RunAs -Wait -PassThru
  if ($p.ExitCode -ne 0) {
    Write-Host "Could not remove the previous install (exit $($p.ExitCode)). Continuing anyway."
  }
}

Write-Host "Starting setup - your browser will open."
& $exe setup
