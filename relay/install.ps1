# Copied verbatim from the v0.6.0-r16 release assets; the next relay release overwrites this file.
# PMS relay — Windows one-line installer.
# Usage (from the PMS's Integrations page):
#   powershell -NoProfile -ExecutionPolicy Bypass -Command "irm https://github.com/Hotel-Assistant/relay-releases/releases/latest/download/install.ps1 | iex"
# Removes any PREVIOUS install first (service + machine directory), then downloads
# the current build and starts the browser setup page. The setup page handles
# pairing and the elevated service install (UAC prompt).
$ErrorActionPreference = "Stop"

# Download to TEMP, not to the machine dir — the machine dir is exactly what a
# purge deletes, and the installed copy is made by setup's elevated child anyway.
$exe = Join-Path $env:TEMP "pms-relay-setup.exe"

Write-Host "Downloading the PMS relay..."
Invoke-WebRequest -UseBasicParsing `
  -Uri "https://github.com/Hotel-Assistant/relay-releases/releases/latest/download/relay-win-x64.exe" `
  -OutFile $exe
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
