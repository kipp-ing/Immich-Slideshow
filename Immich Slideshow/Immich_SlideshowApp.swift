//
//  Immich_SlideshowApp.swift
//  Immich Slideshow
//
//  Created by Jan Kipping on 17.06.26.
//

import Foundation
import ImmichClient
import OnboardingKit
import SwiftUI

@main
struct Immich_SlideshowApp: App {
    @State private var viewModel: OnboardingViewModel

    init() {
        #if DEBUG
        // Hermetic seam for XCUITests: when launched with `--uitest`, drive the
        // flow against an in-memory API/config/keychain — no network, no real
        // keychain — so the UI walkthrough is deterministic and CI-safe. The
        // production path below is untouched.
        if UITestSupport.isActive {
            _viewModel = State(initialValue: UITestSupport.makeViewModel())
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
        // (config + key) routes straight to the main screen (FR-001/FR-011).
        viewModel.step = StartupGate(config: config, keychain: keychain).initialStep()

        _viewModel = State(initialValue: viewModel)
    }

    var body: some Scene {
        WindowGroup {
            if viewModel.step == .done {
                ContentView(onReset: { viewModel.reset() })
            } else {
                OnboardingFlowView(viewModel: viewModel)
            }
        }
    }
}

#if DEBUG
// MARK: - UI test seam (DEBUG only)
//
// Activated solely by the `--uitest` launch argument that the XCUITest target
// passes. Keeps onboarding fully offline: a stubbed ImmichAPI plus in-memory
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
}

private struct StubImmichAPI: ImmichAPI {
    func serverVersion() async throws -> String { "1.0.0" }

    func albums() async throws -> [Album] {
        [Album(id: "a1", name: "Wohnzimmer"), Album(id: "a2", name: "Urlaub 2026")]
    }

    func assets(albumID: String) async throws -> [Asset] {
        [Asset(id: "asset-1", type: "IMAGE")]
    }

    func preview(assetID: String) async throws -> Data { Data([0xFF, 0xD8, 0xFF]) }
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
