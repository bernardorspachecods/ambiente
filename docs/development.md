---
bkf: document
description: "How to build, test, run and install Ambiente without full Xcode, how to get the binaries and what to check by hand after a change. Does not define product behavior or the code structure."
tags: [development, build]
---

# Ambiente — development

No full Xcode: everything uses the Command Line Tools and Swift Package Manager.

## Navigation map

| If you need... | See |
| --- | --- |
| To build and install the app | [Building](#building) |
| To run the tests | [Testing](#testing) |
| To confirm a change in the app | [Manual verification](#manual-verification) |

## Building

```sh
scripts/fetch-binaries.sh        # once: yt-dlp and a static ffmpeg into vendor/
scripts/build-app.sh   # build/Ambiente.app (the local build), ad-hoc signed
open build/Ambiente.app
scripts/install.sh     # build, quit the running copies, replace /Applications/Ambiente.app, open it
```

`vendor/` and `build/` are not versioned. The app icon (`Resources/AppIcon.icns`)
is generated from the blob with `scripts/make-icon.sh`. `scripts/build-app.sh` alone
does not restart anything: quit the app and open it again to see a change.
`scripts/install.sh` does it all for the installed copy. The local build shows a
**DEV** marker next to the menu bar icon, so when both copies are open you know
which one is which (they share the same settings and both listen to the media
keys, so close one). "Open at login" is only reliable with the installed copy:
registered from `build/`, the path may stop existing.

## Testing

The Command Line Tools ship Swift Testing without the Foundation overlay, so the
framework flags are passed explicitly, and a test file **must not import both
`Foundation` and `Testing`** (the code that needs Foundation lives in
`Fixtures.swift`):

```sh
F=/Library/Developer/CommandLineTools/Library/Developer/Frameworks
swift test -Xswiftc -F -Xswiftc $F -Xlinker -F -Xlinker $F -Xlinker -rpath -Xlinker $F
```

Only the core has automated tests; what stays out is what needs the app running
(see [architecture](/docs/architecture.md#core-vs-app-boundary)). A fixed defect
first gets a test that reproduces it. Inside `#expect`, do not call `mutating`
methods directly: store the result in a variable first.

## Manual verification

The app has no automated UI tests, so after a change, depending on what it touched:

- Playback: choose an ambiente, play a specific track, seek on the timeline,
  shuffle/repeat, media keys.
- Resume: play, quit, reopen (it must return to the track and position, paused).
- Downloading: one link; several at once; cancel; a new ambiente; quit the app
  midway (nothing may be left in the ambiente's folder).
- Rename/delete the playing track and the playing ambiente.
- Open the menu: no focus outline on any button.
- `bkf validate .` and `bkf inventory . --check` if you touched documents.

For a test download without the app, use the bundle's binaries with the same
arguments the core generates.
