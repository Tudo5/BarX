//
//  BarXUITestsLaunchTests.swift
//  BarXUITests
//
//  Снимок экрана первого запуска — визуальная регрессия.
//

import XCTest

final class BarXUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        // Ждём первый интерфейс: на чистом прогоне это приветствие
        let welcome = app.staticTexts["Добро пожаловать в BarX"]
        _ = welcome.waitForExistence(timeout: 15)

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
