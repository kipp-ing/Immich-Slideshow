import Foundation
import ImmichClient
import Observation
import ThemeKit

@MainActor
@Observable
public final class SlideshowViewModel {
    public private(set) var phase: SlideshowPhase = .loading
    public private(set) var currentAssetID: String?
    public private(set) var currentImageData: Data?

    /// User-intent pause (the chrome play/pause button), distinct from the
    /// foreground/background gating done via `pause()`/`resume()`. While `true`
    /// the auto-advance ticker stays stopped even across background→foreground,
    /// but manual `showNext()`/`showPrevious()` still work.
    public private(set) var isPaused = false

    /// The album currently being shown. Mutable so Home-Assistant/remote control
    /// can switch albums at runtime (see `switchAlbum(_:)`).
    public private(set) var albumID: String
    private let api: any ImmichAPI
    private let ticker: any SlideshowTicker
    private let cache: ImageCache
    private let config: SlideshowConfig
    /// Live display/playback preferences (order, duration, quality). Read at the
    /// point of use so changes apply to the running show without a restart (008).
    private let settingsStore: any ThemeSettingsStore
    private var imageAssets: [Asset] = []
    private var currentIndex: Int?
    private var runTask: Task<Void, Never>?

    public init(
        api: any ImmichAPI,
        albumID: String,
        ticker: any SlideshowTicker,
        cache: ImageCache = ImageCache(limit: SlideshowConfig.default.cacheLimit),
        config: SlideshowConfig = .default,
        settingsStore: any ThemeSettingsStore
    ) {
        self.api = api
        self.albumID = albumID
        self.ticker = ticker
        self.cache = cache
        self.config = config
        self.settingsStore = settingsStore
    }

    public func start() async {
        pause()
        isPaused = false
        phase = .loading

        do {
            imageAssets = try await api.assets(albumID: albumID).filter { $0.type == "IMAGE" }
            guard !imageAssets.isEmpty else {
                currentIndex = nil
                currentAssetID = nil
                currentImageData = nil
                phase = .empty
                return
            }

            if let loaded = await loadFirstAvailableImage(startingAt: 0) {
                showLoadedImage(loaded)
                phase = .playing
                prefetchImages(after: loaded.index)
                startTickerLoop()
            } else {
                currentIndex = nil
                currentAssetID = nil
                currentImageData = nil
                phase = .failed
            }
        } catch {
            phase = .failed
        }
    }

    public func advance() async {
        await step(by: 1)
    }

    /// Manual forward step from the chrome/swipe. Unlike the ticker-driven
    /// `advance()`, it resets the auto-advance timer so the next automatic step
    /// is a full interval away; works while paused (without resuming the timer).
    public func showNext() async {
        pause()
        await step(by: 1)
        restartTickerIfPlaying()
    }

    /// Manual backward step from the chrome/swipe (the only place the show moves
    /// backwards). Resets the auto-advance timer like `showNext()`.
    public func showPrevious() async {
        pause()
        await step(by: -1)
        restartTickerIfPlaying()
    }

    /// Toggle the user-intent pause (chrome play/pause button). Pausing stops the
    /// auto-advance; resuming restarts it only while a real image is on screen.
    public func togglePause() {
        if isPaused {
            isPaused = false
            restartTickerIfPlaying()
        } else {
            isPaused = true
            pause()
        }
    }

    /// Jump straight to a specific asset in the current album (album-browser tap).
    /// No-op if the album doesn't contain it. Resets the auto-advance timer.
    public func jump(to assetID: String) async {
        guard let index = imageAssets.firstIndex(where: { $0.id == assetID }) else {
            return
        }

        pause()
        if let loaded = await loadFirstAvailableImage(startingAt: index) {
            showLoadedImage(loaded)
            phase = .playing
            prefetchImages(after: loaded.index)
            restartTickerIfPlaying()
        } else {
            phase = .failed
        }
    }

    /// Shared forward/backward step: loads the first available image starting at
    /// `currentIndex + delta` (wrapping), or fails the show if none load.
    private func step(by delta: Int) async {
        guard phase == .playing, !imageAssets.isEmpty else {
            return
        }

        let count = imageAssets.count
        let baseIndex = currentIndex ?? -1
        let targetIndex = ((baseIndex + delta) % count + count) % count

        if let loaded = await loadFirstAvailableImage(startingAt: targetIndex) {
            showLoadedImage(loaded)
            prefetchImages(after: loaded.index)
        } else {
            phase = .failed
            pause()
        }
    }

    private func restartTickerIfPlaying() {
        guard phase == .playing, !isPaused else {
            return
        }
        startTickerLoop()
    }

    public func retry() async {
        guard phase == .failed else {
            return
        }

        await start()
    }

    public func pause() {
        runTask?.cancel()
        runTask = nil
    }

    public func resume() {
        // Foreground gating only re-arms the timer; if the user paused via the
        // chrome, stay paused across background→foreground.
        guard phase == .playing, !isPaused else {
            return
        }

        startTickerLoop()
    }

    /// Switch to a different album and reload from its first image. Used by remote
    /// control (HA select); a no-op restart if the album is unchanged.
    public func switchAlbum(_ albumID: String) async {
        self.albumID = albumID
        await start()
    }

    private func startTickerLoop() {
        pause()
        let ticker = ticker
        runTask = Task.detached { [weak self, ticker] in
            guard let self else { return }

            while !Task.isCancelled {
                do {
                    try await ticker.waitForNextTick()
                    if Task.isCancelled {
                        break
                    }
                    await advance()
                } catch is CancellationError {
                    break
                } catch {
                    break
                }
            }
        }
    }

    private func loadImageData(for assetID: String) async throws -> Data {
        if let cached = cache.data(for: assetID) {
            return cached
        }

        let data = try await api.preview(assetID: assetID)
        cache.store(data, for: assetID)
        return data
    }

    private func loadFirstAvailableImage(startingAt startIndex: Int) async -> LoadedImage? {
        guard !imageAssets.isEmpty else {
            return nil
        }

        for offset in 0..<imageAssets.count {
            let index = (startIndex + offset) % imageAssets.count
            let asset = imageAssets[index]

            do {
                let data = try await loadImageData(for: asset.id)
                return LoadedImage(index: index, assetID: asset.id, data: data)
            } catch {
                continue
            }
        }

        return nil
    }

    private func showLoadedImage(_ loaded: LoadedImage) {
        currentIndex = loaded.index
        currentAssetID = loaded.assetID
        currentImageData = loaded.data
    }

    private func prefetchImages(after index: Int) {
        guard !imageAssets.isEmpty else {
            return
        }

        let depth = min(config.prefetchDepth, max(imageAssets.count - 1, 0))
        guard depth > 0 else {
            return
        }

        let assetIDs = (1...depth).map { offset in
            imageAssets[(index + offset) % imageAssets.count].id
        }
        let api = api
        let cache = cache

        Task {
            for assetID in assetIDs where cache.data(for: assetID) == nil {
                do {
                    let data = try await api.preview(assetID: assetID)
                    cache.store(data, for: assetID)
                } catch {
                    continue
                }
            }
        }
    }
}

private struct LoadedImage {
    let index: Int
    let assetID: String
    let data: Data
}
