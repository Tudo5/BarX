//
//  BarXUITests.swift
//  BarXUITests
//
//  Сценарии первого запуска.
//
//  BarX — приложение строки меню, у него нет главного окна, поэтому
//  типовой шаблон (просто `app.launch()`) здесь бессмыслен. Проверяем то,
//  что действительно важно: приложение стартует и показывает приветствие,
//  ведь тестовый прогон всегда идёт «с чистой страницы».
//

import XCTest

final class BarXUITests: XCTestCase {

    override func setUpWithError() throws {
        // Останавливаемся сразу при первой ошибке
        continueAfterFailure = false
    }

    /// Первый запуск обязан показывать приветствие с выбором приложений и темы.
    ///
    /// Это ключевой сценарий: раньше приложение открывалось в пустое состояние,
    /// и пользователь не понимал, зачем оно нужно.
    @MainActor
    func testFirstRunShowsOnboarding() throws {
        let app = XCUIApplication()
        app.launch()

        let title = app.staticTexts["Добро пожаловать в BarX"]
        XCTAssertTrue(
            title.waitForExistence(timeout: 15),
            "На первом запуске должно появляться приветственное окно"
        )

        // Внутри есть переход дальше и объяснение горячей клавиши
        XCTAssertTrue(app.staticTexts["Панель быстрого запуска в строке меню"].exists)
        XCTAssertTrue(app.buttons["Далее"].exists)
    }

    /// Приветствие можно пройти до конца и вернуться к работе.
    @MainActor
    func testOnboardingCanBeCompleted() throws {
        let app = XCUIApplication()
        app.launch()

        let next = app.buttons["Далее"]
        guard next.waitForExistence(timeout: 15) else {
            XCTFail("Приветственное окно не появилось")
            return
        }

        next.tap()   // страница 2 — приложения
        XCTAssertTrue(app.staticTexts["Закрепите первые приложения"].exists)

        next.tap()   // страница 3 — тема
        XCTAssertTrue(app.staticTexts["Выберите оформление"].exists)

        let finish = app.buttons["Начать пользоваться"]
        XCTAssertTrue(finish.waitForExistence(timeout: 5))
        finish.tap()

        // После завершения приветствие закрывается и открывается главное меню
        XCTAssertFalse(
            app.staticTexts["Добро пожаловать в BarX"].waitForExistence(timeout: 5),
            "После прохождения приветствие должно закрыться"
        )
    }

    /// Приложение запускается без падений и отвечает на события.
    @MainActor
    func testApplicationLaunchesWithoutCrashing() throws {
        let app = XCUIApplication()
        app.launch()

        // Даём приложению поработать: сканирование, регистрация горячей клавиши
        let title = app.staticTexts["Добро пожаловать в BarX"]
        XCTAssertTrue(title.waitForExistence(timeout: 15))

        // Утечка процесса проявилась бы как исчезновение приложения
        XCTAssertTrue(app.state == .runningForeground || app.state == .runningBackground)
    }
}
