//
//  Immich_SlideshowApp.swift
//  Immich Slideshow
//
//  Created by Jan Kipping on 17.06.26.
//

import Foundation
import ImmichClient
import OnboardingKit
import PowerKit
import SlideshowKit
import SwiftUI

@main
struct Immich_SlideshowApp: App {
    @State private var viewModel: OnboardingViewModel
    // Built lazily at the `.done` route: reads the saved config + Keychain key and
    // constructs an authenticated slideshow. Returns nil only if state is somehow
    // incomplete (the StartupGate normally prevents reaching `.done` without it).
    private let makeSlideshow: () -> SlideshowViewModel?
    // Keeps the display awake during the slideshow and can control brightness.
    // Backed by the live screen in production, a fake under `--uitest` so the
    // hermetic test never touches real device brightness.
    private let makePowerManager: () -> PowerManager

    init() {
        #if DEBUG
        // Hermetic seam for XCUITests: when launched with `--uitest`, drive both the
        // onboarding flow and the slideshow against in-memory stubs — no network, no
        // real keychain — so the UI walkthrough is deterministic and CI-safe. The
        // production path below is untouched.
        if UITestSupport.isActive {
            _viewModel = State(initialValue: UITestSupport.makeViewModel())
            makeSlideshow = { UITestSupport.makeSlideshowViewModel() }
            makePowerManager = { UITestSupport.makePowerManager() }
            return
        }
        #endif

        let config = UserDefaultsConfigStore()
        let keychain = KeychainAPIKeyStore()
        let viewModel = OnboardingViewModel(
            api: { serverConfig in ImmichClient(config: serverConfig) },
            config: config,
            keychain: keychain
        )

        // Resume at the first missing step on launch; only a complete state
        // (config + key) routes straight to the slideshow (FR-001/FR-011).
        viewModel.step = StartupGate(config: config, keychain: keychain).initialStep()

        _viewModel = State(initialValue: viewModel)

        // The API key stays in the Keychain and is only handed to the client here;
        // it is never logged or persisted elsewhere (Konstitution III).
        makeSlideshow = {
            guard let appConfig = config.load(), let apiKey = keychain.read() else { return nil }
            let client = ImmichClient(
                config: ServerConfig(baseURL: appConfig.baseURL, apiKey: apiKey)
            )
            return SlideshowViewModel(
                api: client,
                albumID: appConfig.selectedAlbumID,
                ticker: RealTicker(interval: SlideshowConfig.default.interval)
            )
        }

        // Production: drive the real device screen. The PowerManager gates all
        // effects to the foreground itself (Konstitution V).
        makePowerManager = { PowerManager(screen: UIScreenController()) }
    }

    var body: some Scene {
        WindowGroup {
            RootView(
                onboarding: viewModel,
                makeSlideshow: makeSlideshow,
                makePowerManager: makePowerManager
            )
        }
    }
}

/// Routes between onboarding and the running slideshow. Holds the slideshow view
/// model for the lifetime of the `.done` state so its timer/prefetch survive
/// re-renders; reset tears it down and returns to onboarding (002/US3).
private struct RootView: View {
    let onboarding: OnboardingViewModel
    let makeSlideshow: () -> SlideshowViewModel?
    let makePowerManager: () -> PowerManager

    @State private var slideshow: SlideshowViewModel?
    @State private var powerManager: PowerManager?

    var body: some View {
        if onboarding.step == .done {
            if let slideshow, let powerManager {
                SlideshowView(viewModel: slideshow, powerManager: powerManager, onReset: {
                    self.slideshow = nil
                    self.powerManager = nil
                    onboarding.reset()
                })
            } else {
                Color.black
                    .ignoresSafeArea()
                    .task {
                        slideshow = makeSlideshow()
                        powerManager = makePowerManager()
                    }
            }
        } else {
            OnboardingFlowView(viewModel: onboarding)
        }
    }
}

#if DEBUG
// MARK: - UI test seam (DEBUG only)
//
// Activated solely by the `--uitest` launch argument that the XCUITest target
// passes. Keeps the app fully offline: a stubbed ImmichAPI plus in-memory
// config/keychain. Never compiled into Release; never touches the network or
// the real Keychain.

enum UITestSupport {
    static var isActive: Bool {
        ProcessInfo.processInfo.arguments.contains("--uitest")
    }

    static func makeViewModel() -> OnboardingViewModel {
        OnboardingViewModel(
            api: { _ in StubImmichAPI() },
            config: InMemoryConfigStore(),
            keychain: InMemoryKeychainStore()
        )
    }

    static func makeSlideshowViewModel() -> SlideshowViewModel {
        SlideshowViewModel(
            api: StubImmichAPI(),
            albumID: "a1",
            ticker: RealTicker(interval: .seconds(2))
        )
    }

    @MainActor
    static func makePowerManager() -> PowerManager {
        // In-memory screen so the hermetic UI test never dims/locks the real device.
        PowerManager(screen: StubScreenController())
    }
}

@MainActor
private final class StubScreenController: ScreenControlling {
    var brightness: Double = 0.5
    var isIdleTimerDisabled = false
}

private struct StubImmichAPI: ImmichAPI {
    // A valid 1x1 PNG so the slideshow actually decodes and renders an image.
    private static let pngData = Data(
        base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="
    ) ?? Data()

    func serverVersion() async throws -> String { "1.0.0" }

    func albums() async throws -> [Album] {
        [Album(id: "a1", name: "Wohnzimmer"), Album(id: "a2", name: "Urlaub 2026")]
    }

    func assets(albumID: String) async throws -> [Asset] {
        [
            Asset(id: "asset-1", type: "IMAGE"),
            Asset(id: "asset-2", type: "IMAGE"),
            Asset(id: "asset-3", type: "IMAGE"),
        ]
    }

    func preview(assetID: String) async throws -> Data { Self.pngData }
}

private final class InMemoryConfigStore: ConfigStore, @unchecked Sendable {
    private let lock = NSLock()
    private var stored: AppConfiguration?

    func load() -> AppConfiguration? { lock.withLock { stored } }
    func save(_ configuration: AppConfiguration) { lock.withLock { stored = configuration } }
    func clear() { lock.withLock { stored = nil } }
}

private final class InMemoryKeychainStore: KeychainStore, @unchecked Sendable {
    private let lock = NSLock()
    private var stored: String?

    func save(_ apiKey: String) throws { lock.withLock { stored = apiKey } }
    func read() -> String? { lock.withLock { stored } }
    func delete() { lock.withLock { stored = nil } }
}
#endif
