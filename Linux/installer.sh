#!/usr/bin/env bash
set -euo pipefail

UNINSTALL=false

# Parse arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -u|--uninstall|uninstall) UNINSTALL=true ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
    shift
done

# Check if git is installed
if ! command -v git &> /dev/null; then
    echo "Error: git is not installed." >&2
    exit 1
fi

# Determine installation directory under Linux (~/.local/share/git-share)
INSTALL_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/git-share"
TARGET="$INSTALL_DIR/git-share.sh"

if [ "$UNINSTALL" = true ]; then
    git config --global --unset alias.share || true
    rm -rf "$INSTALL_DIR"
    echo "git share uninstalled successfully."
    exit 0
fi

SOURCE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/git-share.sh"
if [ ! -f "$SOURCE" ]; then
    echo "Error: git-share.sh not found next to the installer ($SOURCE)." >&2
    exit 1
fi

# Copy the main script
mkdir -p "$INSTALL_DIR"
cp "$SOURCE" "$TARGET"
chmod +x "$TARGET"

# Configure global git alias
git config --global alias.share "!bash '$TARGET'"
if [ $? -ne 0 ]; then
    echo "Error: could not register the git alias." >&2
    exit 1
fi

echo "Installed in $INSTALL_DIR"
echo "Usage: run \`git share\` from any git repository."