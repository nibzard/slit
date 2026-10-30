// ABOUTME: Shell UI tests: honest camera states without a real camera, and grid preference persistence.
// ABOUTME: Simulator runs cannot prove capture; they verify states, controls, and stability only.

import XCTest

final class BootstrapUITests: XCTestCase {
    func testShellShowsHonestStateWithoutACamera() {
        let app = XCUIApplication()
        let permissionDialog = addUIInterruptionMonitor(withDescription: "camera permission") { interaction in
            let allow = interaction.buttons.matching(NSPredicate(format: "label LIKE '*Allow*'")).firstMatch
            if allow.exists { allow.tap(); return true }
            return false
        }
        app.launch()
        app.buttons["shutterButton"].tap() // Drives the interruption monitor on the permission dialog.
        let placeholder = app.descendants(matching: .any)["cameraPlaceholder"]
        XCTAssertTrue(placeholder.waitForExistence(timeout: 10), "A camera-less host must show an honest placeholder, never a fake preview")
        XCTAssertTrue(app.buttons["shutterButton"].exists)
        XCTAssertFalse(app.buttons["shutterButton"].isEnabled, "The shutter must stay disabled while no camera is ready")
        removeUIInterruptionMonitor(permissionDialog)
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
