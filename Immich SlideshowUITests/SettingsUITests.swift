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
        app.launchArguments = ["--uitest", "--uitest-slideshow"]
        app.launch()

        let image = app.descendants(matching: .any)
            .matching(identifier: "slideshow.image").firstMatch
        XCTAssertTrue(image.waitForExistence(timeout: 5))

        image.tap()
        let settingsButton = app.buttons["slideshow.chrome.settings"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 2))
        settingsButton.tap()

        // Live brightness control.
        let slider = app.sliders["settings.brightness"]
        XCTAssertTrue(slider.waitForExistence(timeout: 3), "brightness slider should appear")
        slider.adjust(toNormalizedSliderPosition: 0.4)

        // A planned (disabled) option is previewed in the shell.
        let plannedRow = app.descendants(matching: .any)
            .matching(identifier: "settings.row.Ken Burns").firstMatch
        XCTAssertTrue(plannedRow.exists, "planned options should be previewed")

        // Dismiss back to the slideshow.
        app.buttons["Fertig"].tap()
        XCTAssertTrue(image.waitForExistence(timeout: 3))
        let dismissed = NSPredicate(format: "isHittable == false")
        expectation(for: dismissed, evaluatedWith: slider)
        waitForExpectations(timeout: 3)
    }
}
