<#
.SYNOPSIS
    Installs (or removes) the global `git share` command.

.DESCRIPTION
    1. Copies gitshare.ps1 to %LOCALAPPDATA%\gitshare\.
    2. Registers a global git alias, so `git share` works in every repository.

    The alias launches the script with -ExecutionPolicy Bypass for that single
    process only, so no change to your PowerShell execution policy is needed.
    Nothing is added to PATH and no admin rights are required.

    Re-running the installer simply updates the installed copy.

.PARAMETER Uninstall
    Removes the alias and the installed copy.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\installer.ps1

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\installer.ps1 -Uninstall
#>
[CmdletBinding()]
param(
    [switch]$Uninstall
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw 'git was not found in PATH. Install Git for Windows first.'
}

$installDir = Join-Path $env:LOCALAPPDATA 'git-share'
$target     = Join-Path $installDir 'git-share.ps1'

if ($Uninstall) {
    # Exit code 5 just means "alias not set"; that is fine when uninstalling.
    git config --global --unset alias.share
    Remove-Item $installDir -Recurse -Force -ErrorAction SilentlyContinue
    'git share uninstalled.'
    return
}

$source = Join-Path $PSScriptRoot 'gitshare.ps1'
if (-not (Test-Path $source)) {
    throw "git-share.ps1 not found next to the installer ($PSScriptRoot)."
}

New-Item -ItemType Directory -Force $installDir | Out-Null
Copy-Item $source $target -Force

# Prefer PowerShell 7 when present, fall back to Windows PowerShell 5.1.
$shell = if (Get-Command pwsh -ErrorAction SilentlyContinue) { 'pwsh' } else { 'powershell' }

# Git runs `!` aliases through its bundled sh: use forward slashes and single quotes
# so a path containing spaces (e.g. "C:/Users/First Last/...") survives intact.
$scriptPath = $target -replace '\\', '/'
git config --global alias.share "!$shell -NoProfile -ExecutionPolicy Bypass -File '$scriptPath'"
if ($LASTEXITCODE) { throw 'Could not register the git alias.' }

"Installed in $installDir (using $shell)."
'Usage: run `git share` from any git repository.'