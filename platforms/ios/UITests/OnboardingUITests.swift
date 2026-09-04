import XCTest

final class OnboardingUITests: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  @MainActor
  func testOnboardingExposesEnablementPathAndTryoutField() {
    let app = XCUIApplication()
    app.launch()

    XCTAssertTrue(app.staticTexts["水杉输入法"].waitForExistence(timeout: 10))
    XCTAssertTrue(app.buttons["openKeyboardSettingsButton"].exists)

    let schemePicker = app.segmentedControls["inputSchemePicker"]
    XCTAssertTrue(schemePicker.exists)
    XCTAssertTrue(schemePicker.buttons["全拼"].exists)
    XCTAssertTrue(schemePicker.buttons["小鹤双拼"].exists)

    let tryoutField = app.textFields["keyboardTryoutField"]
    XCTAssertTrue(tryoutField.exists)
    tryoutField.tap()
    tryoutField.typeText("test")
    XCTAssertEqual(tryoutField.value as? String, "test")
  }
}
