//
//  SlideshowView.swift
//  Immich Slideshow
//
//  Fullscreen slideshow of the selected album. Shows one image at a time with a
//  gentle cross-fade between images (FR-002/FR-004). Empty/error states surface
//  a calm hint instead of a blank screen (FR-009/FR-010). A long-press reveals an
//  unobtrusive reset action, preserving the 002/US3 reset path without cluttering
//  the quiet default (Konstitution VII).
//

import SlideshowKit
import SwiftUI

struct SlideshowView: View {
    let viewModel: SlideshowViewModel
    var onReset: () -> Void = {}

    @Environment(\.scenePhase) private var scenePhase
    @State private var showResetDialog = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch viewModel.phase {
            case .loading:
                ProgressView()
                    .tint(.white)
                    .accessibilityIdentifier("slideshow.loading")

            case .playing:
                currentImage
                    .accessibilityElement()
                    .accessibilityLabel("Slideshow image")
                    .accessibilityIdentifier("slideshow.image")

            case .empty:
                SlideshowEmptyView()

            case .failed:
                SlideshowErrorView(onRetry: { Task { await viewModel.retry() } })
            }
        }
        .animation(.easeInOut(duration: 0.6), value: viewModel.currentAssetID)
        .task { await viewModel.start() }
        .onChange(of: scenePhase) { _, newPhase in
            // Foreground-only timer (Konstitution V, FR-012): iOS hands control back
            // in the background, so pause the auto-advance and resume on return.
            switch newPhase {
            case .active: viewModel.resume()
            default: viewModel.pause()
            }
        }
        .onLongPressGesture { showResetDialog = true }
        .confirmationDialog(
            "Reset configuration?",
            isPresented: $showResetDialog,
            titleVisibility: .visible
        ) {
            Button("Reset", role: .destructive, action: onReset)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This clears the server, API key, and album, and returns to setup.")
        }
    }

    @ViewBuilder
    private var currentImage: some View {
        if let data = viewModel.currentImageData, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .ignoresSafeArea()
                .id(viewModel.currentAssetID)
                .transition(.opacity)
        } else {
            Color.black.ignoresSafeArea()
        }
    }
}
