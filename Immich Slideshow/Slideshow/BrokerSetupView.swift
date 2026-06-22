//
//  BrokerSetupView.swift
//  Immich Slideshow
//
//  Inline MQTT/broker editor rendered inside the Settings screen's collapsible
//  "MQTT" section (010 — folded in from the old standalone sheet). Backed by the
//  host-tested BrokerSetupViewModel, which the settings screen owns in its own
//  @State so collapsing/re-expanding the section keeps typed-but-unsaved edits.
//  Credentials live only in the Keychain via the injected store, and the stored
//  password is never prefilled in cleartext (FR-013).
//

import BrokerSetupKit
import Foundation
import SwiftUI

struct BrokerSettingsSection: View {
    @Bindable var viewModel: BrokerSetupViewModel

    var body: some View {
        Group {
            TextField("Host", text: $viewModel.host)
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
                .autocorrectionDisabled()
                .accessibilityIdentifier("broker.host")

            TextField("Port", text: $viewModel.port)
                .keyboardType(.numberPad)
                .accessibilityIdentifier("broker.port")

            TextField("Benutzername", text: $viewModel.username)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .accessibilityIdentifier("broker.username")

            SecureField(viewModel.passwordIsSet ? "Neues Passwort" : "Passwort", text: $viewModel.password)
                .accessibilityIdentifier("broker.password")

            if viewModel.passwordIsSet {
                Text("Passwort ist gesetzt — zum Ändern neu eingeben.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("broker.passwordHint")
            }

            if let message = viewModel.validationError.map(Self.message(for:)) {
                Text(message)
                    .foregroundStyle(.red)
                    .accessibilityIdentifier("broker.validation")
            }

            Button("Speichern") {
                // On success, reload from the store so the password masks itself again
                // and the "password is set" hint / remove action appear (FR-013).
                if viewModel.save() { viewModel.load() }
            }
            .accessibilityIdentifier("broker.save")

            if viewModel.passwordIsSet {
                Button("Entfernen", role: .destructive) { viewModel.remove() }
                    .accessibilityIdentifier("broker.remove")
            }
        }
    }

    private nonisolated static func message(for error: BrokerValidationError) -> String {
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

/// Selects the broker settings store: an in-memory store under `--uitest` so the
/// hermetic flow never touches the real Keychain, the Keychain store in production.
enum BrokerSettingsStoreFactory {
    static func make() -> any BrokerSettingsStore {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--uitest") {
            return BrokerSetupUITestStore.shared
        }
        #endif
        return KeychainBrokerSettingsStore()
    }
}

#if DEBUG
/// In-memory broker store for hermetic XCUITests (`--uitest`). Seeded with a
/// representative broker when `--uitest-broker-existing` is passed, so the change /
/// remove (US2) flow is testable without the real Keychain. Never built into Release.
final class BrokerSetupUITestStore: BrokerSettingsStore, @unchecked Sendable {
    static let shared = BrokerSetupUITestStore()

    private let lock = NSLock()
    private var stored: BrokerSettings?

    init() {
        if ProcessInfo.processInfo.arguments.contains("--uitest-broker-existing") {
            stored = BrokerSettings(
                host: "mqtt.example.com",
                port: 8883,
                username: "ha-user",
                password: "secret-pass"
            )
        }
    }

    func save(_ settings: BrokerSettings) throws {
        if let error = settings.validate() { throw error }
        lock.withLock { stored = settings }
    }

    func load() -> BrokerSettings? { lock.withLock { stored } }

    func clear() { lock.withLock { stored = nil } }
}
#endif
