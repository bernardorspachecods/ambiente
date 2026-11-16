# Ambiente

A tiny macOS menu bar app for background music. Each subfolder of
`~/Music/Ambiente` is an *ambiente* (lowfi, classical, sad…): pick one and it
plays its tracks on shuffle. No window, no Dock icon, nothing to get distracted by.

I made it because listening to background music on YouTube always ended with
me watching other videos. This plays local files only, and can fetch new tracks
from a link without leaving the app.

> Personal project, built for my own Mac. It works for me; it is not polished
> for distribution (not notarized, Apple Silicon only, no releases).

## Features

- **Folders are the library.** Create a folder, drop music in it, done. No
  settings, no database.
- Play/pause, previous/next, a seekable timeline, volume, **shuffle** and
  **repeat** (off / all / one). Pick a specific track from any ambiente.
- Media keys and the macOS Now Playing widget, with the cover art embedded in the file.
- Resumes where you left off: ambiente, track, position and volume.
- **Add by link:** paste one or several YouTube links, pick (or create) an
  ambiente, and the audio is downloaded as m4a with cover and metadata. Up to
  three at a time, with progress and cancel.
- Rename and move to Trash from the right-click menu; the `yt-dlp` updater only
  speaks up when there is a newer version.
- Native SwiftUI only, with automatic dark mode.

## Requirements

- macOS 14 or later, Apple Silicon.
- Swift toolchain (the Xcode Command Line Tools are enough; full Xcode is not needed).

## Build and run

```sh
scripts/fetch-binaries.sh   # once: downloads yt-dlp and a static ffmpeg into vendor/
scripts/build-app.sh        # builds build/Ambiente.app (ad-hoc signed)
open build/Ambiente.app
```

`scripts/build-app.sh --install` also copies the app to `~/Applications`
(recommended if you want *Open at login*). The binaries are downloaded at build
time and are not part of this repository.

Run the tests (the flags work around the Testing framework layout of the Command Line Tools):

```sh
F=/Library/Developer/CommandLineTools/Library/Developer/Frameworks
swift test -Xswiftc -F -Xswiftc $F -Xlinker -F -Xlinker $F -Xlinker -rpath -Xlinker $F
```

## Notes on downloading

Downloading audio from YouTube goes against YouTube's Terms of Service. The
feature exists for personal use, with content you are allowed to keep, and using
it is your responsibility. This project is not affiliated with YouTube or Google.

## How it is organized

Documentation lives in [`docs/`](docs/) and is organized with
[BKF](MAP.md): start at [`MAP.md`](MAP.md). The short version: what the app
does is in [`docs/produto.md`](docs/produto.md), where to change things is in
[`docs/arquitetura.md`](docs/arquitetura.md). The docs are written in
Portuguese; the app's interface is in English.

## Credits

- [yt-dlp](https://github.com/yt-dlp/yt-dlp) does the downloading, with
  [FFmpeg](https://ffmpeg.org) for audio extraction. Both are downloaded by
  `scripts/fetch-binaries.sh` (the ffmpeg build is a third-party static build;
  check its license before redistributing anything).
- The menu bar icon and app icon are generated with
  [blobatar](https://blobatar.dev) (MIT).

## License

[MIT](LICENSE). This covers the code in this repository, not yt-dlp, FFmpeg or the
blobatar artwork, which keep their own licenses.
