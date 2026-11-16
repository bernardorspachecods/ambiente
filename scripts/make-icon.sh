#!/bin/sh
# Regenerates Resources/AppIcon.icns from Resources/MenuIcon/playing.svg.
set -eu
cd "$(dirname "$0")/.."
TMP="$(mktemp -d)"
swift scripts/make-icon.swift Resources/MenuIcon/playing.svg "$TMP/AppIcon.iconset"
iconutil -c icns "$TMP/AppIcon.iconset" -o Resources/AppIcon.icns
rm -rf "$TMP"
echo "Wrote Resources/AppIcon.icns"
