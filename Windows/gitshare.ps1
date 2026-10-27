<#
.SYNOPSIS
    Zips the CURRENT working state of a git repository, minus anything ignored.

.DESCRIPTION
    Creates "<repo folder name>.zip" containing every file git would track right
    now: committed files, uncommitted modifications AND new untracked files.
    Anything matched by .gitignore is left out.

    Nothing in the repository is modified: no commit, no stash, and the real
    index is never touched. The snapshot is built in a throw-away index file
    (GIT_INDEX_FILE) that is deleted at the end, even if the script fails.

    A safety net refuses to build the archive if it would contain files that
    look like secrets (.env, private keys, database dumps, session files...).

    Works in any git repository. Installed globally as `git share` by installer.ps1.

.PARAMETER OutDir
    Folder where the zip is written. Defaults to the repository root.

.PARAMETER Name
    Name of the zip, without extension. Defaults to the repository folder name.

.PARAMETER Deny
    Extra regular expressions (matched against repo-relative paths, using "/")
    that must never end up in the archive. Added to the built-in list.

.EXAMPLE
    git share
    Creates <repo>.zip at the repository root.

.EXAMPLE
    git share -Deny '^config/', '\.sqlite$'
    Same, and also refuses anything under config/ or ending in .sqlite.

.EXAMPLE
    git share -OutDir C:\Temp -Name review
    Creates C:\Temp\review.zip.
#>
[CmdletBinding()]
param(
    [string]$OutDir,
    [string]$Name,
    [string[]]$Deny = @()
)

$ErrorActionPreference = 'Stop'

# Built-in patterns for files that must never be shared (case-insensitive regex).
$DefaultDeny = @(
    '(^|/)\.env(\.(?!example$|sample$|template$)[^/]+)?$',  # .env, .env.local ... but not .env.example
    '\.(pem|key|pfx|p12|dump)$',                            # keys, certificates, DB dumps
    '(^|/)id_(rsa|ed25519|ecdsa)$',                         # SSH private keys
    '(^|/)session\.json$',                                  # captured auth sessions
    '(^|/)secrets?\.(json|ya?ml|toml)$'                     # generic secrets files
)

# Runs git and fails loudly on a non-zero exit code (works on Windows PowerShell 5.1 too).
function Invoke-Git {
    $output = & git @args
    if ($LASTEXITCODE) { throw "git $($args -join ' ') failed (exit code $LASTEXITCODE)" }
    $output
}

# Always work from the repository root, wherever the command was launched.
$root = Invoke-Git rev-parse --show-toplevel
Set-Location $root

if (-not $Name)   { $Name   = Split-Path -Leaf $root }
if (-not $OutDir) { $OutDir = $root }
$zipPath = Join-Path (Resolve-Path $OutDir).Path "$Name.zip"

# Throw-away index: lets us snapshot untracked files without touching the real index.
$env:GIT_INDEX_FILE = Join-Path ([IO.Path]::GetTempPath()) "git-share-$PID.idx"

try {
    # Stage everything in the temporary index, except a previous zip of the same name, so the archive can never contain itself.
    Invoke-Git -c core.safecrlf=false add -A -- . ":(exclude,glob)**/$Name.zip"
    $tree = Invoke-Git write-tree

    # Safety net: abort if the snapshot contains anything that looks like a secret.
    $pattern = ($DefaultDeny + $Deny) -join '|'
    $files   = @(Invoke-Git -c core.quotepath=off ls-tree -r --name-only $tree)
    $leaks   = @($files | Where-Object { $_ -match $pattern })
    if ($leaks) {
        throw "Refusing to archive sensitive-looking files:`n  $($leaks -join "`n  ")`nAdd them to .gitignore and run again."
    }
    Invoke-Git archive --format=zip -o $zipPath $tree | Out-Null

}
finally {
    # Clean up the temporary index and the environment variable, whatever happened.
    Remove-Item $env:GIT_INDEX_FILE -ErrorAction SilentlyContinue
    Remove-Item Env:GIT_INDEX_FILE -ErrorAction SilentlyContinue
}

'{0}: {1} files, {2:N0} KB' -f $zipPath, $files.Count, ((Get-Item $zipPath).Length / 1KB)