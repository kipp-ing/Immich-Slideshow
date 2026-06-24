//
//  ConnectionStepView.swift
//  Immich Slideshow
//
//  Step 1 (merged): enter the server URL and API key on one screen. A single
//  Continue validates reachability AND authorization in one action (010), then
//  advances to the add-source step (album or shared link, 120).
//

import OnboardingKit
import SwiftUI

struct ConnectionStepView: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        Form {
            Section {
                TextField("https://immich.example.com", text: $viewModel.serverURLInput)
                    .textContentType(.URL)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .disabled(viewModel.isBusy)
                    .accessibilityIdentifier("onboarding.serverURL")
            } header: {
                Text("Server address")
            } footer: {
                Text("Address of your Immich instance. Only HTTPS is supported.")
            }

            Section {
                SecureField("API Key", text: $viewModel.apiKeyInput)
                    .textContentType(.password)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .disabled(viewModel.isBusy)
                    .accessibilityIdentifier("onboarding.apiKey")
            } header: {
                Text("API Key")
            } footer: {
                Text("Create one in Immich under Account Settings → API Keys.")
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }

            Section {
                Button {
                    Task { await viewModel.submitConnection() }
                } label: {
                    HStack {
                        Text("Continue")
                        if viewModel.isBusy {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(isContinueDisabled)
                .accessibilityIdentifier("onboarding.connection.continue")
            }
        }
    }

    // Both values are required before a single connection can be validated (FR-005).
    private var isContinueDisabled: Bool {
        viewModel.isBusy
            || viewModel.serverURLInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || viewModel.apiKeyInput.isEmpty
    }
}
