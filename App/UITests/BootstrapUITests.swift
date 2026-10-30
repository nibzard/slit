import XCTest

final class BootstrapUITests: XCTestCase {
    func testShellNeverOffersAnUnimplementedCapture() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["shutterButton"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["shutterButton"].isEnabled)
        let placeholder = app.descendants(matching: .any)["cameraPlaceholder"]
        XCTAssertTrue(placeholder.waitForExistence(timeout: 5))
    }

    func testGridPreferenceSurvivesRelaunch() {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-grid-for-ui-test"]
        app.launch()
        app.buttons["moreButton"].tap()
        let gridRow = app.switches["gridToggle"]
        XCTAssertTrue(gridRow.waitForExistence(timeout: 5))
        // The identifier attaches to the Form row. The control that holds the
        // on-off state and accepts taps is its inner switch descendant.
        let gridSwitch = gridRow.descendants(matching: .switch).firstMatch
        XCTAssertTrue(gridSwitch.waitForExistence(timeout: 5))
        XCTAssertEqual(gridSwitch.value as? String, "0")
        gridSwitch.tap()
        XCTAssertEqual(gridSwitch.value as? String, "1")
        app.terminate()
        app.launchArguments = []
        app.launch()
        app.buttons["moreButton"].tap()
        XCTAssertTrue(gridSwitch.waitForExistence(timeout: 5))
        XCTAssertEqual(gridSwitch.value as? String, "1")
    }
}
