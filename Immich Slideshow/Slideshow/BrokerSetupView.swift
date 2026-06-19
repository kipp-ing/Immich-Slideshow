//
//  BrokerSetupView.swift
//  Immich Slideshow
//

import BrokerSetupKit
import SwiftUI

struct BrokerSetupView: View {
    private let store: any BrokerSettingsStore

    @Environment(\.dismiss) private var dismiss
    @State private var host = ""
    @State private var port = "8883"
    @State private var username = ""
    @State private var password = ""
    @State private var validationMessage: String?

    init(store: any BrokerSettingsStore = KeychainBrokerSettingsStore()) {
        self.store = store
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Host", text: $host)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("broker.host")

                    TextField("Port", text: $port)
                        .keyboardType(.numberPad)
                        .accessibilityIdentifier("broker.port")

                    TextField("Benutzername", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("broker.username")

                    SecureField("Passwort", text: $password)
                        .accessibilityIdentifier("broker.password")
                }

                if let validationMessage {
                    Section {
                        Text(validationMessage)
                            .foregroundStyle(.red)
                            .accessibilityIdentifier("broker.validation")
                    }
                }
            }
            .navigationTitle("Broker einrichten")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern", action: save)
                        .accessibilityIdentifier("broker.save")
                }
            }
        }
    }

    private func save() {
        let settings = BrokerSettings(
            host: host,
            port: Int(port) ?? 0,
            username: username,
            password: password
        )

        do {
            try store.save(settings)
            dismiss()
        } catch let error as BrokerValidationError {
            validationMessage = message(for: error)
        } catch {
            validationMessage = "Die Broker-Einstellungen konnten nicht gespeichert werden."
        }
    }

    private func message(for error: BrokerValidationError) -> String {
        switch error {
        case .emptyHost:
            "Bitte gib einen Broker-Host ein."
        case .invalidPort:
            "Bitte gib einen Port zwischen 1 und 65535 ein."
        case .emptyUsername:
            "Bitte gib einen Benutzernamen ein."
        case .emptyPassword:
            "Bitte gib ein Passwort ein."
        }
    }
}
