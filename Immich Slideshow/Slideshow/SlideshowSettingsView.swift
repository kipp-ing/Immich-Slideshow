//
//  SlideshowSettingsView.swift
//  Immich Slideshow
//
//  Slice D — settings shell reached from the chrome. Brightness is live now
//  (backed by PowerManager / 004). The display options are the planned v1 wishlist
//  but stay disabled until the ThemeSettings module (#5) lands — the screen "lights
//  up" as those modules arrive, per the handover.
//

import PowerKit
import SwiftUI
import UIKit

struct SlideshowSettingsView: View {
    let powerManager: PowerManager

    @Environment(\.dismiss) private var dismiss
    @State private var brightness: Double

    init(powerManager: PowerManager) {
        self.powerManager = powerManager
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
                    placeholderRow("Anzeigedauer", value: "8 s", systemImage: "timer")
                    placeholderRow("Übergang", value: "Überblenden", systemImage: "wand.and.stars")
                    placeholderRow("Ken Burns", value: "Aus", systemImage: "camera.viewfinder")
                    placeholderRow("Reihenfolge", value: "Album", systemImage: "list.number")
                    placeholderRow("Bildanpassung", value: "Einpassen", systemImage: "aspectratio")
                    placeholderRow("Uhr-Overlay", value: "Aus", systemImage: "clock")
                } header: {
                    Text("Anzeige")
                } footer: {
                    Text("Diese Optionen werden mit dem ThemeSettings-Modul aktiv.")
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
