//
//  OnboardingFlowView.swift
//  Immich Slideshow
//
//  Three-step first-run setup: server URL -> API key -> album. Drives the
//  OnboardingViewModel; the app shows ContentView once step == .done.
//

import OnboardingKit
import SwiftUI

struct OnboardingFlowView: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.step {
                case .server:
                    ServerStepView(viewModel: viewModel)
                case .apiKey:
                    APIKeyStepView(viewModel: viewModel)
                case .album:
                    AlbumStepView(viewModel: viewModel)
                case .done:
                    // Routing to the main screen happens at the app level.
                    EmptyView()
                }
            }
            .navigationTitle("Setup")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
