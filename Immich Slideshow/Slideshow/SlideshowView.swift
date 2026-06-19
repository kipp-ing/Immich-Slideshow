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

import HAControlKit
import PowerKit
import SlideshowKit
import SwiftUI

struct SlideshowView: View {
    let viewModel: SlideshowViewModel
    let powerManager: PowerManager
    let coordinator: HAControlCoordinator?
    var onReset: () -> Void = {}

    @Environment(\.scenePhase) private var scenePhase
    @State private var showResetDialog = false
    @State private var showBrokerSetup = false
    @State private var isCoordinatorRunning = false

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
        .task {
            // Entering the slideshow: keep the display awake while it runs in the
            // foreground (FR-001). Idle timer is normalized again on disappear.
            powerManager.activate()
            await viewModel.start()
            await startCoordinator()
        }
        .onDisappear {
            // Leaving the slideshow: restore the idle timer and any app-changed
            // brightness to its baseline (FR-002/FR-011).
            powerManager.deactivate()
            Task { await stopCoordinator() }
        }
        .onChange(of: scenePhase) { _, newPhase in
            // Foreground-only effects (Konstitution V, FR-003/FR-004/FR-012): iOS hands
            // control back in the background, so pause the auto-advance and release the
            // keep-awake; resume and re-acquire on return.
            switch newPhase {
            case .active:
                viewModel.resume()
                powerManager.willEnterForeground()
                Task { await startCoordinator() }
            default:
                viewModel.pause()
                powerManager.didEnterBackground()
                Task { await stopCoordinator() }
            }
        }
        .onLongPressGesture { showResetDialog = true }
        .confirmationDialog(
            "Reset configuration?",
            isPresented: $showResetDialog,
            titleVisibility: .visible
        ) {
            Button("Broker einrichten") { showBrokerSetup = true }
            Button("Reset", role: .destructive, action: onReset)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This clears the server, API key, and album, and returns to setup.")
        }
        .sheet(isPresented: $showBrokerSetup) {
            BrokerSetupView()
        }
    }

    private func startCoordinator() async {
        guard let coordinator else { return }
        guard !isCoordinatorRunning else { return }
        isCoordinatorRunning = true
        await coordinator.start()
    }

    private func stopCoordinator() async {
        guard let coordinator else { return }
        guard isCoordinatorRunning else { return }
        await coordinator.stop()
        isCoordinatorRunning = false
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
