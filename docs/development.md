---
bkf: document
description: "How to build, test, run and package Ambiente without full Xcode (Swift Package Manager plus an app-bundle script), where the code lives and how the bundled yt-dlp and ffmpeg are obtained. Does not define product behavior; the brief owns that."
tags: [development, build]
---

# Development

Full Xcode is not installed; everything uses the Command Line Tools and Swift
Package Manager.

## Layout

| Path | Holds |
| --- | --- |
| `Sources/AmbienteCore/` | Pure logic with tests: folder scanning, shuffle queue, yt-dlp arguments, progress and error parsing. |
| `Sources/Ambiente/` | The app: `PlayerModel` (AVPlayer, Now Playing, media keys), `DownloadModel` (yt-dlp process and updater), `Binaries`, SwiftUI `MenuView`. |
| `Tests/AmbienteCoreTests/` | Swift Testing tests for the core. |
| `Resources/Info.plist` | Bundle metadata, including `LSUIElement`. |
| `Resources/MenuIcon/` | Menu bar icon: a [blobatar](https://blobatar.dev) (MIT) for the name "Simpilco", `happy` face for playing and `sleepy` for paused (dimmed in code). The SVGs are the source; the PNGs are 72 px renders with the viewBox cropped to the blob. |
| `scripts/` | `fetch-binaries.sh` and `build-app.sh`. |

## Test

The Command Line Tools ship Swift Testing without its Foundation overlay, so
the framework path is passed explicitly, and a test file must not import both
`Foundation` and `Testing` (helpers using Foundation live in `Fixtures.swift`):

```sh
F=/Library/Developer/CommandLineTools/Library/Developer/Frameworks
swift test -Xswiftc -F -Xswiftc $F -Xlinker -F -Xlinker $F -Xlinker -rpath -Xlinker $F
```

## Build the app

```sh
scripts/fetch-binaries.sh   # once: standalone yt-dlp and static arm64 ffmpeg into vendor/
scripts/build-app.sh        # build/Ambiente.app, ad-hoc signed
scripts/build-app.sh --install   # also copies it to ~/Applications
```

`vendor/` and `build/` are not tracked. At runtime yt-dlp is looked up first in
`~/Library/Application Support/Ambiente/yt-dlp` (written by the in-app updater),
then in the bundle; ffmpeg is always the bundled one.
