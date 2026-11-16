#!/bin/sh
# Downloads the standalone yt-dlp and a static arm64 ffmpeg into vendor/ (gitignored).
# build-app.sh copies them into the app bundle. Re-run with --force to refresh.
set -eu
cd "$(dirname "$0")/.."
mkdir -p vendor

if [ "${1:-}" = "--force" ]; then rm -f vendor/yt-dlp vendor/ffmpeg; fi

if [ ! -x vendor/yt-dlp ]; then
  echo "Downloading yt-dlp..."
  curl -fL --progress-bar -o vendor/yt-dlp \
    https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_macos
  chmod +x vendor/yt-dlp
fi

if [ ! -x vendor/ffmpeg ]; then
  echo "Downloading ffmpeg (static, arm64)..."
  curl -fL --progress-bar -o vendor/ffmpeg.gz \
    https://github.com/eugeneware/ffmpeg-static/releases/download/b6.0/ffmpeg-darwin-arm64.gz
  gunzip -f vendor/ffmpeg.gz
  chmod +x vendor/ffmpeg
fi

# ffmpeg must not depend on Homebrew libraries, or it breaks outside this Mac's setup.
if otool -L vendor/ffmpeg | tail -n +2 | grep -qE '/opt/homebrew|/usr/local'; then
  echo "ffmpeg links to non-system libraries; use a static build." >&2
  exit 1
fi
vendor/yt-dlp --version
vendor/ffmpeg -version | head -1
