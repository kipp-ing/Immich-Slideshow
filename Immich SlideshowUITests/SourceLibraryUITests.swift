//
//  SourceLibraryUITests.swift
//  Immich SlideshowUITests
//
//  120 / US2 — drives the Settings → Sources source manager against the hermetic
//  in-memory source library: open the manager, add a second source, switch the active
//  one (the running slideshow swaps its photo), and remove a source.
//

import XCTest

final class SourceLibraryUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Switching the active source restarts the running slideshow from it: the seeded
    /// album (a1) plays asset-1…3; after adding and activating album a2 the photo swaps
    /// to asset-4…6. The asset id is read from the image's accessibility value.
    @MainActor
    func testSwitchingActiveSourceSwapsRunningSlideshow() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest", "--uitest-slideshow", "--uitest-chrome"]
        app.launch()

        let image = app.descendants(matching: .any).matching(identifier: "slideshow.image").firstMatch
        XCTAssertTrue(image.waitForExistence(timeout: 5))
        XCTAssertTrue(["asset-1", "asset-2", "asset-3"].contains(image.value as? String ?? ""),
                      "seeded source a1 should be playing first")

        openSources(in: app)

        // Seeded source is present and active.
        XCTAssertTrue(app.buttons["sources.row.src-a1"].waitForExistence(timeout: 3))

        addAlbum(named: "Urlaub 2026", in: app)

        // Activate the new source; the manager marks it and the slideshow swaps album.
        let newRow = app.buttons["Urlaub 2026"]
        XCTAssertTrue(newRow.waitForExistence(timeout: 3))
        newRow.tap()

        // Back out of the manager and close settings to see the running slideshow.
        app.navigationBars["Sources"].buttons.element(boundBy: 0).tap()
        app.buttons["Fertig"].tap()

        XCTAssertTrue(image.waitForExistence(timeout: 3))
        let swapped = NSPredicate(format: "value IN %@", ["asset-4", "asset-5", "asset-6"])
        expectation(for: swapped, evaluatedWith: image)
        waitForExpectations(timeout: 5)
    }

    /// A source can be added and removed; after a swipe-delete its row is gone.
    @MainActor
    func testAddAndRemoveSource() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest", "--uitest-slideshow", "--uitest-chrome"]
        app.launch()

        let image = app.descendants(matching: .any).matching(identifier: "slideshow.image").firstMatch
        XCTAssertTrue(image.waitForExistence(timeout: 5))

        openSources(in: app)
        addAlbum(named: "Urlaub 2026", in: app)

        let newRow = app.buttons["Urlaub 2026"]
        XCTAssertTrue(newRow.waitForExistence(timeout: 3))

        // Swipe-delete the just-added (non-active) source.
        newRow.swipeLeft()
        app.buttons["Delete"].firstMatch.tap()

        XCTAssertFalse(newRow.waitForExistence(timeout: 2), "removed source row should be gone")
        // The seeded source remains.
        XCTAssertTrue(app.buttons["sources.row.src-a1"].exists)
    }

    // MARK: - Helpers

    @MainActor
    private func openSources(in app: XCUIApplication) {
        let settingsButton = app.buttons["slideshow.chrome.settings"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 2))
        settingsButton.tap()

        let sources = app.descendants(matching: .any).matching(identifier: "settings.sources").firstMatch
        XCTAssertTrue(scrollToElement(sources, in: app), "Sources row should be present in settings")
        sources.tap()
    }

    @MainActor
    private func addAlbum(named name: String, in app: XCUIApplication) {
        app.buttons["sources.add"].tap()
        // Album mode is the default; pick the album that becomes the new source.
        let albumButton = app.buttons["sources.album.a2"]
        XCTAssertTrue(albumButton.waitForExistence(timeout: 3), "stub album a2 should be listed")
        albumButton.tap()
        // The add sheet dismisses on success; the new row appears in the manager.
        XCTAssertTrue(app.buttons[name].waitForExistence(timeout: 3))
    }

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
