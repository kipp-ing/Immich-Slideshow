//
//  Immich_SlideshowApp.swift
//  Immich Slideshow
//
//  Created by Jan Kipping on 17.06.26.
//

import Foundation
import BrokerSetupKit
import HAControlKit
import HAControlMQTT
import ImmichClient
import OnboardingKit
import PowerKit
import SlideshowKit
import SwiftUI
import ThemeKit

@main
struct Immich_SlideshowApp: App {
    @State private var viewModel: OnboardingViewModel
    // Built lazily at the `.done` route: reads the saved config + Keychain key and
    // constructs an authenticated slideshow. Returns nil only if state is somehow
    // incomplete (the StartupGate normally prevents reaching `.done` without it).
    // Bundled into one `Sendable` value so SwiftUI's `@Sendable` WindowGroup content
    // closure captures a single Sendable struct rather than individual closure
    // properties (which trip a per-function-value data-race warning when read off
    // the App). `@MainActor` keeps the factories' captured stores main-actor-isolated.
    private let factories: Factories

    struct Factories: Sendable {
        // Built lazily at the `.done` route: reads the saved config + Keychain key and
        // constructs an authenticated slideshow. Returns nil only if state is somehow
        // incomplete (the StartupGate normally prevents reaching `.done` without it).
        // The shared ThemeSettingsStore is injected so the engine reads live display
        // preferences (008); the same instance backs the settings UI.
        let makeSlideshow: @MainActor @Sendable (any ThemeSettingsStore) -> SlideshowViewModel?
        // The authenticated Immich client for UI that browses beyond the active
        // album (the album-browser sheet). Same config/key as the slideshow.
        let makeAPI: @MainActor @Sendable () -> (any ImmichAPI)?
        // Keeps the display awake during the slideshow and can control brightness.
        // Backed by the live screen in production, a fake under `--uitest` so the
        // hermetic test never touches real device brightness.
        let makePowerManager: @MainActor @Sendable () -> PowerManager
        let makeCoordinator: @MainActor @Sendable (SlideshowViewModel, PowerManager) async -> HAControlCoordinator?
    }

    init() {
        #if DEBUG
        // Hermetic seam for XCUITests: when launched with `--uitest`, drive both the
        // onboarding flow and the slideshow against in-memory stubs — no network, no
        // real keychain — so the UI walkthrough is deterministic and CI-safe. The
        // production path below is untouched.
        if UITestSupport.isActive {
            let uitestViewModel = UITestSupport.makeViewModel()
            // Optional fast path for manual/visual verification: skip onboarding and
            // launch straight into the stubbed slideshow (used to screenshot the
            // running show, incl. landscape centering). Additive — the default
            // `--uitest` path still starts at onboarding step 1.
            if ProcessInfo.processInfo.arguments.contains("--uitest-slideshow") {
                uitestViewModel.step = .done
            }
            _viewModel = State(initialValue: uitestViewModel)
            factories = Factories(
                makeSlideshow: { @MainActor @Sendable store in UITestSupport.makeSlideshowViewModel(settingsStore: store) },
                makeAPI: { @MainActor @Sendable in StubImmichAPI() },
                makePowerManager: { @MainActor @Sendable in UITestSupport.makePowerManager() },
                makeCoordinator: { @MainActor @Sendable _, _ in nil }
            )
            return
        }
        #endif

        let config = UserDefaultsConfigStore()
        let keychain = KeychainAPIKeyStore()
        let brokerStore = KeychainBrokerSettingsStore()
        let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? "immich-slideshow-device"
        let brokerProvider = BrokerConfigProvider(settingsStore: brokerStore, deviceID: deviceID)
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
        let makeSlideshow: @MainActor @Sendable (any ThemeSettingsStore) -> SlideshowViewModel? = { settingsStore in
            guard let appConfig = config.load(), let apiKey = keychain.read() else { return nil }
            let client = ImmichClient(
                config: ServerConfig(baseURL: appConfig.baseURL, apiKey: apiKey)
            )
            return SlideshowViewModel(
                api: client,
                albumID: appConfig.selectedAlbumID,
                ticker: RealTicker(interval: SlideshowConfig.default.interval),
                settingsStore: settingsStore
            )
        }

        // Authenticated client for the album browser; nil only if state is somehow
        // incomplete (same guard as the slideshow factory).
        let makeAPI: @MainActor @Sendable () -> (any ImmichAPI)? = {
            guard let appConfig = config.load(), let apiKey = keychain.read() else { return nil }
            return ImmichClient(config: ServerConfig(baseURL: appConfig.baseURL, apiKey: apiKey))
        }

        // Production: drive the real device screen. The PowerManager gates all
        // effects to the foreground itself (Konstitution V).
        let makePowerManager: @MainActor @Sendable () -> PowerManager = {
            PowerManager(screen: UIScreenController())
        }
        let makeCoordinator: @MainActor @Sendable (SlideshowViewModel, PowerManager) async -> HAControlCoordinator? = { slideshow, powerManager in
            guard let brokerConfig = brokerProvider.load() else { return nil }

            // Best-effort album list for the HA select entity; empty on failure so
            // pause/play and brightness still work (FR-003 — broker is never blocking).
            var albums: [Album] = []
            if let appConfig = config.load(), let apiKey = keychain.read() {
                let client = ImmichClient(config: ServerConfig(baseURL: appConfig.baseURL, apiKey: apiKey))
                albums = (try? await client.albums()) ?? []
            }

            let adapter = SlideshowRemoteControlAdapter(
                slideshow: slideshow,
                powerManager: powerManager,
                albums: albums,
                currentAlbumID: config.load()?.selectedAlbumID
            )
            let transport = NIOMQTTTransport(config: brokerConfig)
            return HAControlCoordinator(
                transport: transport,
                control: adapter,
                configStore: brokerProvider,
                deviceName: "Immich Slideshow",
                enabledEntities: [.playback, .brightness, .album]
            )
        }

        factories = Factories(
            makeSlideshow: makeSlideshow,
            makeAPI: makeAPI,
            makePowerManager: makePowerManager,
            makeCoordinator: makeCoordinator
        )
    }

