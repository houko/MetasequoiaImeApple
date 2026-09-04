import XCTest

final class OnboardingUITests: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  func testOnboardingExposesEnablementPathAndTryoutField() {
    let app = XCUIApplication()
    app.launch()

    XCTAssertTrue(app.staticTexts["水杉输入法"].waitForExistence(timeout: 10))
    XCTAssertTrue(app.buttons["openKeyboardSettingsButton"].exists)

    let tryoutField = app.textFields["keyboardTryoutField"]
    XCTAssertTrue(tryoutField.exists)
    tryoutField.tap()
    tryoutField.typeText("test")
    XCTAssertEqual(tryoutField.value as? String, "test")
  }
}
