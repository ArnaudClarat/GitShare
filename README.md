# git-share

Zip a git repo as it is right now, without committing anything.

`git share` packs everything git would track at this moment: committed files, uncommitted changes, and new untracked files. Whatever `.gitignore` excludes stays out. Handy when you want to send someone your work in progress and don't want to commit, stash, or copy the folder and delete `node_modules` by hand.

## How it works

The script builds the snapshot in a temporary index file (`GIT_INDEX_FILE`), so your real index is never touched. No commit, no stash. The temp index is deleted when the script ends, even if it fails.

Before writing the archive, it checks the file list for things that look like secrets and stops if it finds any.

## Requirements

- Windows
- Git for Windows
- PowerShell 5.1 or 7 (7 is used if available)

## Install

```powershell
powershell -ExecutionPolicy Bypass -File .\installer.ps1
```

This copies the script to `%LOCALAPPDATA%\git-share\` and sets a global git alias. No admin rights, nothing added to `PATH`, and your execution policy is left alone (the alias bypasses it for its own process only).

Running the installer again updates the installed copy.

To remove everything:

```powershell
powershell -ExecutionPolicy Bypass -File .\installer.ps1 -Uninstall
```

## Usage

From anywhere inside a repo:

```
git share
```

This writes `<repo folder name>.zip` at the repo root and prints the path, file count and size.

### Options

| Option | Description |
| --- | --- |
| `-OutDir` | Where to write the zip. Defaults to the repo root. |
| `-Name` | Zip name, without extension. Defaults to the repo folder name. |
| `-Deny` | Extra regexes for paths that must never be archived. Matched against repo-relative paths with `/` separators. |

```
git share -OutDir C:\Temp -Name review
git share -Deny '^config/', '\.sqlite$'
```

## Secret check

If the snapshot contains a file matching one of these patterns, nothing is archived and the script lists the offending files:

- `.env` and `.env.*` (but `.env.example`, `.env.sample` and `.env.template` are fine)
- `*.pem`, `*.key`, `*.pfx`, `*.p12`, `*.dump`
- `id_rsa`, `id_ed25519`, `id_ecdsa`
- `session.json`
- `secret.*` / `secrets.*` with a `json`, `yml`, `yaml` or `toml` extension

Fix it by adding the file to `.gitignore` and running the command again. Use `-Deny` to add your own patterns.

This is a safety net, not a guarantee. It only catches obvious filenames, so look at what you're sending.

## Notes

- A zip with the same name at the repo root is excluded, so the archive never contains itself.
- Untracked files are included unless they're ignored. If you don't want one in the zip, ignore it.