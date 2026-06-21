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
    var makeCoordinator: () async -> HAControlCoordinator? = { nil }
    var onReset: () -> Void = {}

    @Environment(\.scenePhase) private var scenePhase
    @State private var showResetDialog = false
    @State private var showBrokerSetup = false
    @State private var coordinator: HAControlCoordinator?
    @State private var isStartingCoordinator = false

    // Reveal-on-tap chrome (Slice A). Hidden by default; a tap reveals it and an
    // idle timer hides it again. The status bar follows it so the calm default
    // stays overlay-free.
    // Default hidden; `--uitest-chrome` starts revealed for screenshot verification
    // (auto-hide only arms on reveal/interaction, so it stays up).
    @State private var chromeVisible = ProcessInfo.processInfo.arguments.contains("--uitest-chrome")
    @State private var autoHideTask: Task<Void, Never>?
    @State private var showSettings = false
    @State private var showAlbumBrowser = false
    @State private var showInfo = false

    private static let chromeAutoHide: Duration = .seconds(4.5)

    var body: some View {
        ZStack {
            // The letterboxed image fills the whole screen and owns the gestures so
            // tap/swipe cover everything (incl. under the hidden status bar).
            phaseContent
                .ignoresSafeArea()
                .contentShape(Rectangle())
                // Tap toggles the chrome; a horizontal swipe advances without revealing it.
                .onTapGesture { toggleChrome() }
                .gesture(swipeGesture)
                .onLongPressGesture { showResetDialog = true }

            // Chrome sits inside the safe area (sibling, not safe-area-ignoring) so the
            // bars don't collide with the screen edges / home indicator.
            chromeOverlay
        }
        // Status bar + home indicator follow the chrome: hidden in the calm default
        // (fixes the always-visible iPad clock/battery), revealed with the controls.
        .statusBarHidden(!chromeVisible)
        .persistentSystemOverlays(chromeVisible ? .automatic : .hidden)
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
            autoHideTask?.cancel()
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
        .sheet(isPresented: $showAlbumBrowser) {
            // TODO(Slice B): real album-browser sheet (album grid -> thumbnails).
            chromePlaceholderSheet(title: "Alben")
        }
        .sheet(isPresented: $showSettings) {
            // TODO(Slice D): real settings shell.
            chromePlaceholderSheet(title: "Einstellungen")
        }
    }

    @ViewBuilder
    private var phaseContent: some View {
        ZStack {
            Color.black

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
    }

    // MARK: - Chrome reveal + auto-hide

    private func toggleChrome() {
        if chromeVisible { hideChrome() } else { revealChrome() }
    }

    private func revealChrome() {
        chromeVisible = true
        scheduleAutoHide()
    }

    private func hideChrome() {
        chromeVisible = false
        showInfo = false
        autoHideTask?.cancel()
        autoHideTask = nil
    }

    /// (Re)arm the idle countdown that hides the chrome again. Called on reveal
    /// and on every control interaction so the chrome stays up while in use.
    private func scheduleAutoHide() {
        autoHideTask?.cancel()
        autoHideTask = Task { @MainActor in
            try? await Task.sleep(for: Self.chromeAutoHide)
            guard !Task.isCancelled else { return }
            hideChrome()
        }
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 40)
            .onEnded { value in
                // Horizontal swipe advances next/prev without revealing the chrome.
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                if value.translation.width < 0 {
                    Task { await viewModel.showNext() }
                } else {
                    Task { await viewModel.showPrevious() }
                }
            }
    }

    @ViewBuilder
    private var chromeOverlay: some View {
        SlideshowChrome(
            viewModel: viewModel,
            onExit: { showResetDialog = true },
            onInfo: { showInfo.toggle(); scheduleAutoHide() },
            onAlbums: { showAlbumBrowser = true },
            onSettings: { showSettings = true },
            onInteraction: { scheduleAutoHide() }
        )
        .overlay(alignment: .top) {
            if showInfo {
                photoInfoCard
                    .padding(.top, 100)
                    .transition(.opacity)
            }
        }
        .opacity(chromeVisible ? 1 : 0)
        .animation(.easeInOut(duration: 0.3), value: chromeVisible)
        .allowsHitTesting(chromeVisible)
    }

    // TODO(Slice C): replace with real EXIF date/time + location.
    private var photoInfoCard: some View {
        Text(viewModel.currentAssetID ?? "—")
            .font(.callout)
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .glassEffect(in: .capsule)
            .accessibilityIdentifier("slideshow.info.card")
    }

    // TODO(Slices B/D): replaced by the album browser and settings shell.
    private func chromePlaceholderSheet(title: String) -> some View {
        NavigationStack {
            Color(.systemBackground)
                .ignoresSafeArea()
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func startCoordinator() async {
        // One coordinator/transport per run: build fresh on start, fully tear down on stop.
        // That keeps the MQTT client re-connectable across background/foreground (the old
        // reused-client path stayed offline after the first background cycle).
        // `isStartingCoordinator` guards the await gap (building now fetches the album
        // list) against a second appear/scenePhase call building a duplicate. All on the
        // main actor, so the flag check/set is race-free.
        guard coordinator == nil, !isStartingCoordinator else { return }
        isStartingCoordinator = true
        defer { isStartingCoordinator = false }

        guard let coordinator = await makeCoordinator() else { return }
        self.coordinator = coordinator
        await coordinator.start()
        // Connect failed: release it so a later appear/foreground retries instead of being
        // stuck. stop() fully tears the transport down (disconnect + shutdown).
        if coordinator.connection == .disconnected {
            self.coordinator = nil
            await coordinator.stop()
        }
    }

    private func stopCoordinator() async {
        guard let coordinator else { return }
        self.coordinator = nil
        await coordinator.stop()
    }

    @ViewBuilder
    private var currentImage: some View {
        if let data = viewModel.currentImageData, let image = UIImage(data: data) {
            // Fit (letterbox) the image into the full screen and center it. Applying
            // `.ignoresSafeArea()` directly to a `scaledToFit` image expands its frame
            // asymmetrically by the safe-area insets, which pushed the picture off-center
            // in landscape; instead the whole ZStack ignores the safe area and the image
            // fills + centers within it.
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .id(viewModel.currentAssetID)
                .transition(.opacity)
        } else {
            Color.black
        }
    }
}
