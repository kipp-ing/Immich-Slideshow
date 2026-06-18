//
//  Immich_SlideshowUITests.swift
//  Immich SlideshowUITests
//
//  Created by Jan Kipping on 17.06.26.
//

import XCTest

final class Immich_SlideshowUITests: XCTestCase {

    override func setUpWithError() throws {
        // Stop at the first failure so a broken step doesn't cascade into noise.
        continueAfterFailure = false
    }

    /// Launches the hermetic `--uitest` build (stub API + in-memory stores) and
    /// drives the full three-step onboarding flow end to end, asserting the app
    /// lands on the main screen. No network, no real keychain — deterministic.
    @MainActor
    func testOnboardingHappyPathReachesMainScreen() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest"]
        app.launch()

        // Step 1 — server URL
        let serverField = app.textFields["onboarding.serverURL"]
        XCTAssertTrue(serverField.waitForExistence(timeout: 5), "server URL field should appear")
        serverField.tap()
        serverField.typeText("https://demo.example.com")
        app.buttons["onboarding.server.continue"].tap()

        // Step 2 — API key
        let keyField = app.secureTextFields["onboarding.apiKey"]
        XCTAssertTrue(keyField.waitForExistence(timeout: 5), "API key field should appear")
        keyField.tap()
        keyField.typeText("dummy-key")
        app.buttons["onboarding.apiKey.connect"].tap()

        // Step 3 — pick the first stubbed album
        let album = app.buttons["onboarding.album.a1"]
        XCTAssertTrue(album.waitForExistence(timeout: 5), "stubbed album row should appear")
        album.tap()

        // Done — main screen
        XCTAssertTrue(
            app.staticTexts["main.completed"].waitForExistence(timeout: 5),
            "completing onboarding should route to the main screen"
        )
    }

    /// A fresh hermetic launch starts at step 1 (server URL).
    @MainActor
    func testFreshLaunchShowsServerStep() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest"]
        app.launch()
        XCTAssertTrue(app.textFields["onboarding.serverURL"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testLaunchPerformance() throws {
        // Measures launch time. Each iteration launches a fresh app, stops the
        // measurement once it is up, and terminates it before the next pass —
        // this avoids the flaky "unexpected number of metrics" the stock
        // template hits when iterations overlap on the simulator.
        let options = XCTMeasureOptions()
        options.invocationOptions = [.manuallyStop]
        measure(metrics: [XCTApplicationLaunchMetric()], options: options) {
            let app = XCUIApplication()
            app.launch()
            stopMeasuring()
            app.terminate()
        }
    }
}
