//
//  KenBurnsModifier.swift
//  Immich Slideshow
//
//  008 / US2 — opt-in slow pan/zoom over the current photo (off by default, calm
//  default preserved). Each photo gets a fresh modifier identity via the image's
//  `.id`, so the motion restarts per photo from its base; it resets cleanly when the
//  show is paused. The motion duration follows the live per-photo duration (review R4).
//

import SwiftUI

struct KenBurnsModifier: ViewModifier {
    /// On only when Ken Burns is enabled and the show is actively playing (not paused).
    let isActive: Bool
    /// Per-photo duration; the pan/zoom spans the time the photo is on screen.
    let durationSeconds: Double

    @State private var progress: CGFloat = 0

    // Scale stays >= 1 (the photo is rendered fill-framed while Ken Burns is on) so the
    // slow zoom + pan never reveals a letterbox gap (spec assumption: Ken Burns implies
    // fill-style framing).
    private let startScale: CGFloat = 1.0
    private let endScale: CGFloat = 1.12
    private let pan: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .scaleEffect(isActive ? startScale + (endScale - startScale) * progress : 1.0)
            .offset(x: isActive ? pan * progress : 0, y: isActive ? -pan * progress : 0)
            .onAppear { if isActive { animateIn() } }
            .onChange(of: isActive) { _, active in
                if active { animateIn() } else { reset() }
            }
    }

    private func animateIn() {
        progress = 0
        withAnimation(.easeInOut(duration: max(durationSeconds, 0.1))) {
            progress = 1
        }
    }

    private func reset() {
        withAnimation(.easeOut(duration: 0.25)) { progress = 0 }
    }
}

extension View {
    func kenBurns(isActive: Bool, durationSeconds: Double) -> some View {
        modifier(KenBurnsModifier(isActive: isActive, durationSeconds: durationSeconds))
    }
}
