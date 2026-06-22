//
//  ConnectionStepView.swift
//  Immich Slideshow
//
//  Step 1 (merged): enter the server URL and API key on one screen. A single
//  Continue validates reachability AND authorization in one action (010), then
//  advances to album selection. The shared-album-link row is a reserved, inert
//  placeholder for a future feature (spec 011) — visible but disabled.
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

            Section {
                HStack {
                    Label("Shared album link", systemImage: "link")
                    Spacer()
                    Text("Coming soon")
                        .foregroundStyle(.tertiary)
                }
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("onboarding.sharedLinkPlaceholder")
            } footer: {
                Text("Using a shared album link will be available in a future update.")
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
