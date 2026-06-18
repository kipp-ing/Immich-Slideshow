//
//  ServerStepView.swift
//  Immich Slideshow
//
//  Step 1: enter and verify the Immich server URL (HTTPS, reachable).
//

import OnboardingKit
import SwiftUI

struct ServerStepView: View {
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
            } header: {
                Text("Server-Adresse")
            } footer: {
                Text("Adresse deiner Immich-Instanz. Nur HTTPS wird unterstützt.")
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }

            Section {
                Button {
                    Task { await viewModel.submitServerURL() }
                } label: {
                    HStack {
                        Text("Weiter")
                        if viewModel.isBusy {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(viewModel.isBusy || viewModel.serverURLInput.isEmpty)
            }
        }
    }
}
