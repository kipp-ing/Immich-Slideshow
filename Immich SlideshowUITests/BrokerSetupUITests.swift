//
//  BrokerSetupUITests.swift
//  Immich SlideshowUITests
//
//  Feature 006 / US2 (T016): the broker-setup sheet shows existing data so it can
//  be changed or removed, without ever prefilling the password in cleartext.
//  Driven hermetically via an in-memory broker store seeded by `--uitest-broker-existing`.
//

import XCTest

final class BrokerSetupUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testExistingBrokerPrefillsFieldsMasksPasswordAndRemoves() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "--uitest", "--uitest-slideshow", "--uitest-chrome",
            "--uitest-broker", "--uitest-broker-existing",
        ]
        app.launch()

        // Host / port / username are prefilled from the stored broker so the user can
        // edit them (FR-007 change flow).
        let host = app.textFields["broker.host"]
        XCTAssertTrue(host.waitForExistence(timeout: 5), "broker setup should open with existing data")
        XCTAssertEqual(host.value as? String, "mqtt.example.com")
        XCTAssertEqual(app.textFields["broker.port"].value as? String, "8883")
        XCTAssertEqual(app.textFields["broker.username"].value as? String, "ha-user")

        // The stored password is never prefilled in cleartext; a "set" hint stands in
        // for it instead (FR-009).
        let passwordHint = app.staticTexts["broker.passwordHint"]
        XCTAssertTrue(passwordHint.exists, "a 'password is set' hint should replace cleartext prefill")
        let password = app.secureTextFields["broker.password"]
        XCTAssertTrue(password.exists)
        XCTAssertNotEqual(password.value as? String, "secret-pass", "password must not be prefilled")

        // Remove clears the stored config and returns to the slideshow (FR-008).
        let remove = app.buttons["broker.remove"]
        XCTAssertTrue(remove.exists, "existing broker data should offer a remove action")
        remove.tap()

        let image = app.descendants(matching: .any)
            .matching(identifier: "slideshow.image").firstMatch
        XCTAssertTrue(image.waitForExistence(timeout: 3), "removing should dismiss back to the slideshow")
        XCTAssertFalse(host.exists, "broker sheet should be gone after removal")
    }
}
