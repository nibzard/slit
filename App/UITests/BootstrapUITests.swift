import XCTest

final class BootstrapUITests: XCTestCase {
    func testShellNeverOffersAnUnimplementedCapture() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["shutterButton"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["shutterButton"].isEnabled)
        XCTAssertTrue(app.otherElements["cameraPlaceholder"].exists)
    }

    func testGridPreferenceSurvivesRelaunch() {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-grid-for-ui-test"]
        app.launch()
        app.buttons["moreButton"].tap()
        let grid = app.switches["gridToggle"]
        XCTAssertTrue(grid.waitForExistence(timeout: 5))
        XCTAssertEqual(grid.value as? String, "0")
        grid.tap()
        XCTAssertEqual(grid.value as? String, "1")
        app.terminate()
        app.launchArguments = []
        app.launch()
        app.buttons["moreButton"].tap()
        XCTAssertTrue(grid.waitForExistence(timeout: 5))
        XCTAssertEqual(grid.value as? String, "1")
    }
}
