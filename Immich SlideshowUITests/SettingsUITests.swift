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
            .matching(identifier: "settings.row.Clock overlay").firstMatch
        XCTAssertTrue(plannedRow.exists, "the clock-overlay option should be previewed")

        // Dismiss back to the slideshow.
        app.buttons["Done"].tap()
        XCTAssertTrue(image.waitForExistence(timeout: 3))
        let dismissed = NSPredicate(format: "isHittable == false")
        expectation(for: dismissed, evaluatedWith: slider)
        waitForExpectations(timeout: 3)
    }

    /// Connection (009) and MQTT/broker (006) are folded into Settings as collapsible
    /// sections that default to collapsed, keeping the calm default (010, FR-009/010/014).
    @MainActor
    func testConnectionAndMqttAppearAsCollapsedSections() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest", "--uitest-slideshow", "--uitest-chrome"]
        app.launch()

        let image = app.descendants(matching: .any)
            .matching(identifier: "slideshow.image").firstMatch
        XCTAssertTrue(image.waitForExistence(timeout: 5))

        let settingsButton = app.buttons["slideshow.chrome.settings"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 2))
        settingsButton.tap()

        // Both advanced sections are present (scrolled into view — they sit below the
        // brightness/display sections).
        let connection = app.descendants(matching: .any)
            .matching(identifier: "settings.connection").firstMatch
        XCTAssertTrue(scrollToElement(connection, in: app), "Connection section should be present")
        let mqtt = app.descendants(matching: .any)
            .matching(identifier: "settings.mqtt").firstMatch
        XCTAssertTrue(scrollToElement(mqtt, in: app), "MQTT section should be present")

        // Collapsed by default: their inner fields are not rendered until expanded.
        XCTAssertFalse(app.textFields["connection.url"].exists, "Connection fields hidden until expanded")
        XCTAssertFalse(app.textFields["broker.host"].exists, "MQTT fields hidden until expanded")
    }

    /// The settings form must scroll so every section — including the folded-in
    /// Connection and MQTT at the bottom — is reachable in both orientations (010/US3,
    /// FR-015/FR-016).
    @MainActor
    func testBottomSettingsSectionReachableInBothOrientations() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest", "--uitest-slideshow", "--uitest-chrome"]
        app.launch()
        defer { XCUIDevice.shared.orientation = .portrait }

        let image = app.descendants(matching: .any)
            .matching(identifier: "slideshow.image").firstMatch
        XCTAssertTrue(image.waitForExistence(timeout: 5))
        let settingsButton = app.buttons["slideshow.chrome.settings"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 2))
        settingsButton.tap()

        // Portrait: the bottom-most section (MQTT) scrolls into view.
        XCUIDevice.shared.orientation = .portrait
        let mqtt = app.descendants(matching: .any).matching(identifier: "settings.mqtt").firstMatch
        XCTAssertTrue(scrollToElement(mqtt, in: app), "MQTT section reachable in portrait")

        // Landscape: still reachable after rotating (the form keeps scrolling).
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(scrollToElement(mqtt, in: app), "MQTT section reachable in landscape")
    }

    /// Swipes up until the element exists (or the swipe budget is exhausted).
    @MainActor
    private func scrollToElement(_ element: XCUIElement, in app: XCUIApplication, maxSwipes: Int = 8) -> Bool {
        if element.waitForExistence(timeout: 3) { return true }
        var swipes = 0
        while !element.exists && swipes < maxSwipes {
            app.swipeUp()
            swipes += 1
        }
        return element.exists
    }
}
