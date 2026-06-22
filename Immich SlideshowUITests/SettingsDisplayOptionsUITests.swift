//
//  SettingsDisplayOptionsUITests.swift
//  Immich SlideshowUITests
//
//  008 / US1 — the order and duration rows are live controls bound to the settings
//  store, and the choices survive an app relaunch (SC-002). Drives the menu pickers
//  via XCUITest (MCP has no tap tools); the live-apply-to-the-running-show timing is
//  covered by the host DurationTickerTests.
//

import XCTest

final class SettingsDisplayOptionsUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testOrderAndDurationPersistAcrossRelaunch() throws {
        // Start from the calm defaults (reset the hermetic theme suite).
        let app = XCUIApplication()
        app.launchArguments = [
            "--uitest", "--uitest-slideshow", "--uitest-chrome", "--uitest-settings", "--uitest-reset-theme"
        ]
        app.launch()

        // Both live rows are present, showing the defaults.
        let order = app.descendants(matching: .any).matching(identifier: "settings.order").firstMatch
        XCTAssertTrue(order.waitForExistence(timeout: 5), "order picker should exist")
        let duration = app.descendants(matching: .any).matching(identifier: "settings.duration").firstMatch
        XCTAssertTrue(duration.waitForExistence(timeout: 2), "duration picker should exist")
        XCTAssertTrue(app.staticTexts["Zufällig"].firstMatch.exists, "order defaults to shuffle")
        XCTAssertTrue(app.staticTexts["15 s"].firstMatch.exists, "duration defaults to 15 s")

        // Change order shuffle -> sequential via the menu picker.
        order.tap()
        app.buttons["Der Reihe nach"].firstMatch.tap()

        // Change duration 15 s -> 30 s.
        duration.tap()
        app.buttons["30 s"].firstMatch.tap()

        // Relaunch WITHOUT the reset arg: the choices persist (SC-002).
        app.terminate()
        let relaunch = XCUIApplication()
        relaunch.launchArguments = [
            "--uitest", "--uitest-slideshow", "--uitest-chrome", "--uitest-settings"
        ]
        relaunch.launch()

        let orderAfter = relaunch.descendants(matching: .any)
            .matching(identifier: "settings.order").firstMatch
        XCTAssertTrue(orderAfter.waitForExistence(timeout: 5), "settings reopen after relaunch")
        XCTAssertTrue(
            relaunch.staticTexts["Der Reihe nach"].firstMatch.waitForExistence(timeout: 2),
            "sequential order should persist across relaunch"
        )
        XCTAssertTrue(
            relaunch.staticTexts["30 s"].firstMatch.exists,
            "30 s duration should persist across relaunch"
        )
    }
}