    var body: some Scene {
        // Capture as locals so the (Sendable) WindowGroup content closure captures
        // these values directly instead of `self`.
        let onboarding = viewModel
        let factories = factories
        return WindowGroup {
            RootView(onboarding: onboarding, factories: factories)
        }
    }
}

/// Routes between onboarding and the running slideshow. Holds the slideshow view
/// model for the lifetime of the `.done` state so its timer/prefetch survive
/// re-renders; reset tears it down and returns to onboarding (002/US3).
private struct RootView: View {
    let onboarding: OnboardingViewModel
    let factories: Immich_SlideshowApp.Factories

    @State private var slideshow: SlideshowViewModel?
    @State private var powerManager: PowerManager?
    @State private var api: (any ImmichAPI)?
    // One shared settings store for the lifetime of the slideshow: the engine reads
    // live preferences from it and the settings UI binds the same concrete instance
    // (008). UI tests run against an isolated, cleared suite so a fresh launch starts
    // from the calm defaults regardless of prior runs.
    @State private var themeStore = RootView.makeThemeStore()

    var body: some View {
        if onboarding.step == .done {
            if let slideshow, let powerManager, let api {
                SlideshowView(viewModel: slideshow, powerManager: powerManager, api: api,
                              themeStore: themeStore,
                              makeCoordinator: { await factories.makeCoordinator(slideshow, powerManager) },
                              onReset: {
                    self.slideshow = nil
                    self.powerManager = nil
                    self.api = nil
                    onboarding.reset()
                })
            } else {
                Color.black
                    .ignoresSafeArea()
                    .task {
                        slideshow = factories.makeSlideshow(themeStore)
                        powerManager = factories.makePowerManager()
                        api = factories.makeAPI()
                    }
            }
        } else {
            OnboardingFlowView(viewModel: onboarding)
        }
    }

    private static func makeThemeStore() -> UserDefaultsThemeStore {
        #if DEBUG
        if UITestSupport.isActive {
            // Hermetic UI-test store: a dedicated suite, cleared on launch, so the
            // "calm defaults" checks never inherit a previous run's choices.
            let suite = "uitest.theme"
            let defaults = UserDefaults(suiteName: suite) ?? .standard
            defaults.removePersistentDomain(forName: suite)
            return UserDefaultsThemeStore(defaults: defaults)
        }
        #endif
        return UserDefaultsThemeStore()
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

    static func makeSlideshowViewModel(settingsStore: any ThemeSettingsStore) -> SlideshowViewModel {
        SlideshowViewModel(
            api: StubImmichAPI(),
            albumID: "a1",
            ticker: RealTicker(interval: .seconds(2)),
            settingsStore: settingsStore
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

    func preview(assetID: String) async throws -> Data { Self.renderPortrait(for: assetID) }

    func assetInfo(assetID: String) async throws -> AssetInfo {
        // Deterministic EXIF for the photo-info overlay (15 June 2024, 14:30 UTC).
        AssetInfo(
            id: assetID,
            takenAt: Date(timeIntervalSince1970: 1_718_462_400),
            city: "Berlin",
            state: "Berlin",
            country: "Germany"
        )
    }

    // Renders a portrait (3:4) test image per asset: a landscape screen letterboxes
    // it left/right, which makes the centering fix visually verifiable. The white
    // inset border marks the image bounds and the centered dot marks its midpoint.
    private static func renderPortrait(for assetID: String) -> Data {
        let size = CGSize(width: 810, height: 1080)
        let colors: [String: UIColor] = [
            "asset-1": .systemRed,
            "asset-2": .systemGreen,
            "asset-3": .systemBlue,
        ]
        let color = colors[assetID] ?? .systemPurple
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            color.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            UIColor.white.setStroke()
            let border = UIBezierPath(rect: CGRect(x: 20, y: 20, width: size.width - 40, height: size.height - 40))
            border.lineWidth = 16
            border.stroke()
            UIColor.white.setFill()
            UIBezierPath(ovalIn: CGRect(x: size.width / 2 - 60, y: size.height / 2 - 60, width: 120, height: 120)).fill()
        }
        return image.pngData() ?? Data()
    }
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
