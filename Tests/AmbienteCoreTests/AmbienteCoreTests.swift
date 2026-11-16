import Testing
@testable import AmbienteCore


@Suite struct PlayQueueTests {
    @Test func playsEveryTrackOncePerRound() {
        var queue = PlayQueue(tracks: urls(["a", "b", "c"]))
        var seen = [queue.current!]
        seen.append(queue.next()!)
        seen.append(queue.next()!)
        #expect(Set(seen).count == 3)
    }

    @Test func newRoundNeverRepeatsLastTrackFirst() {
        // A shuffler that always returns the same order would repeat the boundary track.
        var queue = PlayQueue(tracks: urls(["a", "b"]), shuffler: { $0 })
        #expect(queue.current == url("a"))
        queue.next()  // b
        let next = queue.next()  // new round
        #expect(next != url("b"))
    }

    @Test func loopsForever() {
        var queue = PlayQueue(tracks: urls(["a"]))
        for _ in 0..<5 {
            let next = queue.next()
            #expect(next == url("a"))
        }
    }

    @Test func emptyQueueYieldsNothing() {
        var queue = PlayQueue(tracks: [])
        let next = queue.next()
        let previous = queue.previous()
        #expect(queue.current == nil)
        #expect(next == nil)
        #expect(previous == nil)
    }

    @Test func previousStopsAtRoundStart() {
        var queue = PlayQueue(tracks: urls(["a", "b", "c"]), shuffler: { $0 })
        queue.next()
        let first = queue.previous()
        let again = queue.previous()
        #expect(first == url("a"))
        #expect(again == url("a"))
    }

    @Test func updateKeepsPlayingTrackAndAddsNew() {
        var queue = PlayQueue(tracks: urls(["a", "b"]), shuffler: { $0 })
        let kept = queue.update(tracks: urls(["a", "b", "c"]))
        #expect(kept)
        #expect(queue.current == url("a"))
        #expect(queue.count == 3)
    }

    @Test func updateReportsRemovedPlayingTrack() {
        var queue = PlayQueue(tracks: urls(["a", "b"]), shuffler: { $0 })
        let kept = queue.update(tracks: urls(["b"]))
        #expect(!kept)
    }
}

@Suite struct PlayQueueModeTests {
    @Test func unshuffledPlaysInFileOrder() {
        var queue = PlayQueue(tracks: urls(["a", "b", "c"]), shuffled: false)
        let b = queue.next()
        let c = queue.next()
        let a = queue.next()
        #expect(b == url("b"))
        #expect(c == url("c"))
        #expect(a == url("a"))
    }

    @Test func noWrapStopsAtEnd() {
        var queue = PlayQueue(tracks: urls(["a", "b"]), shuffled: false)
        queue.next()
        let end = queue.next(wrap: false)
        #expect(end == nil)
        #expect(queue.current == url("b"))
        queue.rewind()
        #expect(queue.current == url("a"))
    }

    @Test func togglingShuffleKeepsCurrentTrack() {
        var queue = PlayQueue(tracks: urls(["a", "b", "c"]), shuffled: false)
        queue.next()
        queue.setShuffled(true)
        #expect(queue.current == url("b"))
        queue.setShuffled(false)
        #expect(queue.current == url("b"))
        let c = queue.next()
        #expect(c == url("c"))
    }

    @Test func unshuffledUpdateKeepsFileOrder() {
        var queue = PlayQueue(tracks: urls(["a", "c"]), shuffled: false)
        queue.next()
        let kept = queue.update(tracks: urls(["a", "b", "c"]))
        #expect(kept)
        #expect(queue.current == url("c"))
    }
}

@Suite struct AudioLibraryTests {
    @Test func listsFoldersAndAudioOnly() throws {
        let root = try makeLibraryFixture()
        defer { removeFixture(root) }
        #expect(folderNames(root: root) == ["Clássico", "Lowfi"])
        #expect(trackNames(root: root, folder: "Lowfi") == ["one.m4a", "TWO.MP3"])
    }

    @Test func sanitizesFolderNames() {
        #expect(AudioLibrary.sanitizedFolderName("  Lowfi ") == "Lowfi")
        #expect(AudioLibrary.sanitizedFolderName("a/b:c") == "a-b-c")
        #expect(AudioLibrary.sanitizedFolderName("..hidden") == "hidden")
        #expect(AudioLibrary.sanitizedFolderName(" ../ ") == "-")
        #expect(AudioLibrary.sanitizedFolderName("   ") == nil)
        #expect(AudioLibrary.sanitizedFolderName("...") == nil)
    }

    @Test func missingRootIsEmpty() {
        #expect(folderNames(root: "/nonexistent/ambiente").isEmpty)
    }
}

@Suite struct YouTubeDownloadTests {
    @Test func validatesLinks() {
        #expect(YouTubeDownload.validatedURL(" https://www.youtube.com/watch?v=abc ") != nil)
        #expect(YouTubeDownload.validatedURL("youtube.com/watch?v=abc") == nil)
        #expect(YouTubeDownload.validatedURL("--exec rm") == nil)
        #expect(YouTubeDownload.validatedURL("file:///etc/passwd") == nil)
    }

    @Test func argumentsAreSingleVideoM4aAndEndOptions() {
        let args = sampleArguments()
        #expect(args.contains("--no-playlist"))
        #expect(args.contains("m4a"))
        #expect(args.suffix(2) == ["--", "https://youtu.be/x"])
        #expect(args.contains("/m/Lowfi/%(title)s.%(ext)s"))
        #expect(args.contains("/app/ffmpeg"))
    }

    @Test func parsesProgress() {
        #expect(YouTubeDownload.progress(fromLine: "[download]  42.5% of 3.21MiB at 1.00MiB/s ETA 00:02") == 0.425)
        #expect(YouTubeDownload.progress(fromLine: "[download] 100% of 3.21MiB") == 1)
        #expect(YouTubeDownload.progress(fromLine: "[info] Writing metadata") == nil)
    }

    @Test func extractsReadableError() {
        let out = "[youtube] x: Downloading\nERROR: [youtube] x: Video unavailable\n"
        #expect(YouTubeDownload.errorMessage(fromOutput: out) == "[youtube] x: Video unavailable")
        #expect(YouTubeDownload.errorMessage(fromOutput: "") == "The download failed.")
    }
}
