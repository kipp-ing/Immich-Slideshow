//
//  SettingsUITests.swift
//  Immich SlideshowUITests
//
//  Slice D — drives the settings shell: reveal chrome, open settings, confirm the
//  live brightness slider and a (disabled) planned-option row are present, adjust
//  brightness, and dismiss back to the slideshow.
//

import XCTest

final class SettingsUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testSettingsShowsBrightnessAndPlannedOptionsAndDismisses() throws {
        let app = XCUIApplication()
        // Pin the chrome so opening settings isn't racing the idle auto-hide.
        app.launchArguments = ["--uitest", "--uitest-slideshow", "--uitest-chrome"]
        app.launch()

        let image = app.descendants(matching: .any)
            .matching(identifier: "slideshow.image").firstMatch
        XCTAssertTrue(image.waitForExistence(timeout: 5))

        let settingsButton = app.buttons["slideshow.chrome.settings"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 2))
        settingsButton.tap()

        // Live brightness control.
        let slider = app.sliders["settings.brightness"]
        XCTAssertTrue(slider.waitForExistence(timeout: 3), "brightness slider should appear")
        slider.adjust(toNormalizedSliderPosition: 0.4)

        // A planned (disabled) option is previewed in the shell. Order/duration/
        // transition/Ken Burns/fit/quality are now live (008); the clock overlay is the
        // remaining placeholder until US4.
        let plannedRow = app.descendants(matching: .any)
            .matching(identifier: "settings.row.Uhr-Overlay").firstMatch
        XCTAssertTrue(plannedRow.exists, "the clock-overlay option should be previewed")

        // Dismiss back to the slideshow.
        app.buttons["Fertig"].tap()
        XCTAssertTrue(image.waitForExistence(timeout: 3))
        let dismissed = NSPredicate(format: "isHittable == false")
        expectation(for: dismissed, evaluatedWith: slider)
        waitForExpectations(timeout: 3)
    }
}
