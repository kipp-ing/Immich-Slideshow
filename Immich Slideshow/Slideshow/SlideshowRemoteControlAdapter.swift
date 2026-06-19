//
//  SlideshowRemoteControlAdapter.swift
//  Immich Slideshow
//

import HAControlKit
import SlideshowKit

@MainActor
public final class SlideshowRemoteControlAdapter: RemoteControlling {
    private let slideshow: SlideshowViewModel

    public private(set) var playbackState: PlaybackState = .playing
    public var brightness: Double { 0 }
    public var albumOptions: [String] { [] }
    public var currentAlbum: String? { nil }
    public var onLocalChange: (@MainActor () -> Void)?

    public init(slideshow: SlideshowViewModel) {
        self.slideshow = slideshow
    }

    public func pause() {
        slideshow.pause()
        playbackState = .paused
        onLocalChange?()
    }

    public func resume() {
        slideshow.resume()
        playbackState = .playing
        onLocalChange?()
    }

    public func setBrightness(_ value: Double) async {}

    public func selectAlbum(_ name: String) {}
}
