//
//  PhotoInfoUITests.swift
//  Immich SlideshowUITests
//
//  Slice C — drives the photo-info overlay against the hermetic build. The stub
//  API returns deterministic EXIF (Berlin, Germany), so revealing the chrome and
//  tapping the info button must surface the date + location card.
//

import XCTest

final class PhotoInfoUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testInfoButtonTogglesDateAndLocationOverlay() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest", "--uitest-slideshow"]
        app.launch()

        let image = app.descendants(matching: .any)
            .matching(identifier: "slideshow.image").firstMatch
        XCTAssertTrue(image.waitForExistence(timeout: 5))

        // Reveal chrome, then toggle the info overlay on.
        image.tap()
        let infoButton = app.buttons["slideshow.chrome.info"]
        XCTAssertTrue(infoButton.waitForExistence(timeout: 2))
        infoButton.tap()

        let card = app.descendants(matching: .any)
            .matching(identifier: "slideshow.info.card").firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 3), "info overlay should appear")
        XCTAssertTrue(
            app.staticTexts["Berlin, Germany"].waitForExistence(timeout: 2),
            "overlay should show the stub location"
        )

        // Toggle it back off.
        infoButton.tap()
        let gone = NSPredicate(format: "exists == false")
        expectation(for: gone, evaluatedWith: card)
        waitForExpectations(timeout: 3)
    }
}
