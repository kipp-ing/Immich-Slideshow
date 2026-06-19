//
//  UIScreenController.swift
//  Immich Slideshow
//
//  Real `ScreenControlling` implementation backing the PowerManager: maps onto
//  the live device screen brightness and the idle/auto-lock timer. Kept in the
//  app target so PowerKit stays UIKit-free and host-testable (Konstitution II).
//  Foreground-only effects (idle timer, brightness) are guaranteed by the
//  PowerManager's gating, not here (Konstitution V).
//

import PowerKit
import UIKit

@MainActor
final class UIScreenController: ScreenControlling {
    var brightness: Double {
        get { Double(UIScreen.main.brightness) }
        set { UIScreen.main.brightness = CGFloat(newValue) }
    }

    var isIdleTimerDisabled: Bool {
        get { UIApplication.shared.isIdleTimerDisabled }
        set { UIApplication.shared.isIdleTimerDisabled = newValue }
    }
}
