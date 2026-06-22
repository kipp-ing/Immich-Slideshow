//
//  SlideshowSettingsView.swift
//  Immich Slideshow
//
//  Settings shell reached from the chrome. Brightness is live (PowerManager / 004)
//  and the display options bind the ThemeSettings store (008). Connection (009) and
//  MQTT/broker (006) are folded in here as collapsed-by-default disclosure sections
//  (010) — the calm default stays brightness + display, with the advanced config
//  tucked away until opened.
//

import BrokerSetupKit
import OnboardingKit
import PowerKit
import SwiftUI
import ThemeKit
import UIKit

struct SlideshowSettingsView: View {
    let powerManager: PowerManager
    // The shared display-preferences store, bound live by the display-option rows (008).
    @Bindable var themeStore: UserDefaultsThemeStore
    // Connection editor seams (009): the editor view model and a callback so a saved
    // change reconnects the running slideshow without re-onboarding.
    var makeConnectionViewModel: () -> ConnectionSettingsViewModel? = { nil }
    var onConnectionChanged: (ConnectionValidationOutcome) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss
    @State private var brightness: Double
    // Both editors are owned here as @State (not inside the disclosure content) so
    // collapsing/re-expanding a section keeps typed-but-unsaved edits.
    @State private var connectionViewModel: ConnectionSettingsViewModel?
    @State private var brokerViewModel: BrokerSetupViewModel
    // Advanced sections collapse by default (Constitution VII). UI tests pre-expand a
    // section via a launch argument so its fields are reachable without a tap.
    @State private var connectionExpanded: Bool
    @State private var mqttExpanded: Bool

