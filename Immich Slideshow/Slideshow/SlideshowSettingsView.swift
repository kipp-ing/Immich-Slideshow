//
//  SlideshowSettingsView.swift
//  Immich Slideshow
//
//  Slice D — settings shell reached from the chrome. Brightness is live now
//  (backed by PowerManager / 004). The display options are the planned v1 wishlist
//  but stay disabled until the ThemeSettings module (#5) lands — the screen "lights
//  up" as those modules arrive, per the handover.
//

import OnboardingKit
import PowerKit
import SwiftUI
import ThemeKit
import UIKit

struct SlideshowSettingsView: View {
    let powerManager: PowerManager
    // The shared display-preferences store. Bound live by the display-option rows as
    // they come online (008); held here from T011 so the seam exists end to end.
    @Bindable var themeStore: UserDefaultsThemeStore
    // Connection editor seams (009): build a fresh editor view model on demand, and
    // report a successful change so the app can reconnect the running slideshow.
    var makeConnectionViewModel: () -> ConnectionSettingsViewModel? = { nil }
    var onConnectionChanged: (ConnectionValidationOutcome) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss
    @State private var brightness: Double
    @State private var connectionViewModel: ConnectionSettingsViewModel?
    @State private var showConnection = false

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
                    Button {
                        connectionViewModel = makeConnectionViewModel()
                        showConnection = connectionViewModel != nil
                    } label: {
                        HStack {
                            Label("Verbindung", systemImage: "server.rack")
                            Spacer()
                            Image(systemName: "chevron.forward")
                                .font(.footnote)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .accessibilityIdentifier("settings.connection")
                } header: {
                    Text("Server")
                } footer: {
                    Text("Server-Adresse und API-Schlüssel ändern.")
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
        .sheet(isPresented: $showConnection) {
            if let connectionViewModel {
                ConnectionSettingsView(viewModel: connectionViewModel) { outcome in
                    showConnection = false
                    onConnectionChanged(outcome)
                }
            }
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
