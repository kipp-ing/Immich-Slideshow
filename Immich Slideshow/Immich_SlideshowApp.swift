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

        // First-run check: only a complete state (config + key) skips onboarding.
        // US2 (StartupGate) refines this into the precise first-missing-step logic.
        if config.load() != nil, keychain.read() != nil {
            viewModel.step = .done
        }

        _viewModel = State(initialValue: viewModel)
    }

    var body: some Scene {
        WindowGroup {
            if viewModel.step == .done {
                ContentView()
            } else {
                OnboardingFlowView(viewModel: viewModel)
            }
        }
    }
}
