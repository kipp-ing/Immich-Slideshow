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
    /// drives onboarding end to end, asserting the app lands on the running
    /// slideshow (first image visible). Server URL and API key are now collected on
    /// one screen (010), so it is a single Continue then album selection. No network,
    /// no real keychain — deterministic.
    @MainActor
    func testOnboardingHappyPathReachesSlideshow() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest"]
        app.launch()

        // Combined connection step — server URL + API key on one screen.
        let serverField = app.textFields["onboarding.serverURL"]
        XCTAssertTrue(serverField.waitForExistence(timeout: 5), "server URL field should appear")
        serverField.tap()
        serverField.typeText("https://demo.example.com")

        let keyField = app.secureTextFields["onboarding.apiKey"]
        XCTAssertTrue(keyField.waitForExistence(timeout: 5), "API key field should appear")
        keyField.tap()
        keyField.typeText("dummy-key")

        // One action validates reachability + authorization, then advances (FR-001/FR-002).
        app.buttons["onboarding.connection.continue"].tap()

        // Pick the first stubbed album.
        let album = app.buttons["onboarding.album.a1"]
        XCTAssertTrue(album.waitForExistence(timeout: 5), "stubbed album row should appear")
        album.tap()

        // Done — the slideshow starts and shows the first image (FR-002/SC-001).
        // Generous ceiling: the merged one-screen flow reaches here faster than the
        // old three-step flow, so the first asset load/render now lands on a colder
        // simulator under full-suite load. The wait returns the instant the image
        // appears; the ceiling only bites when the simulator is heavily loaded.
        let slideshowImage = app.descendants(matching: .any)
            .matching(identifier: "slideshow.image").firstMatch
        XCTAssertTrue(
            slideshowImage.waitForExistence(timeout: 30),
            "completing onboarding should route to the running slideshow"
        )
    }

    /// A fresh hermetic launch starts at the combined connection step.
    @MainActor
    func testFreshLaunchShowsConnectionStep() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest"]
        app.launch()
        XCTAssertTrue(app.textFields["onboarding.serverURL"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.secureTextFields["onboarding.apiKey"].waitForExistence(timeout: 5))
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
