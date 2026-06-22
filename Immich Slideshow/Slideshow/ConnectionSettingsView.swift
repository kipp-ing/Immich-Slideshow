//
//  ConnectionSettingsView.swift
//  Immich Slideshow
//
//  In-app editor for the Immich connection (server URL + API key), reachable from
//  the settings screen and from the slideshow's connection-error state (009).
//  Validates (reachable + authorized) before persisting; the stored API key is
//  never shown — only a "key is set" indicator — and an empty key field keeps the
//  existing key (Constitution III). On a successful save the app reconnects the
//  running slideshow without re-onboarding.
//

import OnboardingKit
import SwiftUI

struct ConnectionSettingsView: View {
    @Bindable var viewModel: ConnectionSettingsViewModel
    var onSaved: (ConnectionValidationOutcome) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("https://photos.example.com", text: $viewModel.serverURLInput)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .accessibilityIdentifier("connection.url")
                } header: {
                    Text("Server-Adresse")
                }

                Section {
                    SecureField("Neuer API-Schlüssel", text: $viewModel.apiKeyInput)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("connection.apiKey")
                    if viewModel.keyIsSet {
                        Label("Schlüssel ist gesetzt", systemImage: "key.fill")
                            .foregroundStyle(.secondary)
                            .font(.footnote)
                            .accessibilityIdentifier("connection.keySet")
                    }
                } header: {
                    Text("API-Schlüssel")
                } footer: {
                    Text("Leer lassen, um den gespeicherten Schlüssel zu behalten.")
                }

                if let errorMessage = viewModel.errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                            .accessibilityIdentifier("connection.error")
                    }
                }
            }
            .navigationTitle("Verbindung")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                        .disabled(viewModel.isBusy)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if viewModel.isBusy {
                        ProgressView()
                    } else {
                        Button("Speichern", action: save)
                            .disabled(isSaveDisabled)
                            .accessibilityIdentifier("connection.save")
                    }
                }
            }
        }
    }

    private var isSaveDisabled: Bool {
        viewModel.serverURLInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func save() {
        Task {
            let outcome = await viewModel.save()
            switch outcome {
            case .success, .albumMissing:
                onSaved(outcome)
                dismiss()
            default:
                // A failure leaves the prior connection intact; the inline error is
                // shown and the editor stays open so the user can correct it.
                break
            }
        }
    }
}
