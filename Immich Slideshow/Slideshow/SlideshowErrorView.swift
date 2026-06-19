//
//  SlideshowErrorView.swift
//  Immich Slideshow
//
//  Shown when the album's asset list cannot be loaded (FR-010). Offers a retry
//  rather than leaving a blank or crashed screen.
//

import SwiftUI

struct SlideshowErrorView: View {
    var onRetry: () -> Void = {}

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.exclamationmark")
                .imageScale(.large)
                .foregroundStyle(.secondary)
            Text("Couldn’t load the album")
                .font(.headline)
                .accessibilityIdentifier("slideshow.error")
            Text("Check the connection to your Immich server and try again.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Try again", action: onRetry)
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("slideshow.retry")
        }
        .padding()
        .foregroundStyle(.white)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        SlideshowErrorView()
    }
}
