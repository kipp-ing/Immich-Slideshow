//
//  ContentView.swift
//  Immich Slideshow
//
//  Created by Jan Kipping on 17.06.26.
//
//  Placeholder main screen shown once onboarding is complete. The toolbar
//  offers a reset action that clears the saved config + API key and returns to
//  onboarding (US3, FR-012).
//

import SwiftUI

struct ContentView: View {
    var onReset: () -> Void = {}

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "photo.stack")
                    .imageScale(.large)
                    .foregroundStyle(.tint)
                Text("Setup complete")
                    .font(.headline)
                    .accessibilityIdentifier("main.completed")
                Text("The slideshow will follow in a later step.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Reset", systemImage: "arrow.counterclockwise", action: onReset)
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
