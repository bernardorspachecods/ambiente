---
bkf: document
description: "Defines what Ambiente is and does: concept, playback behavior, the folder-based library, downloading from links, rename/delete rules, what is out of scope and the state of the acceptance criteria. Does not describe the code structure or the interface layout; architecture.md and ui.md own those."
tags: [product, requirements]
---

# Ambiente — product

A macOS menu bar app for listening to background music without the
distractions of YouTube. Personal use: no App Store, no sandbox, no
distribution.

## Navigation map

| If you need... | See |
| --- | --- |
| The concept and why it exists | [Concept](#concept) |
| How the library is read | [Library](#library) |
| Playback, shuffle, repeat and resume rules | [Playback](#playback) |
| Downloading music from links | [Downloading from links](#downloading-from-links) |
| Renaming and deleting | [Managing the library](#managing-the-library) |
| What is not built | [Out of scope](#out-of-scope) |
| Whether something is already done | [Acceptance criteria](#acceptance-criteria) |

## Concept

Listening to background music on YouTube leads to distractions and to hunting
for the same videos again. Ambiente plays local files only, chosen by
"ambiente" (classical, lowfi, instrumental…), with a dedicated menu bar icon.
There is no YouTube wrapper: YouTube is only a source to download audio from.

## Library

- The root is `~/Music/Ambiente/`, created at launch if missing. Every visible
  subfolder is an ambiente; every audio file inside it is a track. There is no
  configuration and no database: the folders are the truth.
- Subfolders inside an ambiente do not count (one level only).
- Recognized formats: m4a, mp3, aac, wav, aiff/aif, flac, caf. Opus does not
  play in AVPlayer, so downloads are always m4a.
- The list is re-read when the menu opens and after any change made by the app.
- The **displayed title is the file name**, not the metadata title, so that
  renaming is visible. The artist and the cover image come from the embedded
  metadata; without a cover a placeholder is shown.

## Playback

- Choosing an ambiente (the row's play button) plays its tracks; clicking a
  track plays that track and the rest follow the rules below.
- **Shuffle** (on by default): each round plays every track once, and a new
  round never starts with the track that just played. Off, it plays by name
  order. Turning it on or off does not interrupt the current track.
- **Repeat** (default `all`): `off` stops at the end of the round and goes back
  to the first track, paused; `all` loops forever; `one` repeats the track.
  Manual next and previous ignore repeat. Previous, after 3 seconds, restarts
  the track.
- Media keys and the macOS Now Playing widget control playback.
- **Resume:** on launch the app returns to the last ambiente, volume, track and
  position, **paused** (it does not start playing by itself). If the saved track
  no longer exists, only the ambiente is restored.
- An unreadable file (corrupt, or deleted behind the app's back) is skipped to
  the next track; if every track fails in a row, playback stops instead of
  sitting silent with the button on "play".
- Adding files to the active ambiente's folder does not interrupt the current
  track; the new tracks join the round.

## Downloading from links

- You paste one or several links (separated by line, space or comma), choose an
  ambiente — or create a new one by typing its name — and the app downloads the
  audio as m4a (best quality, embedded thumbnail and metadata).
- Single videos only: playlist links download just the video.
- Up to 3 downloads run in parallel; the rest wait. Each link has its own
  progress and state, and can be cancelled.
- A track only enters the ambiente when the download finishes successfully; an
  interruption never leaves partial files in the library. An existing track is
  never replaced: if the name is taken, the new one gets " (2)", " (3)"… If the
  ambiente disappears during the download, it is recreated. If saving fails,
  the downloaded file stays in the working folder and the error says where.
- `yt-dlp` and `ffmpeg` ship inside the app. `yt-dlp` can be updated without
  reinstalling: the app speaks up **only** when a newer version exists, and the
  update only replaces the one in use if the new one starts. The updated copy is
  used only while it is newer than the bundled one. `yt-dlp` runs without the
  user's personal configuration.
- Legal note: downloading from YouTube goes against the service's terms. Personal
  use, by the user's decision.

## Managing the library

- **Rename** tracks and ambientes inline in the list (context menu). For tracks
  the extension is kept; names that collide with an existing one are refused,
  and changing only upper/lower case is allowed. Renaming what is playing keeps
  playing from the same position, with a brief gap (the track is reloaded).
- **Delete** moves to the Trash (recoverable), with confirmation. Deleting an
  ambiente takes all its tracks. Deleting the playing track moves on to another;
  deleting the playing ambiente stops playback.

## Out of scope

Search, manual playlists, downloading YouTube playlists, lyrics, crossfade, a
global shortcut, keyboard-only navigation, autoplay on launch. Undated ideas are
in [ideas.md](/ideas.md).

## Acceptance criteria

Done and verified in the app, except where noted.

- [x] Lives only in the menu bar, no Dock icon.
- [x] Detects the subfolders of `~/Music/Ambiente/` as ambientes.
- [x] Choosing an ambiente plays it on shuffle and loop (configurable).
- [x] Play/pause, previous, next, volume and a timeline in the popover.
- [ ] Media keys control playback — implemented, never confirmed by hand.
- [x] On reopening it resumes ambiente, volume, track and position.
- [x] The interface uses native system components.
- [x] Pasting links downloads m4a into the right folder; the track appears without restarting.
- [x] `yt-dlp` and `ffmpeg` ship inside the app; `yt-dlp` updates without reinstalling.
- [ ] Parallel downloads, cancelling and updating `yt-dlp` from the interface — implemented, only tested through the command line and the build.