    init(
        powerManager: PowerManager,
        themeStore: UserDefaultsThemeStore,
        makeConnectionViewModel: @escaping () -> ConnectionSettingsViewModel? = { nil },
        onConnectionChanged: @escaping (ConnectionValidationOutcome) -> Void = { _ in }
    ) {
        self.powerManager = powerManager
        self.themeStore = themeStore
        self.makeConnectionViewModel = makeConnectionViewModel
        self.onConnectionChanged = onConnectionChanged
        _brightness = State(initialValue: Self.currentScreenBrightness())
        _connectionViewModel = State(initialValue: makeConnectionViewModel())
        let broker = BrokerSetupViewModel(store: BrokerSettingsStoreFactory.make())
        broker.load()
        _brokerViewModel = State(initialValue: broker)
        let args = ProcessInfo.processInfo.arguments
        _connectionExpanded = State(initialValue: args.contains("--uitest-connection"))
        _mqttExpanded = State(initialValue: args.contains("--uitest-broker"))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "sun.min").foregroundStyle(.secondary)
                        Slider(value: $brightness, in: 0...1)
                            .accessibilityIdentifier("settings.brightness")
                        Image(systemName: "sun.max").foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Helligkeit")
                } footer: {
                    Text("Wirkt nur im Vordergrund, solange die Diashow läuft.")
                }

                Section {
                    Picker(selection: $themeStore.settings.order) {
                        Text("Zufällig").tag(PlayOrder.shuffle)
                        Text("Der Reihe nach").tag(PlayOrder.sequential)
                    } label: {
                        Label("Reihenfolge", systemImage: "shuffle")
                    }
                    .accessibilityIdentifier("settings.order")

                    Picker(selection: $themeStore.settings.duration) {
                        ForEach(Self.durationPresets, id: \.self) { duration in
                            Text(Self.durationLabel(duration)).tag(duration)
                        }
                    } label: {
                        Label("Anzeigedauer", systemImage: "timer")
                    }
                    .accessibilityIdentifier("settings.duration")

                    Picker(selection: $themeStore.settings.transition) {
                        Text("Überblenden").tag(Transition.crossfade)
                        Text("Schieben").tag(Transition.slide)
                        Text("Auflösen").tag(Transition.dissolve)
                        Text("Ohne").tag(Transition.none)
                    } label: {
                        Label("Übergang", systemImage: "wand.and.stars")
                    }
                    .accessibilityIdentifier("settings.transition")

                    Toggle(isOn: $themeStore.settings.kenBurns) {
                        Label("Ken Burns", systemImage: "camera.viewfinder")
                    }
                    .accessibilityIdentifier("settings.kenBurns")

                    Picker(selection: $themeStore.settings.fit) {
                        Text("Einpassen").tag(ImageFit.fit)
                        Text("Ausfüllen").tag(ImageFit.fill)
                    } label: {
                        Label("Bildanpassung", systemImage: "aspectratio")
                    }
                    .accessibilityIdentifier("settings.fit")

                    Picker(selection: $themeStore.settings.quality) {
                        Text("Vorschau").tag(ImageQuality.preview)
                        Text("Original").tag(ImageQuality.original)
                    } label: {
                        Label("Qualität", systemImage: "photo")
                    }
                    .accessibilityIdentifier("settings.quality")

                    placeholderRow("Uhr-Overlay", value: "Aus", systemImage: "clock")
                } header: {
                    Text("Anzeige")
                } footer: {
                    Text("Reihenfolge und Anzeigedauer wirken sofort. Weitere Optionen folgen.")
                }

                Section {
                    DisclosureGroup(isExpanded: $connectionExpanded) {
                        if let connectionViewModel {
                            ConnectionSettingsSection(viewModel: connectionViewModel) { outcome in
                                onConnectionChanged(outcome)
                                connectionExpanded = false
                            }
                        }
                    } label: {
                        Label("Verbindung", systemImage: "server.rack")
                            .accessibilityIdentifier("settings.connection")
                    }
                } header: {
                    Text("Server")
                } footer: {
                    Text("Server-Adresse und API-Schlüssel ändern.")
                }

                Section {
                    DisclosureGroup(isExpanded: $mqttExpanded) {
                        BrokerSettingsSection(viewModel: brokerViewModel)
                    } label: {
                        Label("MQTT", systemImage: "antenna.radiowaves.left.and.right")
                            .accessibilityIdentifier("settings.mqtt")
                    }
                } header: {
                    Text("Home Assistant")
                } footer: {
                    Text("MQTT-Broker für die Fernsteuerung über Home Assistant.")
                }
            }
            .navigationTitle("Einstellungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
        .onChange(of: brightness) { _, newValue in
            Task { await powerManager.setBrightness(newValue, animated: false) }
        }
    }

    /// Duration presets surfaced in the picker (a subset of the 3 s…600 s range the
    /// store accepts; out-of-range values are clamped by the store).
    private static let durationPresets: [Duration] = [
        .seconds(5), .seconds(10), .seconds(15), .seconds(30), .seconds(60), .seconds(300)
    ]

    private static func durationLabel(_ duration: Duration) -> String {
        let seconds = Int(duration.components.seconds)
        if seconds < 60 {
            return "\(seconds) s"
        }
        return "\(seconds / 60) min"
    }

    /// A disabled preview of a planned setting (lights up once its module exists).
    private func placeholderRow(_ title: String, value: String, systemImage: String) -> some View {
        HStack {
            Label(title, systemImage: systemImage)
            Spacer()
            Text(value)
        }
        .foregroundStyle(.secondary)
        .accessibilityIdentifier("settings.row.\(title)")
    }

    /// Live built-in-screen brightness via the active window scene (iOS 26 dropped
    /// `UIScreen.main`), mirroring UIScreenController so the slider starts accurate.
    private static func currentScreenBrightness() -> Double {
        let windowScenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
        let screen = (windowScenes.first { $0.activationState == .foregroundActive } ?? windowScenes.first)?.screen
        return Double(screen?.brightness ?? 1.0)
    }
}

/// Inline connection editor rendered inside the Settings "Verbindung" disclosure
/// section (010). Reuses the 009 `ConnectionSettingsViewModel`: validate before
/// persist, apply live on save, and never display the stored key. The standalone
/// `ConnectionSettingsView` sheet is kept for the slideshow's error-recovery path.
private struct ConnectionSettingsSection: View {
    @Bindable var viewModel: ConnectionSettingsViewModel
    var onSaved: (ConnectionValidationOutcome) -> Void

    var body: some View {
        Group {
            TextField("https://photos.example.com", text: $viewModel.serverURLInput)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
                .accessibilityIdentifier("connection.url")

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

            if let errorMessage = viewModel.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                    .accessibilityIdentifier("connection.error")
            }

            if viewModel.isBusy {
                ProgressView()
            } else {
                Button("Verbindung speichern", action: save)
                    .disabled(viewModel.serverURLInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("connection.save")
            }
        }
    }

    private func save() {
        Task {
            let outcome = await viewModel.save()
            switch outcome {
            case .success, .albumMissing:
                onSaved(outcome)
            default:
                // A failure leaves the prior connection intact; the inline error shows
                // and the section stays open so the user can correct it.
                break
            }
        }
    }
}
