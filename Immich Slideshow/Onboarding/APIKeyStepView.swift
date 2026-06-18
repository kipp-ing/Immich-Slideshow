//
//  APIKeyStepView.swift
//  Immich Slideshow
//
//  Step 2: enter the API key (SecureField, never logged). On success the key is
//  stored in the keychain and the album list is loaded for step 3.
//

import OnboardingKit
import SwiftUI

struct APIKeyStepView: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        Form {
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
                    Task { await viewModel.submitAPIKey() }
                } label: {
                    HStack {
                        Text("Connect")
                        if viewModel.isBusy {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(viewModel.isBusy || viewModel.apiKeyInput.isEmpty)
                .accessibilityIdentifier("onboarding.apiKey.connect")
            }
        }
    }
}
