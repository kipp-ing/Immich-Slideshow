import Foundation
import ImmichClient
import SlideshowKit
import Testing

@MainActor
@Test func startShowsFirstImageAssetAndFiltersVideos() async {
    let api = StubImmichAPI()
    let ticker = ManualTicker()
    api.setAssets([
        Asset(id: "video", type: "VIDEO"),
        Asset(id: "image-1", type: "IMAGE"),
        Asset(id: "image-2", type: "IMAGE")
    ], for: "album")
    api.setPreviewData(Data([1]), for: "image-1")
    api.setPreviewData(Data([2]), for: "image-2")

    let model = SlideshowViewModel(api: api, albumID: "album", ticker: ticker)
    await model.start()

    #expect(model.phase == .playing)
    #expect(model.currentAssetID == "image-1")
    #expect(model.currentImageData == Data([1]))
}

@MainActor
@Test func manualTickAdvancesExactlyOneImageAndWraps() async {
    let api = StubImmichAPI()
    let ticker = ManualTicker()
    api.setAssets([
        Asset(id: "image-1", type: "IMAGE"),
        Asset(id: "image-2", type: "IMAGE")
    ], for: "album")
    api.setPreviewData(Data([1]), for: "image-1")
    api.setPreviewData(Data([2]), for: "image-2")

    let model = SlideshowViewModel(api: api, albumID: "album", ticker: ticker)
    await model.start()

    await ticker.waitUntilWaiting()
    ticker.tick()
    await ticker.waitUntilConsumedTickCount(1)
    await waitUntil(model.currentAssetID == "image-2")
    #expect(model.currentAssetID == "image-2")
    #expect(model.currentImageData == Data([2]))

    await ticker.waitUntilWaiting()
    ticker.tick()
    await ticker.waitUntilConsumedTickCount(2)
    await waitUntil(model.currentAssetID == "image-1")
    #expect(model.currentAssetID == "image-1")
    #expect(model.currentImageData == Data([1]))
}

@MainActor
@Test func slideshowDoesNotAdvanceWithoutTickAndPauseStopsTickerUntilResume() async {
    let api = StubImmichAPI()
    let ticker = ManualTicker()
    api.setAssets([
        Asset(id: "image-1", type: "IMAGE"),
        Asset(id: "image-2", type: "IMAGE")
    ], for: "album")
    api.setPreviewData(Data([1]), for: "image-1")
    api.setPreviewData(Data([2]), for: "image-2")

    let model = SlideshowViewModel(api: api, albumID: "album", ticker: ticker)
    await model.start()
    await settleMainActor()
    #expect(model.currentAssetID == "image-1")

    await ticker.waitUntilWaiting()
    model.pause()
    ticker.tick()
    await settleMainActor()
    #expect(model.currentAssetID == "image-1")

    model.resume()
    await ticker.waitUntilWaiting()
    ticker.tick()
    await ticker.waitUntilConsumedTickCount(1)
    await waitUntil(model.currentAssetID == "image-2")
    #expect(model.currentAssetID == "image-2")
}

@MainActor
@Test func singleImageAlbumRemainsStableOnTick() async {
    let api = StubImmichAPI()
    let ticker = ManualTicker()
    api.setAssets([Asset(id: "image-1", type: "IMAGE")], for: "album")
    api.setPreviewData(Data([1]), for: "image-1")

    let model = SlideshowViewModel(api: api, albumID: "album", ticker: ticker)
    await model.start()

    await ticker.waitUntilWaiting()
    ticker.tick()
    await ticker.waitUntilConsumedTickCount(1)
    await settleMainActor()

    #expect(model.phase == .playing)
    #expect(model.currentAssetID == "image-1")
    #expect(model.currentImageData == Data([1]))
}

@MainActor
private func settleMainActor() async {
    await Task.yield()
    await Task.yield()
    await Task.yield()
}

@MainActor
private func waitUntil(_ condition: @autoclosure () -> Bool) async {
    for _ in 0..<100 where !condition() {
        await Task.yield()
    }
}

@MainActor
@Test func advanceCanBeCalledDirectlyAndWrapsInAlbumOrder() async {
    let api = StubImmichAPI()
    let ticker = ManualTicker()
    api.setAssets([
        Asset(id: "image-1", type: "IMAGE"),
        Asset(id: "image-2", type: "IMAGE"),
        Asset(id: "image-3", type: "IMAGE")
    ], for: "album")
    api.setPreviewData(Data([1]), for: "image-1")
    api.setPreviewData(Data([2]), for: "image-2")
    api.setPreviewData(Data([3]), for: "image-3")

    let model = SlideshowViewModel(api: api, albumID: "album", ticker: ticker)
    await model.start()

    await model.advance()
    #expect(model.currentAssetID == "image-2")

    await model.advance()
    #expect(model.currentAssetID == "image-3")

    await model.advance()
    #expect(model.currentAssetID == "image-1")
}
