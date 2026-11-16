#!/bin/sh
# Builds the app, replaces /Applications/Ambiente.app with it and opens it.
# Quits the running copies first (a plain SIGTERM is a normal quit for the app).
set -eu
cd "$(dirname "$0")/.."

DEST=/Applications/Ambiente.app

scripts/build-app.sh

# Quit any running copy (installed or local) so the new one is the only one.
pkill -f "Ambiente.app/Contents/MacOS/Ambiente" 2>/dev/null || true
sleep 1

rm -rf "$DEST"
cp -R build/Ambiente.app "$DEST"
# Older versions of this script installed into ~/Applications: avoid a second installed copy.
rm -rf "$HOME/Applications/Ambiente.app"

open "$DEST"
echo "Installed $DEST"
