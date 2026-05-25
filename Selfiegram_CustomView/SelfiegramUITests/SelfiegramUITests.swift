//
//  SelfiegramUITests.swift
//  SelfiegramUITests
//
//  Created by Pham Hoang Minh on 17/5/26.
//

import XCTest

final class SelfiegramUITests: XCTestCase {

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
        // Test to ensure that number of selfies are the same between app lauches
        // tables: list of TableViews in the app
        // boundBy: 0 => TableView 0
        let app = XCUIApplication()
        app.launch()
        let table = app.tables.element(boundBy: 0)
        let currentSelfieCount = table.cells.count
        
        // restart app (virtually)
        app.terminate()
        app.launch()
        
        // compare number of rows from 2 runs
        let newCount = app.tables.element(boundBy: 0).cells.count
        // assert
        XCTAssertEqual(currentSelfieCount, newCount)
        
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
    
    @MainActor
    // Test Selfie capture; will fail as we don't give camera access
    func testPhotos() {
        
        let app = XCUIApplication()
        app.launch()
        
        // handle permission dialog
        addUIInterruptionMonitor(withDescription: "Camera Permission Dialog") {
            (alert) -> Bool in
            alert.buttons["OK"].tap()
            return true
        }
        
        let currentSelfieCount = app.tables.element(boundBy: 0).cells.count
        // start collecting more Selfies
        app.navigationBars["Selfies"].buttons["Add"].tap()
        // get current window, get element inside it i.e. the screen window and "tap" it
        // i.e. capture a new Selfie
        app.children(matching: .window).element(boundBy: 0)
            .children(matching: .other).element.tap()
        // tap the EditView screen's "Done" button
        print(app.debugDescription)

        app.navigationBars["Edit"].buttons["Done"].tap()
        // Assert
        let newSelfieCount = app.tables.element(boundBy: 0).cells.count
        XCTAssertEqual(currentSelfieCount+1, newSelfieCount)
    }
    
    @MainActor
    // Test location display; will fail as we don't give location permission
    func testExistence() {
        let app = XCUIApplication()
        app.launch()
        // select 1st Selfie in the list
        app.tables.element(boundBy: 0).cells.element(boundBy:0).tap()
        let mapView = app.maps.firstMatch
        // Assert
        XCTAssert(mapView.exists)
        XCTAssert(mapView.isHittable)
    }
}
