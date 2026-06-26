//
//  OnboardingFlowView.swift
//  Immich Slideshow
//
//  First-run setup: server URL + API key -> add a source (album or shared link) ->
//  confirm -> slideshow. Drives the OnboardingViewModel; the source/confirm steps also
//  bind a SourceLibraryViewModel that writes the persisted library shared with the app.
//  Routing to the main screen happens at the app level once step == .done.
//

import OnboardingKit
import SwiftUI

struct OnboardingFlowView: View {
    let viewModel: OnboardingViewModel
    @State private var sourceLibrary: SourceLibraryViewModel

    init(viewModel: OnboardingViewModel, makeSourceLibrary: () -> SourceLibraryViewModel) {
        self.viewModel = viewModel
        _sourceLibrary = State(initialValue: makeSourceLibrary())
    }

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.step {
                case .choice:
                    OnboardingChoiceView(viewModel: viewModel)
                case .sharedLinkSetup:
                    SharedLinkSetupView(onboarding: viewModel, sourceLibrary: sourceLibrary)
                case .connection:
                    ConnectionStepView(viewModel: viewModel)
                case .source:
                    SourceStepView(onboarding: viewModel, sourceLibrary: sourceLibrary)
                case .confirm:
                    OnboardingConfirmStepView(onboarding: viewModel, sourceLibrary: sourceLibrary)
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
