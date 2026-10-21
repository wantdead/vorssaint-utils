// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// Spotify's scripting interface reports milliseconds despite its dictionary's
/// description. Its position is already current and needs no MediaRemote age.
struct NotchSpotifySample {
    let id: String
    let title: String
    let artist: String
    let album: String
    let duration: TimeInterval
    let elapsed: TimeInterval
    let isPlaying: Bool
    let sampledAt: Date
    let artworkURL: URL?
    var artworkData: Data?

    static func coverURL(_ value: String?) -> URL? {
        guard let value, let url = URL(string: value), url.scheme == "https",
              url.host == "i.scdn.co", url.user == nil, url.password == nil,
              url.port == nil || url.port == 443 else { return nil }
        return url
    }

    func applying(to playback: NotchPlayback, now: Date = Date()) -> NotchPlayback {
        guard playback.track.appBundleIdentifier == "com.spotify.client",
              now.timeIntervalSince(sampledAt) >= 0, now.timeIntervalSince(sampledAt) < 3 else { return playback }
        // While a video plays, Spotify's web player also publishes the song
        // as "Title • Artist" with no artist or album of its own.
        let webPlayer = (playback.track.artist ?? "").isEmpty && playback.track.title == "\(title) • \(artist)"
        let matches = webPlayer || (playback.track.title == title && playback.track.artist == artist
            && (playback.track.album == nil || playback.track.album == album))
        // MediaRemote can publish Chromium's page title, position and icon
        // during pause or navigation. Only the direct sample describes the song.
        let track = RadialNowPlayingSnapshot(title: title, artist: artist.isEmpty ? nil : artist,
            album: album.isEmpty ? nil : album,
            artworkData: artworkData,
            appBundleIdentifier: playback.track.appBundleIdentifier, appPID: playback.track.appPID)
        // A direct read can discover the next song before MediaRemote does, and
        // MediaRemote can stay on the old one for good. Play, pause, next and
        // previous keep the context. Native seeking requires a matching song;
        // scripting seeking validates Spotify's own recording ID before sending.
        return NotchPlayback(track: track, isPlaying: isPlaying, elapsed: elapsed,
            duration: duration, rate: isPlaying ? 1 : 0, sampledAt: sampledAt,
            canSeek: matches && playback.canSeek, hasPosition: true,
            itemIdentifier: matches ? playback.itemIdentifier : id,
            commandContext: playback.commandContext,
            canSendCommandsDirectly: playback.canSendCommandsDirectly,
            automationItemIdentifier: id,
            canSkipNext: playback.canSkipNext,
            canSkipPrevious: playback.canSkipPrevious)
    }
}

/// Spotify's recording identity survives Chromium page/session revisions.
struct NotchSpotifyPlaybackState {
    private var item: String?
    private var pid: Int32?
    private var context: NotchPlaybackContext?

    mutating func applying(_ sample: NotchSpotifySample, to playback: NotchPlayback, now: Date = Date()) -> NotchPlayback {
        var next = sample.applying(to: playback, now: now)
        guard next.automationItemIdentifier == sample.id, let nextPID = next.track.appPID else { return next }
        if item != sample.id || pid != nextPID || context == nil {
            item = sample.id
            pid = nextPID
            context = NotchPlaybackContext(pid: nextPID, revision: UUID())
        }
        next.commandContext = context
        next.itemIdentifier = sample.id
        next.canSendCommandsDirectly = false
        return next
    }
}
