//
//  BrokerSetupView.swift
//  Immich Slideshow
//

import Foundation
import BrokerSetupKit
import SwiftUI

struct BrokerSetupView: View {
    private let store: any BrokerSettingsStore

    @Environment(\.dismiss) private var dismiss
    @State private var host = ""
    @State private var port = "8883"
    @State private var username = ""
    @State private var password = ""
    // True once existing settings are loaded: a password is already stored, so we
    // show a "set" hint instead of prefilling it (FR-009) and offer removal (FR-008).
    @State private var passwordIsSet = false
    @State private var validationMessage: String?

    init(store: (any BrokerSettingsStore)? = nil) {
        self.store = store ?? Self.defaultStore()
    }

    private static func defaultStore() -> any BrokerSettingsStore {
        #if DEBUG
        // Hermetic XCUITests drive an in-memory store so the change/remove flow never
        // touches the real Keychain. The production path uses the Keychain store.
        if ProcessInfo.processInfo.arguments.contains("--uitest") {
            return BrokerSetupUITestStore.shared
        }
        #endif
        return KeychainBrokerSettingsStore()
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

                    SecureField(passwordIsSet ? "Neues Passwort" : "Passwort", text: $password)
                        .accessibilityIdentifier("broker.password")

                    if passwordIsSet {
                        Text("Passwort ist gesetzt — zum Ändern neu eingeben.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("broker.passwordHint")
                    }
                }

                if let validationMessage {
                    Section {
                        Text(validationMessage)
                            .foregroundStyle(.red)
                            .accessibilityIdentifier("broker.validation")
                    }
                }

                if passwordIsSet {
                    Section {
                        Button("Entfernen", role: .destructive, action: remove)
                            .accessibilityIdentifier("broker.remove")
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
            .onAppear(perform: loadExisting)
        }
    }

    // Prefill host/port/username from a stored broker so it can be edited. The
    // password is intentionally left blank (FR-009) — `passwordIsSet` drives the hint.
    private func loadExisting() {
        guard let existing = store.load() else { return }
        host = existing.host
        port = String(existing.port)
        username = existing.username
        passwordIsSet = true
    }

    private func save() {
        // An empty password field while a password is already stored means "keep it":
        // reuse the stored secret rather than forcing re-entry (FR-007). The secret is
        // only read transiently here and never displayed.
        let effectivePassword: String
        if password.isEmpty, let existing = store.load() {
            effectivePassword = existing.password
        } else {
            effectivePassword = password
        }

        let settings = BrokerSettings(
            host: host,
            port: Int(port) ?? 0,
            username: username,
            password: effectivePassword
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

    private func remove() {
        store.clear()
        dismiss()
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
