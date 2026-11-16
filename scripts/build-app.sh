#!/bin/sh
# Builds build/Ambiente.app (release, ad-hoc signed). Pass --install to copy it to ~/Applications.
set -eu
cd "$(dirname "$0")/.."

if [ ! -x vendor/yt-dlp ] || [ ! -x vendor/ffmpeg ]; then
  echo "Missing vendor/yt-dlp or vendor/ffmpeg: run scripts/fetch-binaries.sh first." >&2
  exit 1
fi

swift build -c release
BIN="$(swift build -c release --show-bin-path)/Ambiente"

APP=build/Ambiente.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Ambiente"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp vendor/yt-dlp vendor/ffmpeg "$APP/Contents/Resources/"
mkdir -p "$APP/Contents/Resources/MenuIcon"
cp Resources/MenuIcon/*.png "$APP/Contents/Resources/MenuIcon/"
codesign --force --sign - "$APP"
echo "Built $APP"

if [ "${1:-}" = "--install" ]; then
  mkdir -p ~/Applications
  rm -rf ~/Applications/Ambiente.app
  cp -R "$APP" ~/Applications/Ambiente.app
  echo "Installed ~/Applications/Ambiente.app"
fi
