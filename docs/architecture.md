---
bkf: document
description: "Describes how Ambiente is built: modules and the boundary between the testable core and the app, the saved state and where it lives, how the external binaries are found, the download model and the build-environment pitfalls. Keeps the why and the boundaries, not what the code already says; product rules are in product.md."
tags: [architecture, technical]
---

# Ambiente — architecture

## Navigation map

| If you need... | See |
| --- | --- |
| To know where to change things for a new feature | [Where to put a feature](#where-to-put-a-feature) |
| What is testable and what is not | [Core vs app boundary](#core-vs-app-boundary) |
| What the app keeps between launches | [Saved state](#saved-state) |
| How `yt-dlp` and `ffmpeg` are found | [External binaries](#external-binaries) |
| How downloading works | [Downloading](#downloading) |
| Decisions that look odd | [Decisions and pitfalls](#decisions-and-pitfalls) |

## Core vs app boundary

A Swift package with two targets, plus tests:

- `Sources/AmbienteCore/` — logic with no AppKit and no processes: reading the
  library, playback order (shuffle/repeat), file operations (rename, publish
  downloads), the download queue, `yt-dlp` arguments and output parsing, binary
  choice, protection against unreadable tracks in a row. **All new testable
  logic goes here, with tests** (policy in [AGENTS.md](/AGENTS.md)).
- `Sources/Ambiente/` — the app: playback (`PlayerModel`), downloads and the
  updater (`DownloadModel`), binary lookup, the SwiftUI popover (`MenuView`) and
  the icon. It is thin glue over the core: what has no automated test is what
  needs the app running (AVPlayer, Now Playing, media keys, real processes,
  appearance), and it is verified by hand
  ([development](/docs/development.md#manual-verification)).
- `Tests/AmbienteCoreTests/` — tests the core only.

The two app models are `@MainActor @Observable`; the view only reads state and
calls methods, and has no playback or file logic (creating folders, renaming and
deleting go through `PlayerModel`).

## Where to put a feature

| Feature about... | Change |
| --- | --- |
| Ordering, queue, names, links, parsing, file operations | `AmbienteCore` + test |
| Playback, time, Now Playing, media keys, rename/delete wiring | `PlayerModel` |
| Downloading, the download list, updating `yt-dlp` | `DownloadModel` |
| Layout, buttons, popover pages | `MenuView` (see [ui.md](/docs/ui.md)) |
| Menu bar icon, app icon | `MenuIcon`, `Resources/MenuIcon/`, `scripts/make-icon.sh` |
| Packaging, binaries, signing | `scripts/` |

After a feature, update [product.md](/docs/product.md) (rules and criteria) and,
if structure or saved state changed, this document.

## Saved state

- **Preferences** in `UserDefaults` (the app's domain): last ambiente, volume,
  shuffle, repeat, track and position. The position is saved every ~5 s while
  playing, on pause, on seek and on quit. The keys live in `PlayerModel`.
- **Library**: the file system only, no database.
- **Application Support/Ambiente/**: the updated `yt-dlp` and the downloads'
  working folder.

## External binaries

An updated `yt-dlp` in Application Support only wins over the bundled one while
it is newer (file date); that way rebuilding the app with a newer `yt-dlp` is
never shadowed by an old update. `ffmpeg` is always the bundled one. Both come
from `scripts/fetch-binaries.sh` into `vendor/` (not versioned) and are copied
into the bundle by `scripts/build-app.sh`. `ffmpeg` must be **static**: the
Homebrew one depends on libraries outside the system and broke off this
machine. `yt-dlp` is the official standalone binary, not the Python script.

## Downloading

Each link is a job with its own scratch folder. `yt-dlp` writes there, and only
when it succeeds is the `.m4a` moved into the ambiente. This exists because an
interruption once left a truncated `.m4a` and leftover `.webm`/`.webp` files in
the library. The queue state (at most 3 at a time, cancel, duplicates) lives in
`DownloadQueue`; `DownloadModel` only launches and terminates the processes and
reports the result. A free name is chosen by the file move itself, so two
downloads with the same title cannot collide. Quitting the app terminates the
processes; at launch, interrupted scratch folders are deleted, except those that
still hold an `.m4a` whose save failed.

## Decisions and pitfalls

- **No sandbox and no chosen folder**: avoids security-scoped bookmarks, which
  would complicate the fixed folder in `~/Music`.
- **No full Xcode**: it builds with Swift Package Manager, and the `.app` is
  assembled and ad-hoc signed by a script. `LSUIElement` is in `Info.plist`.
- **Tests with the Command Line Tools' Swift Testing** need framework flags and
  the rule of not importing `Foundation` and `Testing` in the same file (details
  in [development](/docs/development.md#testing)).
- **Keyboard focus disabled** on controls (`focusable(false)`): with macOS
  keyboard navigation on, the first button always opened with an outline. Accepted
  consequence: the popover cannot be navigated with Tab alone.
- **The Now Playing image** is created off the main actor: MediaPlayer calls the
  handler on another queue, and a main-actor-isolated closure would fail at
  runtime.
