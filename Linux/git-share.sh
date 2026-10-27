#!/usr/bin/env bash
set -euo pipefail

# Built-in patterns for files that must never be shared (case-insensitive regex)
DEFAULT_DENY='(^|/)\.env$|(^|/)\.env\..+|\.(pem|key|pfx|p12|dump)$|(^|/)id_(rsa|ed25519|ecdsa)$|(^|/)session\.json$|(^|/)secrets?\.(json|ya?ml|toml)$'

OUT_DIR=""
NAME=""
EXTRA_DENY=""

# Parse arguments (supports --out-dir, --name, --deny)
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --out-dir) OUT_DIR="$2"; shift ;;
        --name) NAME="$2"; shift ;;
        --deny) EXTRA_DENY="${EXTRA_DENY}|$2"; shift ;;
        *) echo "Unknown parameter: $1" >&2; exit 1 ;;
    esac
    shift
done

# Ensure we are inside a git repository and go to its root
ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || {
  echo "Error: not inside a git repository." >&2
  exit 1
}
cd "$ROOT"

if [ -z "$NAME" ]; then
    NAME=$(basename "$ROOT")
fi
if [ -z "$OUT_DIR" ]; then
    OUT_DIR="$ROOT"
fi

ZIP_PATH="$OUT_DIR/$NAME.zip"

# Temporary index: allows snapshotting untracked files without touching the real index
export GIT_INDEX_FILE="$(mktemp)"
trap 'rm -f "$GIT_INDEX_FILE"' EXIT
git read-tree --empty

# Stage everything in the temporary index, excluding a previous zip of the same name
git -c core.safecrlf=false add -A -- . ":(exclude,glob)**/$NAME.zip"
TREE=$(git write-tree)

# Build complete security pattern
PATTERN="$DEFAULT_DENY$EXTRA_DENY"

# Safety net: check for sensitive files
FILES=$(git -c core.quotepath=off ls-tree -r --name-only "$TREE")
LEAKS=$(echo "$FILES" | grep -E "$PATTERN" | grep -vE '\.env\.(example|sample|template)$' || true)

if [ -n "$LEAKS" ]; then
    echo "Refusing to archive sensitive-looking files:" >&2
    echo "$LEAKS" | sed 's/^/  /' >&2
    echo "Add them to .gitignore and run again." >&2
    exit 1
fi

# Create the zip archive
git archive --format=zip -o "$ZIP_PATH" "$TREE" > /dev/null

# Output statistics
FILE_COUNT=$(echo "$FILES" | wc -l)
FILE_SIZE_KB=$(du -k "$ZIP_PATH" | cut -f1)

echo "$ZIP_PATH: $FILE_COUNT files, ${FILE_SIZE_KB} KB"