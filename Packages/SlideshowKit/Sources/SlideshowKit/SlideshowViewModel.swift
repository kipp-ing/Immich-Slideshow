import Foundation
import ImmichClient
import Observation

@MainActor
@Observable
public final class SlideshowViewModel {
    public private(set) var phase: SlideshowPhase = .loading
    public private(set) var currentAssetID: String?
    public private(set) var currentImageData: Data?

    /// The album currently being shown. Mutable so Home-Assistant/remote control
    /// can switch albums at runtime (see `switchAlbum(_:)`).
    public private(set) var albumID: String
    private let api: any ImmichAPI
    private let ticker: any SlideshowTicker
    private let cache: ImageCache
    private let config: SlideshowConfig
    private var imageAssets: [Asset] = []
    private var currentIndex: Int?
    private var runTask: Task<Void, Never>?

    public init(
        api: any ImmichAPI,
        albumID: String,
        ticker: any SlideshowTicker,
        cache: ImageCache = ImageCache(limit: SlideshowConfig.default.cacheLimit),
        config: SlideshowConfig = .default
    ) {
        self.api = api
        self.albumID = albumID
        self.ticker = ticker
        self.cache = cache
        self.config = config
    }

    public func start() async {
        pause()
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
        guard phase == .playing, !imageAssets.isEmpty else {
            return
        }

        let baseIndex = currentIndex ?? -1
        let nextIndex = (baseIndex + 1) % imageAssets.count

        if let loaded = await loadFirstAvailableImage(startingAt: nextIndex) {
            showLoadedImage(loaded)
            prefetchImages(after: loaded.index)
        } else {
            phase = .failed
            pause()
        }
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
        guard phase == .playing else {
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
