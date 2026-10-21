// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import CoreServices

/// Reads only the selected Spotify process, using this app's existing consent.
/// Timer and results belong to the main thread; Apple Events use a serial queue.
final class NotchSpotifyMetadata {
    private(set) var sample: NotchSpotifySample?
    private var target: NotchMusicAutomation.Target?
    var isFollowingCurrentSource: Bool { target?.isCurrent == true }
    private var generation = UUID()
    private var timer: Timer?
    private var observer: NSObjectProtocol?
    private var inFlight = false
    private var refreshAgain = false
    private var changed: (() -> Void)?
    private let queue = DispatchQueue(label: "com.vorssaint.spotify-metadata", qos: .utility)
    private var coverTask: URLSessionDownloadTask?
    private var coverSession: URLSession?
    private var coverRetryAt = Date.distantPast
    private var coverURL: URL?
    private var coverRequest = UUID()
    private var readCancellation = DispatchWorkItem {}

    func follow(_ playback: NotchPlayback?, changed: @escaping () -> Void) {
        guard let playback, playback.track.appBundleIdentifier == "com.spotify.client",
              let next = NotchMusicAutomation.Target(playback) else { stop(); return }
        self.changed = changed
        guard next != target else { return }
        stop()
        self.changed = changed
        target = next
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.refresh() }
        observer = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("com.spotify.client.PlaybackStateChanged"), object: nil, queue: .main
        ) { [weak self] _ in self?.refresh() }
        refresh()
    }

    func stop() {
        generation = UUID()
        readCancellation.cancel()
        readCancellation = DispatchWorkItem {}
        coverRequest = UUID()
        timer?.invalidate(); timer = nil
        if let observer { DistributedNotificationCenter.default().removeObserver(observer) }
        observer = nil
        coverTask?.cancel(); coverTask = nil
        coverSession?.invalidateAndCancel(); coverSession = nil
        coverURL = nil; coverRetryAt = .distantPast
        target = nil; sample = nil; changed = nil; inFlight = false; refreshAgain = false
    }

    func refresh() {
        guard let target else { return }
        guard target.isCurrent else {
            let notify = changed
            stop()
            notify?()
            return
        }
        guard !inFlight else { refreshAgain = true; return }
        inFlight = true
        let requested = generation
        let cancellation = readCancellation
        let previous = sample
        queue.async { [weak self] in
            guard !cancellation.isCancelled else { return }
            let next = Self.read(target, previous: previous)
            DispatchQueue.main.async {
                guard let self, self.generation == requested, self.target == target else { return }
                self.inFlight = false
                var next = next
                if next == nil, let previous = self.sample, Date().timeIntervalSince(previous.sampledAt) < 3 {
                    next = previous
                }
                if next?.id != self.sample?.id {
                    self.coverTask?.cancel(); self.coverTask = nil
                    self.coverSession?.invalidateAndCancel(); self.coverSession = nil
                    self.coverRequest = UUID()
                    self.coverURL = nil
                }
                if next?.id == self.sample?.id, next?.artworkURL == self.sample?.artworkURL {
                    next?.artworkData = self.sample?.artworkData
                }
                self.sample = next
                self.changed?()
                self.loadCover()
                if self.refreshAgain {
                    self.refreshAgain = false
                    self.refresh()
                }
            }
        }
    }

    private func loadCover() {
        guard let sample, sample.artworkData == nil, let url = sample.artworkURL else { return }
        if coverURL == url, coverTask != nil || Date() < coverRetryAt { return }
        coverTask?.cancel()
        coverSession?.invalidateAndCancel()
        coverURL = url
        coverRetryAt = Date().addingTimeInterval(30)
        let requested = generation
        let request = UUID()
        coverRequest = request
        let id = sample.id
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = nil
        configuration.urlCredentialStorage = nil
        configuration.urlCache = nil
        configuration.timeoutIntervalForRequest = 5
        configuration.timeoutIntervalForResource = 10
        let session = URLSession(configuration: configuration, delegate: SpotifyCoverRedirectPolicy(), delegateQueue: nil)
        coverSession = session
        coverTask = session.downloadTask(with: url) { [weak self] file, response, _ in
            var data: Data?
            if let file, let response = response as? HTTPURLResponse, response.statusCode == 200,
               Self.validCoverResponse(response),
               let size = try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize,
               size > 0, size <= RadialNowPlayingSupport.maximumArtworkBytes {
                data = try? Data(contentsOf: file)
            }
            let cover = data
            DispatchQueue.main.async {
                guard let self, self.generation == requested, self.coverRequest == request, self.sample?.id == id,
                      self.sample?.artworkURL == url else { return }
                self.coverTask = nil
                self.coverSession?.finishTasksAndInvalidate(); self.coverSession = nil
                self.sample?.artworkData = cover
                self.changed?()
            }
        }
        coverTask?.resume()
    }

    private static func validCoverResponse(_ response: HTTPURLResponse) -> Bool {
        NotchSpotifySample.coverURL(response.url?.absoluteString) != nil
            && response.mimeType?.hasPrefix("image/") == true
    }

    /// Public to the local test executable; no scripting text or subprocesses.
    static func property(_ code: UInt32, container: NSAppleEventDescriptor = .null()) -> NSAppleEventDescriptor? {
        let record = NSAppleEventDescriptor.record()
        record.setDescriptor(NSAppleEventDescriptor(typeCode: typeProperty), forKeyword: AEKeyword(keyAEDesiredClass))
        record.setDescriptor(NSAppleEventDescriptor(enumCode: OSType(formPropertyID)), forKeyword: AEKeyword(keyAEKeyForm))
        record.setDescriptor(NSAppleEventDescriptor(typeCode: code), forKeyword: AEKeyword(keyAEKeyData))
        record.setDescriptor(container, forKeyword: AEKeyword(keyAEContainer))
        return record.coerce(toDescriptorType: typeObjectSpecifier)
    }

    static func get(_ code: UInt32, in container: NSAppleEventDescriptor = .null(),
                    target: NotchMusicAutomation.Target) -> NSAppleEventDescriptor? {
        guard target.isCurrent, let property = property(code, container: container) else { return nil }
        let event = NSAppleEventDescriptor(eventClass: kAECoreSuite, eventID: kAEGetData,
            targetDescriptor: NSAppleEventDescriptor(processIdentifier: target.pid),
            returnID: AEReturnID(kAutoGenerateReturnID), transactionID: AETransactionID(kAnyTransactionID))
        event.setParam(property, forKeyword: keyDirectObject)
        guard let reply = try? event.sendEvent(options: [.waitForReply, .neverInteract, .dontRecord], timeout: 0.4),
              (reply.paramDescriptor(forKeyword: keyErrorNumber)?.int32Value ?? 0) == 0 else { return nil }
        return reply.paramDescriptor(forKeyword: keyDirectObject)
    }

    static func read(_ target: NotchMusicAutomation.Target, previous: NotchSpotifySample? = nil) -> NotchSpotifySample? {
        guard target.bundleIdentifier == "com.spotify.client", target.isCurrent,
              NotchMusicAutomation.access(to: target) == .granted else { return nil }
        return readTrack(get: { get($0, in: $1, target: target) }, isCurrent: { target.isCurrent }, previous: previous)
    }

    static func readTrack(get: (UInt32, NSAppleEventDescriptor) -> NSAppleEventDescriptor?,
                          isCurrent: () -> Bool, previous: NotchSpotifySample? = nil) -> NotchSpotifySample? {
        guard let track = property(0x7054726B),
              let id = get(0x49442020, track)?.stringValue else { return nil } // pTrk / ID
        if let previous, previous.id == id {
            guard let elapsed = get(0x70506F73, .null())?.doubleValue,
                  elapsed.isFinite, elapsed >= 0 else { return nil }
            let sampledAt = Date()
            guard let state = get(0x70506C53, .null())?.enumCodeValue,
                  state == 0x6B505350 || state == 0x6B505370,
                  get(0x49442020, track)?.stringValue == id, isCurrent() else { return nil }
            return NotchSpotifySample(id: id, title: previous.title, artist: previous.artist, album: previous.album,
                duration: previous.duration, elapsed: min(elapsed, previous.duration),
                isPlaying: state == 0x6B505350, sampledAt: sampledAt,
                artworkURL: previous.artworkURL, artworkData: previous.artworkData)
        }
        // Spotify rejects pALL (all properties) for a track with -10000.
        // Read the declared properties, retaining the first ID to catch a skip.
        let properties = NSAppleEventDescriptor.record()
        properties.setDescriptor(NSAppleEventDescriptor(string: id), forKeyword: 0x49442020)
        for code: UInt32 in [0x706E616D, 0x70417274, 0x70416C62, 0x70447572] {
            guard let value = get(code, track) else { return nil }
            properties.setDescriptor(value, forKeyword: code)
        }
        if let cover = get(0x6155726C, track) { properties.setDescriptor(cover, forKeyword: 0x6155726C) }
        guard let elapsed = get(0x70506F73, .null())?.doubleValue else { return nil } // pPos
        let sampledAt = Date()
        guard let state = get(0x70506C53, .null())?.enumCodeValue, // pPlS
              get(0x49442020, track)?.stringValue == id,
              isCurrent() else { return nil }
        return decode(properties: properties, elapsed: elapsed, state: state, sampledAt: sampledAt)
    }

    static func decode(properties: NSAppleEventDescriptor, elapsed: Double, state: UInt32,
                       sampledAt: Date) -> NotchSpotifySample? {
        guard let id = properties.forKeyword(0x49442020)?.stringValue, !id.isEmpty,
              let title = properties.forKeyword(0x706E616D)?.stringValue, !title.isEmpty,
              let artist = properties.forKeyword(0x70417274)?.stringValue,
              let album = properties.forKeyword(0x70416C62)?.stringValue,
              let duration = properties.forKeyword(0x70447572)?.doubleValue,
              state == 0x6B505350 || state == 0x6B505370, // kPSP / kPSp
              elapsed.isFinite, elapsed >= 0, duration.isFinite,
              duration > 0, duration <= 604_800_000 else { return nil }
        return NotchSpotifySample(id: id, title: title, artist: artist, album: album,
            duration: duration / 1_000, elapsed: min(elapsed, duration / 1_000),
            isPlaying: state == 0x6B505350, sampledAt: sampledAt,
            artworkURL: NotchSpotifySample.coverURL(properties.forKeyword(0x6155726C)?.stringValue))
    }
}

private final class SpotifyCoverRedirectPolicy: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(NotchSpotifySample.coverURL(request.url?.absoluteString) == nil ? nil : request)
    }
}
