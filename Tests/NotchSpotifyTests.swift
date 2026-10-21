// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import CoreServices

enum NotchSpotifyTests {
    static func run(_ suite: TestSuite) {
        let now = Date(timeIntervalSince1970: 1_000)
        let revision = NotchPlaybackContext(pid: 42, revision: UUID())
        func playback(_ title: String = "Song", bundle: String = "com.spotify.client",
                      at: Date? = nil) -> NotchPlayback {
            NotchPlayback(track: .init(title: title, artist: "Artist", album: "Album", artworkData: nil,
                appBundleIdentifier: bundle, appPID: 42), isPlaying: true, elapsed: 205, duration: 239,
                rate: 1, sampledAt: at ?? now.addingTimeInterval(-1), canSeek: true,
                itemIdentifier: "native-item", commandContext: revision, canSendCommandsDirectly: true,
                canSkipNext: true, canSkipPrevious: true)
        }
        let properties = NSAppleEventDescriptor.record()
        for (key, text): (UInt32, String) in [
            (0x49442020, "spotify:track:one"), (0x706E616D, "Song"), (0x70417274, "Artist"),
            (0x70416C62, "Album"), (0x6155726C, "https://i.scdn.co/image/cover")
        ] { properties.setDescriptor(NSAppleEventDescriptor(string: text), forKeyword: key) }
        properties.setDescriptor(NSAppleEventDescriptor(int32: 239_000), forKeyword: 0x70447572)
        var requests: [UInt32] = []
        var nested = true
        func read(_ code: UInt32, _ container: NSAppleEventDescriptor) -> NSAppleEventDescriptor? {
            requests.append(code)
            if code == 0x70506F73 { return NSAppleEventDescriptor(double: 236) }
            if code == 0x70506C53 { return NSAppleEventDescriptor(enumCode: 0x6B505350) }
            nested = nested && container.forKeyword(AEKeyword(keyAEKeyData))?.typeCodeValue == 0x7054726B
            return properties.forKeyword(code)
        }
        let direct = NotchSpotifyMetadata.readTrack(get: read, isCurrent: { true })
        suite.expect(direct?.elapsed == 236 && direct?.duration == 239 && nested
            && !requests.contains(0x70414C4C) && requests.filter { $0 == 0x49442020 }.count == 2,
            "the real reader requests supported track properties individually and checks the ID around position and state")
        var ids = 0
        let skipped = NotchSpotifyMetadata.readTrack(get: { code, container in
            if code == 0x49442020 {
                ids += 1
                if ids == 2 { return NSAppleEventDescriptor(string: "spotify:track:next") }
            }
            return read(code, container)
        }, isCurrent: { true })
        suite.expect(skipped == nil && NotchSpotifyMetadata.readTrack(get: read, isCurrent: { false }) == nil,
            "a skip or process replacement during an Apple Event read discards the mixed snapshot")
        guard var sample = NotchSpotifyMetadata.decode(properties: properties, elapsed: 236,
            state: 0x6B505350, sampledAt: now) else {
            suite.expect(false, "Spotify's native scripting record decodes"); return
        }
        sample.artworkData = Data([1, 2, 3])
        requests = []
        let cached = NotchSpotifyMetadata.readTrack(get: read, isCurrent: { true }, previous: sample)
        suite.expect(cached?.elapsed == 236 && cached?.artworkData == sample.artworkData
            && requests == [0x49442020, 0x70506F73, 0x70506C53, 0x49442020],
            "steady playback polls only identity, position and state instead of rereading all track metadata")
        ids = 0
        let changedDuringPoll = NotchSpotifyMetadata.readTrack(get: { code, container in
            if code == 0x49442020 {
                ids += 1
                if ids == 2 { return NSAppleEventDescriptor(string: "spotify:track:next") }
            }
            return read(code, container)
        }, isCurrent: { true }, previous: sample)
        suite.expect(changedDuringPoll == nil, "the lightweight poll also rejects a track changing during its read")
        let merged = sample.applying(to: playback(), now: now)
        suite.expect(merged.elapsed == 236 && merged.duration == 239 && merged.position(at: now.addingTimeInterval(1)) == 237,
            "Spotify's current position replaces the stale MediaRemote position and its duration uses milliseconds")
        suite.expect(merged.track.artworkData == sample.artworkData && merged.commandContext == revision
            && merged.itemIdentifier == "native-item" && merged.canSendCommandsDirectly,
            "the downloaded cover fills missing artwork without losing the matching player's command context")
        let different = sample.applying(to: playback("Old song"), now: now)
        suite.expect(different.track.title == "Song" && different.commandContext == revision
            && different.canSendCommandsDirectly && different.canSkipNext == true && different.canSkipPrevious == true,
            "a song MediaRemote has not caught up to keeps play, pause, next and previous")
        suite.expect(!different.canSeek && different.itemIdentifier == "spotify:track:one",
            "a song MediaRemote has not caught up to cannot be sought with the previous recording's position")
        func web(_ title: String, artist: String? = nil, at: Date? = nil, artwork: Data? = nil) -> NotchPlayback {
            NotchPlayback(track: .init(title: title, artist: artist, album: nil, artworkData: artwork,
                appBundleIdentifier: "com.spotify.client", appPID: 42), isPlaying: true, elapsed: 205, duration: 239,
                rate: 1, sampledAt: at ?? now.addingTimeInterval(-1), canSeek: true,
                itemIdentifier: "native-item", commandContext: revision, canSendCommandsDirectly: true,
                canSkipNext: true, canSkipPrevious: true)
        }
        let video = sample.applying(to: web("Song • Artist"), now: now)
        suite.expect(video.track.title == "Song" && video.track.artist == "Artist" && video.canSeek
            && video.commandContext == revision && video.itemIdentifier == "native-item",
            "the web player's 'Title • Artist' reading of a video counts as the same song, with its controls and seek")
        suite.expect(!sample.applying(to: web("Spotify - Web Player: Music for everyone"), now: now).canSeek
            && !sample.applying(to: web("Other • Artist"), now: now).canSeek,
            "a web-player title for another song keeps seek off")
        var bare = sample
        bare.artworkData = nil
        suite.expect(bare.applying(to: web("Song • Artist", artwork: Data([9])), now: now).track.artworkData == nil,
            "the web player's picture of its own icon is never shown as the cover")
        let silent = NotchSpotifySample(id: "spotify:episode:x", title: "Song", artist: "", album: "", duration: 239,
            elapsed: 3, isPlaying: true, sampledAt: now, artworkURL: nil, artworkData: nil)
        let quiet = silent.applying(to: playback(), now: now)
        suite.expect(quiet.track.artist == nil && quiet.track.album == nil,
            "an empty artist or album from Spotify reads as missing, not as a blank line")
        let later0 = now.addingTimeInterval(0.5)
        let between = sample.applying(to: web("Spotify - Web Player: Music for everyone", at: later0), now: later0)
        suite.expect(between.track.title == "Song" && between.track.artist == "Artist" && !between.canSeek,
            "the web player's page title between songs never replaces Spotify's own reading")
        let other = playback(bundle: "local.video")
        suite.expect(sample.applying(to: other, now: now) == other,
            "Spotify cannot replace another selected player's metadata")
        let later = playback("New song", at: now.addingTimeInterval(0.5))
        suite.expect(sample.applying(to: later, now: now.addingTimeInterval(0.5)).track.title == "Song",
            "a fresh direct Spotify sample remains authoritative while Chromium publishes different page metadata")
        suite.expect(sample.applying(to: playback(), now: now.addingTimeInterval(3)) == playback()
            && sample.applying(to: playback(), now: now.addingTimeInterval(-1)) == playback(),
            "expired samples and a backwards wall clock fall back to native playback")
        let paused = NotchSpotifyMetadata.decode(properties: properties, elapsed: 50, state: 0x6B505370, sampledAt: now)
        let page = NotchPlayback(track: .init(title: "Spotify – Liked Songs", artist: "Spotify", album: nil,
            artworkData: Data([9]), appBundleIdentifier: "com.spotify.client", appPID: 42),
            isPlaying: false, elapsed: 0, duration: 236, rate: 0,
            sampledAt: now.addingTimeInterval(0.5), canSeek: true,
            commandContext: .init(pid: 42, revision: UUID()), canSendCommandsDirectly: true)
        let pausePage = paused?.applying(to: page, now: now.addingTimeInterval(0.5))
        suite.expect(pausePage?.track.title == "Song" && pausePage?.elapsed == 50 && pausePage?.duration == 239,
            "a pause publishing Spotify's Chromium page title and zero position cannot replace its direct track sample")
        let nativeIcon = NotchPlayback(track: .init(title: "Song", artist: "Artist", album: "Album",
            artworkData: Data([9]), appBundleIdentifier: "com.spotify.client", appPID: 42),
            isPlaying: true, elapsed: 0, duration: 239, rate: 1, sampledAt: now.addingTimeInterval(-1), canSeek: true)
        suite.expect(bare.applying(to: nativeIcon, now: now).track.artworkData == nil,
            "Chromium artwork cannot substitute for Spotify's track cover even when the titles match")
        let newerPause = NotchPlayback(track: playback().track, isPlaying: false, elapsed: 51, duration: 239,
            rate: 0, sampledAt: now.addingTimeInterval(0.5), canSeek: true,
            itemIdentifier: "native-item", commandContext: revision, canSendCommandsDirectly: true)
        let stillPaused = sample.applying(to: newerPause, now: now.addingTimeInterval(0.5))
        suite.expect(stillPaused.isPlaying && stillPaused.elapsed == sample.elapsed && stillPaused.sampledAt == sample.sampledAt,
            "native timing updates cannot overwrite the direct Spotify clock or state")
        suite.expect(stillPaused.automationItemIdentifier == sample.id,
            "a newer native timing sample retains Spotify's recording identity for responsive scripting controls")
        let service = NotchMusicCommandContract.Service()
        service.receiveAdapter(.init(playback: playback(), artwork: nil, tint: nil,
            sources: [], automatic: true, selectedPID: nil))
        service.spotify.sample = NotchSpotifySample(id: sample.id, title: sample.title,
            artist: sample.artist, album: sample.album, duration: sample.duration, elapsed: sample.elapsed,
            isPlaying: true, sampledAt: Date(), artworkURL: nil)
        service.receiveSpotify()
        for _ in 0..<4 {
            service.receiveAdapter(.init(playback: nil, artwork: nil, tint: nil,
                sources: [], automatic: true, selectedPID: nil))
            // Drain the production gap deadline: this must survive beyond grace.
            NotchMusicCommandContract.DispatchQueue.main.drain()
        }
        suite.expect(service.playback?.track.title == "Song" && service.spotify.followed != nil,
            "rapid native gaps must not stop Spotify polling or show Nothing playing")
        let recovered = NotchSpotifySample(id: "spotify:track:recovered", title: "Recovered",
            artist: "Artist", album: "Album", duration: 239, elapsed: 2,
            isPlaying: true, sampledAt: Date(), artworkURL: nil)
        service.spotify.sample = recovered
        service.receiveSpotify()
        suite.expect(service.playback?.track.title == "Recovered"
            && service.playback?.automationItemIdentifier == recovered.id,
            "direct polling discovers the next recording without native session recovery")
        let recoveredContext = service.playback?.commandContext
        service.receiveAdapter(.init(playback: playback("Old native song"), artwork: nil, tint: nil,
            sources: [], automatic: true, selectedPID: nil))
        suite.expect(service.playback?.track.title == "Recovered"
            && service.playback?.commandContext == recoveredContext,
            "native recovery cannot replace the direct track or reset its command context")
        service.spotify.alive = false
        service.receiveSpotify()
        service.receiveSpotify()
        NotchMusicCommandContract.DispatchQueue.main.drain()
        suite.expect(service.playback == nil && service.spotify.followed == nil,
            "process exit clears playback and repeated callbacks cannot resurrect stale native metadata")
        service.spotify.alive = true
        service.receiveAdapter(.init(playback: playback(), artwork: nil, tint: nil,
            sources: [], automatic: true, selectedPID: nil))
        service.spotify.sample = recovered
        service.receiveAdapter(.init(playback: nil, artwork: nil, tint: nil,
            sources: [], automatic: false, selectedPID: 99))
        NotchMusicCommandContract.DispatchQueue.main.drain()
        suite.expect(service.playback == nil && service.spotify.followed == nil,
            "a different explicit source clears Spotify even during a native gap")
        service.receiveAdapter(.init(playback: playback(), artwork: nil, tint: nil,
            sources: [], automatic: true, selectedPID: nil))
        service.spotify.sample = recovered
        service.receiveAdapter(.init(playback: other, artwork: nil, tint: nil,
            sources: [], automatic: true, selectedPID: nil))
        service.spotify.sample = recovered
        service.receiveSpotify()
        suite.expect(service.playback?.track.appBundleIdentifier == "local.video",
            "a late Spotify callback cannot replace another automatic player")
        service.start()
        let browser = NotchPlaybackSource(pid: 99, bundleIdentifier: "local.video",
            isMusicApp: false, isPlaying: true, hasTrack: true)
        service.receiveAdapter(.init(playback: playback(), artwork: nil, tint: nil,
            sources: [browser], automatic: true, selectedPID: nil))
        service.spotify.sample = recovered
        service.selectSource(browser.selection)
        service.spotify.sample = recovered
        service.receiveSpotify()
        suite.expect(service.playback == nil && service.spotify.followed == nil && service.adapterReading == nil,
            "an explicit source request invalidates direct callbacks before the adapter replies")
        var state = NotchSpotifyPlaybackState()
        let song = state.applying(sample, to: playback(), now: now)
        let pagePlayback = state.applying(paused!, to: page, now: now.addingTimeInterval(0.5))
        suite.expect(song.commandContext == pagePlayback.commandContext && song.itemIdentifier == sample.id
            && !song.canSendCommandsDirectly && !pagePlayback.canSendCommandsDirectly,
            "a Chromium page revision cannot cancel Spotify controls or retarget seeking to the native session")
        suite.expect(pagePlayback.track.title == "Song" && !pagePlayback.isPlaying && pagePlayback.elapsed == 50,
            "the authoritative session pauses without replacing the title or resetting the timeline")
        let nextSample = NotchSpotifySample(id: "spotify:track:next", title: "Song", artist: "Artist", album: "Album",
            duration: 239, elapsed: 0, isPlaying: true, sampledAt: now, artworkURL: nil)
        let nextSong = state.applying(nextSample, to: page, now: now)
        suite.expect(nextSong.commandContext != song.commandContext && nextSong.automationItemIdentifier == nextSample.id,
            "Spotify's next recording changes the control context even if Chromium and visible titles stay the same")
        suite.expect(paused?.applying(to: playback(), now: now).position(at: now.addingTimeInterval(2)) == 50,
            "a paused Spotify sample holds its position")
        suite.expect(NotchSpotifyMetadata.decode(properties: properties, elapsed: .nan, state: 0x6B505350, sampledAt: now) == nil
            && NotchSpotifyMetadata.decode(properties: properties, elapsed: -1, state: 0x6B505350, sampledAt: now) == nil
            && NotchSpotifyMetadata.decode(properties: properties, elapsed: 1, state: 0x6B505353, sampledAt: now) == nil,
            "invalid positions and stopped playback do not override the native reader")
        suite.expect(NotchSpotifySample.coverURL("http://i.scdn.co/image/cover") == nil
            && NotchSpotifySample.coverURL("https://i.scdn.co.example.org/image/cover") == nil
            && NotchSpotifySample.coverURL("https://user:pass@i.scdn.co/image/cover") == nil,
            "cover downloads accept only Spotify's HTTPS image host without credentials")
        let currentTrack = NotchSpotifyMetadata.property(0x7054726B)
        let cover = currentTrack.flatMap { NotchSpotifyMetadata.property(0x6155726C, container: $0) }
        suite.expect(cover?.descriptorType == typeObjectSpecifier
            && cover?.forKeyword(AEKeyword(keyAEContainer))?.forKeyword(AEKeyword(keyAEKeyData))?.typeCodeValue == 0x7054726B,
            "Spotify reads encode a nested current-track property instead of application-global artwork")
    }
}
