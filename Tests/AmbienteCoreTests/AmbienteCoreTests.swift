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

@Suite struct PlayQueueSelectTests {
    @Test func selectStartsOnChosenTrackInBothModes() {
        var shuffled = PlayQueue(tracks: urls(["a", "b", "c"]), shuffled: true)
        let okShuffled = shuffled.select(url("c"))
        #expect(okShuffled)
        #expect(shuffled.current == url("c"))
        var ordered = PlayQueue(tracks: urls(["a", "b", "c"]), shuffled: false)
        let okOrdered = ordered.select(url("b"))
        #expect(okOrdered)
        let next = ordered.next()
        #expect(next == url("c"))
    }

    @Test func selectRejectsUnknownTrack() {
        var queue = PlayQueue(tracks: urls(["a"]), shuffled: false)
        let ok = queue.select(url("z"))
        #expect(!ok)
    }

    @Test func renameKeepsPositionAndOrder() {
        var queue = PlayQueue(tracks: urls(["a", "b", "c"]), shuffled: false)
        queue.next()
        queue.rename(from: url("b"), to: url("x"))
        #expect(queue.current == url("x"))
        let next = queue.next()
        #expect(next == url("c"))
    }
}

@Suite struct PlayQueueStabilityTests {
    @Test func updateWithSameTracksKeepsUpcomingOrder() {
        // A shuffler that reverses would visibly change the order if update reshuffled.
        var queue = PlayQueue(tracks: urls(["a", "b", "c", "d"]), shuffled: true, shuffler: { $0.reversed() })
        let before = [queue.current, queue.next(), queue.next(), queue.next()]
        queue.rewind()
        let kept = queue.update(tracks: urls(["a", "b", "c", "d"]))
        let after = [queue.current, queue.next(), queue.next(), queue.next()]
        #expect(kept)
        #expect(before == after)
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
        #expect(args.first == "--ignore-config")
        #expect(args.contains("--no-playlist"))
        #expect(args.contains("m4a"))
        #expect(args.suffix(2) == ["--", "https://youtu.be/x"])
        #expect(args.contains("/m/Lowfi/%(title)s.%(ext)s"))
        #expect(args.contains("/app/ffmpeg"))
    }

    @Test func extractsLinksFromPastedText() {
        let text = "https://youtu.be/a\nhttps://youtu.be/b, junk https://youtu.be/a\n  https://youtu.be/c  "
        let links = YouTubeDownload.links(from: text).map(\.absoluteString)
        #expect(links == ["https://youtu.be/a", "https://youtu.be/b", "https://youtu.be/c"])
        #expect(YouTubeDownload.links(from: "nothing here").isEmpty)
    }

