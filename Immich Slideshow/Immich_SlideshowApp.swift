//
//  Immich_SlideshowApp.swift
//  Immich Slideshow
//
//  Created by Jan Kipping on 17.06.26.
//

import ImmichClient
import OnboardingKit
import SwiftUI

@main
struct Immich_SlideshowApp: App {
    @State private var viewModel: OnboardingViewModel

    init() {
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
