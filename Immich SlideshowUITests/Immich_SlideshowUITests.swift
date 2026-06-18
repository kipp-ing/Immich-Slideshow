//
//  Immich_SlideshowUITests.swift
//  Immich SlideshowUITests
//
//  Created by Jan Kipping on 17.06.26.
//

import XCTest

final class Immich_SlideshowUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // XCUIAutomation Documentation
        // https://developer.apple.com/documentation/xcuiautomation
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
