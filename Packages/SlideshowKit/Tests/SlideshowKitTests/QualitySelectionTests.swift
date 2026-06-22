import Foundation
import ImmichClient
import SlideshowKit
import Testing
import ThemeKit
import ThemeKitTestSupport

@MainActor
@Test func originalQualityLoadsOriginalBytesWithoutPreviewFetch() async {
    let api = StubImmichAPI()
    let ticker = ManualTicker()
    api.setAssets([Asset(id: "a", type: "IMAGE")], for: "album")
    api.setPreviewData(Data([1]), for: "a")
    api.setOriginalData(Data([2]), for: "a")

    let model = SlideshowViewModel(
        api: api,
        albumID: "album",
        ticker: ticker,
        settingsStore: themeStore(quality: .original)
    )
    await model.start()

    #expect(model.currentAssetID == "a")
    #expect(model.currentImageData == Data([2]))
    #expect(api.originalCallCount(for: "a") == 1)
    #expect(api.previewCallCount(for: "a") == 0)
}

@MainActor
@Test func previewQualityLoadsPreviewBytesWithoutOriginalFetch() async {
    let api = StubImmichAPI()
    let ticker = ManualTicker()
    api.setAssets([Asset(id: "a", type: "IMAGE")], for: "album")
    api.setPreviewData(Data([1]), for: "a")
    api.setOriginalData(Data([2]), for: "a")

    let model = SlideshowViewModel(
        api: api,
        albumID: "album",
        ticker: ticker,
        settingsStore: themeStore(quality: .preview)
    )
    await model.start()

    #expect(model.currentAssetID == "a")
    #expect(model.currentImageData == Data([1]))
    #expect(api.previewCallCount(for: "a") == 1)
    #expect(api.originalCallCount(for: "a") == 0)
}

@MainActor
@Test func previewCacheEntryDoesNotSatisfyOriginalQualityRequest() async {
    let api = StubImmichAPI()
    let ticker = ManualTicker()
    let cache = ImageCache(limit: 3)
    api.setAssets([Asset(id: "a", type: "IMAGE")], for: "album")
    api.setPreviewData(Data([1]), for: "a")
    api.setOriginalData(Data([2]), for: "a")

    let previewModel = SlideshowViewModel(
        api: api,
        albumID: "album",
        ticker: ticker,
        cache: cache,
        settingsStore: themeStore(quality: .preview)
    )
    await previewModel.start()

    let originalModel = SlideshowViewModel(
        api: api,
        albumID: "album",
        ticker: ticker,
        cache: cache,
        settingsStore: themeStore(quality: .original)
    )
    await originalModel.start()

    #expect(originalModel.currentAssetID == "a")
    #expect(originalModel.currentImageData == Data([2]))
    #expect(api.previewCallCount(for: "a") == 1)
    #expect(api.originalCallCount(for: "a") == 1)
}

@MainActor
private func themeStore(quality: ImageQuality) -> InMemoryThemeStore {
    InMemoryThemeStore(settings: ThemeSettings(order: .sequential, quality: quality))
}