    @Test func readsTitleFromDestinationLine() {
        #expect(YouTubeDownload.title(fromLine: "[download] Destination: /tmp/x/Me at the zoo.webm") == "Me at the zoo")
        #expect(YouTubeDownload.title(fromLine: "[download]  42.5% of 3MiB") == nil)
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

@Suite struct LibraryFilesTests {
    @Test func renamesTrackKeepingExtension() throws {
        let root = try makeTempRoot()
        defer { removeFixture(root) }
        try touch(root, ["Sad/old.m4a"])
        #expect(renameTrack(root, "Sad/old.m4a", to: "  New name ") == "New name.m4a")
        #expect(listing(root, "Sad") == ["New name.m4a"])
        // Typing the extension does not double it.
        #expect(renameTrack(root, "Sad/New name.m4a", to: "Other.M4A") == "Other.m4a")
    }

    @Test func refusesToReplaceAnExistingTrack() throws {
        let root = try makeTempRoot()
        defer { removeFixture(root) }
        try touch(root, ["Sad/a.m4a", "Sad/b.m4a"])
        #expect(renameTrack(root, "Sad/a.m4a", to: "b").hasPrefix("error:"))
        #expect(contents(root, "Sad/b.m4a") == "Sad/b.m4a")
        #expect(listing(root, "Sad") == ["a.m4a", "b.m4a"])
    }

    @Test func rejectsInvalidNames() throws {
        let root = try makeTempRoot()
        defer { removeFixture(root) }
        try touch(root, ["Sad/a.m4a"])
        #expect(renameTrack(root, "Sad/a.m4a", to: "   ").hasPrefix("error:"))
        #expect(renameTrack(root, "Sad/a.m4a", to: "...").hasPrefix("error:"))
        #expect(renameTrack(root, "Sad/a.m4a", to: "../x") == "-x.m4a")
        #expect(listing(root, "Sad") == ["-x.m4a"])
    }

    @Test func caseOnlyTrackRenameWorksAndLeavesNoTempFile() throws {
        let root = try makeTempRoot()
        defer { removeFixture(root) }
        try touch(root, ["Sad/Song.m4a"])
        #expect(renameTrack(root, "Sad/Song.m4a", to: "song") == "song.m4a")
        #expect(listing(root, "Sad") == ["song.m4a"])
    }

    @Test func renamesFolderAndRefusesCollision() throws {
        let root = try makeTempRoot()
        defer { removeFixture(root) }
        try touch(root, ["Lowfi/a.m4a", "Sad/b.m4a"])
        #expect(renameFolder(root, "Lowfi", to: "Chill") == "Chill")
        #expect(listing(root) == ["Chill", "Sad"])
        #expect(renameFolder(root, "Chill", to: "Sad").hasPrefix("error:"))
        #expect(listing(root, "Sad") == ["b.m4a"])
    }

    @Test func caseOnlyFolderRenameLeavesNoHiddenFolder() throws {
        let root = try makeTempRoot()
        defer { removeFixture(root) }
        try touch(root, ["lowfi/a.m4a"])
        #expect(renameFolder(root, "lowfi", to: "Lowfi") == "Lowfi")
        #expect(listing(root) == ["Lowfi"])
        #expect(listing(root, "Lowfi") == ["a.m4a"])
    }

    @Test func publishMovesM4aOnlyAndNeverReplaces() throws {
        let root = try makeTempRoot()
        defer { removeFixture(root) }
        try touch(root, ["Sad/Song.m4a", "scratch/Song.m4a", "scratch/Song.webm", "scratch/Song.webp"])
        #expect(publish(root, scratch: "scratch", to: "Sad") == ["Song (2).m4a"])
        #expect(listing(root, "Sad") == ["Song (2).m4a", "Song.m4a"])
        #expect(contents(root, "Sad/Song.m4a") == "Sad/Song.m4a")
        #expect(contents(root, "Sad/Song (2).m4a") == "scratch/Song.m4a")
    }

    @Test func publishSkipsEveryTakenNumber() throws {
        let root = try makeTempRoot()
        defer { removeFixture(root) }
        try touch(root, ["Sad/S.m4a", "Sad/S (2).m4a", "scratch/S.m4a"])
        #expect(publish(root, scratch: "scratch", to: "Sad") == ["S (3).m4a"])
    }

    @Test func publishRecreatesAFolderThatVanishedMidDownload() throws {
        let root = try makeTempRoot()
        defer { removeFixture(root) }
        try touch(root, ["scratch/S.m4a"])
        #expect(publish(root, scratch: "scratch", to: "Gone") == ["S.m4a"])
        #expect(listing(root, "Gone") == ["S.m4a"])
    }

    @Test func publishWithoutAudioFails() throws {
        let root = try makeTempRoot()
        defer { removeFixture(root) }
        try touch(root, ["scratch/S.webm"])
        #expect(publish(root, scratch: "scratch", to: "Sad").first?.hasPrefix("error:") == true)
        #expect(listing(root).contains("Sad") == false)
    }
}

@Suite struct DownloadQueueTests {
    @Test func runsAtMostMaxConcurrentAndStartsTheRestAsSlotsFree() {
        var queue = DownloadQueue(maxConcurrent: 2)
        queue.enqueue(urls(["a", "b", "c", "d"]), into: url("F"))
        let first = queue.startable()
        #expect(first.count == 2)
        #expect(queue.startable().isEmpty)
        queue.finish(first[0].id, outcome: .success)
        let next = queue.startable()
        #expect(next.count == 1)
        #expect(next[0].url == url("c"))
    }

    @Test func skipsDuplicateActiveLinksButAllowsAfterFinishOrOtherFolder() {
        var queue = DownloadQueue()
        queue.enqueue(urls(["a"]), into: url("F"))
        queue.enqueue(urls(["a"]), into: url("F"))
        #expect(queue.jobs.count == 1)
        queue.enqueue(urls(["a"]), into: url("G"))
        #expect(queue.jobs.count == 2)
        let started = queue.startable()
        queue.finish(started[0].id, outcome: .success)
        queue.enqueue(urls(["a"]), into: url("F"))
        #expect(queue.jobs.count == 3)
    }

    @Test func cancellingAQueuedJobRemovesItImmediately() {
        var queue = DownloadQueue(maxConcurrent: 1)
        queue.enqueue(urls(["a", "b"]), into: url("F"))
        _ = queue.startable()
        let waiting = queue.jobs[1].id
        let action = queue.remove(waiting)
        #expect(action == .removed)
        #expect(queue.jobs.count == 1)
    }

    @Test func cancellingARunningJobAsksToTerminateThenDropsItOnFailure() {
        var queue = DownloadQueue()
        queue.enqueue(urls(["a"]), into: url("F"))
        let id = queue.startable()[0].id
        let action = queue.remove(id)
        #expect(action == .terminateProcess)
        #expect(queue.jobs.count == 1)
        queue.finish(id, outcome: .failure("killed"))
        #expect(queue.jobs.isEmpty)
    }

    @Test func aJobThatSucceededJustAfterCancelIsKept() {
        var queue = DownloadQueue()
        queue.enqueue(urls(["a"]), into: url("F"))
        let id = queue.startable()[0].id
        _ = queue.remove(id)
        queue.finish(id, outcome: .success)
        #expect(queue.jobs.count == 1)
        #expect(queue.jobs[0].status == .done)
    }

    @Test func failuresStayUntilDismissedAndDoneJobsClear() {
        var queue = DownloadQueue()
        queue.enqueue(urls(["a", "b"]), into: url("F"))
        let started = queue.startable()
        queue.finish(started[0].id, outcome: .failure("boom"))
        queue.finish(started[1].id, outcome: .success)
        queue.clearDone()
        #expect(queue.jobs.count == 1)
        #expect(queue.jobs[0].status == .failed("boom"))
        let action = queue.remove(started[0].id)
        #expect(action == .removed)
        #expect(!queue.isDownloading)
    }

    @Test func progressAndTitleUpdateOnlyRunningJobs() {
        var queue = DownloadQueue(maxConcurrent: 1)
        queue.enqueue(urls(["a", "b"]), into: url("F"))
        let running = queue.startable()[0].id
        queue.update(running, title: "Song", progress: 0.5)
        queue.update(running, title: "Other", progress: nil)
        #expect(queue.jobs[0].title == "Song")
        #expect(queue.jobs[0].status == .downloading(progress: 0.5))
        queue.update(queue.jobs[1].id, title: nil, progress: 0.9)
        #expect(queue.jobs[1].status == .queued)
    }

    @Test func jobsCanStartAlreadyFailed() {
        var queue = DownloadQueue()
        queue.enqueue(urls(["a"]), into: url("F"), failWith: "no yt-dlp")
        #expect(queue.startable().isEmpty)
        #expect(queue.jobs[0].status == .failed("no yt-dlp"))
    }
}

@Suite struct SupportTests {
    @Test func splitsOnNewlineAndCarriageReturn() {
        #expect(splitLines([Array("a\r\nb\rc\nd".utf8)]) == ["a", "", "b", "c", "d"])
    }

    @Test func keepsAMultiByteCharacterSplitAcrossReads() {
        let bytes = Array("[download] Destination: Café.webm\n".utf8)
        let cut = bytes.firstIndex(of: 0xC3)! + 1  // between the two bytes of "é"
        let lines = splitLines([Array(bytes[..<cut]), Array(bytes[cut...])])
        #expect(lines == ["[download] Destination: Café.webm"])
    }

    @Test func emitsTheLastLineWithoutBreak() {
        #expect(splitLines([Array("ERROR: x".utf8)]) == ["ERROR: x"])
    }

    @Test func updatedYtDlpWinsOnlyWhileNewer() {
        #expect(choiceName(updated: 200, bundled: 100) == "updated")
        #expect(choiceName(updated: 100, bundled: 200) == "bundled")
        #expect(choiceName(updated: 100, bundled: nil) == "updated")
        #expect(choiceName(updated: nil, bundled: 100) == "bundled")
        #expect(choiceName(updated: nil, bundled: nil) == "none")
    }

    @Test func stopsSkippingWhenEveryTrackFailedInARow() {
        var guardRail = PlaybackFailureGuard()
        let first = guardRail.shouldSkip(afterFailureIn: 3)
        let second = guardRail.shouldSkip(afterFailureIn: 3)
        let third = guardRail.shouldSkip(afterFailureIn: 3)
        #expect(first)
        #expect(second)
        #expect(!third)
        guardRail.recordSuccess()
        let again = guardRail.shouldSkip(afterFailureIn: 3)
        #expect(again)
    }

    @Test func singleTrackFolderNeverSkips() {
        var guardRail = PlaybackFailureGuard()
        let skip = guardRail.shouldSkip(afterFailureIn: 1)
        #expect(!skip)
    }
}
