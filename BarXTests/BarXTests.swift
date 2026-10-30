//
//  BarXTests.swift
//  BarXTests
//
//  Юнит-тесты логики, не зависящей от UI.
//
//  Раньше файл был пустой заготовкой с одним несделанным `example()`
//  при 12 000 строк приложения. Здесь покрыто то, что проще всего
//  сломать и что легче всего проверить: разбор клавиш, сравнение версий,
//  идентичность приложений и расчёт размеров панели.
//

import Testing
import SwiftUI
import AppKit
import Carbon.HIToolbox
@testable import BarX

// MARK: - Разбор горячих клавиш

struct KeyCodeHelperTests {

    @Test func parseHotkeySplitsModifiersAndKey() {
        let (modifiers, key) = KeyCodeHelper.parseHotkey("⌘ ⇧ B")
        #expect(modifiers == [.command, .shift])
        #expect(key == "B")
    }

    @Test func parseHotkeyAcceptsFormatWithoutSpaces() {
        // Рекордер и хранилище использовали оба формата
        let (modifiers, key) = KeyCodeHelper.parseHotkey("⌘⇧B")
        #expect(modifiers == [.command, .shift])
        #expect(key == "B")
    }

    @Test func parseHotkeySupportsEveryModifier() {
        let (modifiers, key) = KeyCodeHelper.parseHotkey("⌃ ⌥ ⇧ ⌘ K")
        #expect(modifiers == [.command, .option, .shift, .control])
        #expect(key == "K")
    }

    @Test func normalizeHotkeyProducesCanonicalForm() {
        #expect(KeyCodeHelper.normalizeHotkey("⌘⇧B") == "⌘ ⇧ B")
        #expect(KeyCodeHelper.normalizeHotkey("  ⌘   b ") == "⌘ B")
    }

    @Test func normalizeHotkeyKeepsModifierOrder() {
        // Порядок всегда одинаков: ⌘, ⌥, ⇧, ⌃
        #expect(KeyCodeHelper.normalizeHotkey("⌃ ⇧ ⌘ A") == "⌘ ⇧ ⌃ A")
    }

    @Test func normalizeHotkeyIsIdempotentAndCaseCanonical() {
        // Повторная нормализация ничего не меняет, а буква — всегда заглавная
        let once = KeyCodeHelper.normalizeHotkey("  ⌘   b ")
        #expect(once == "⌘ B")
        #expect(KeyCodeHelper.normalizeHotkey(once) == once)
        #expect(KeyCodeHelper.normalizeHotkey("⌘ B") == "⌘ B")
    }

    @Test func normalizeHotkeyPreservesMultiCharacterKeys() {
        // Space/Return/F-клавиши в верхний регистр не превращаем
        #expect(KeyCodeHelper.normalizeHotkey("⌘space") == "⌘ space")
        #expect(KeyCodeHelper.normalizeHotkey("⌃ F1") == "⌃ F1")
    }

    @Test func normalizeHotkeyRejectsEmptyKey() {
        // Один лишь модификатор не является комбинацией
        #expect(KeyCodeHelper.normalizeHotkey("⌘") == "⌘")
        #expect(KeyCodeHelper.parseHotkey("⌘").1.isEmpty)
    }

    @Test func usableHotkeyRequiresBothParts() {
        #expect(KeyCodeHelper.isUsableHotkey("⌘ ⇧ B"))
        #expect(!KeyCodeHelper.isUsableHotkey("B"))      // нет модификатора
        #expect(!KeyCodeHelper.isUsableHotkey("⌘ ⇧"))   // нет клавиши
        #expect(!KeyCodeHelper.isUsableHotkey(""))
    }

    @Test func keyStringCoversPhysicalModifierKeys() {
        // Каждому физическому keycode — своя клавиша.
        // Регрессия: раньше 61 (Right ⌥) и 62 (Right ⌃) отдавали "⇧".
        #expect(KeyCodeHelper.keyString(for: 54) == "⌘") // Right Command
        #expect(KeyCodeHelper.keyString(for: 55) == "⌘") // Left Command
        #expect(KeyCodeHelper.keyString(for: 56) == "⇧") // Left Shift
        #expect(KeyCodeHelper.keyString(for: 58) == "⌥") // Left Option
        #expect(KeyCodeHelper.keyString(for: 59) == "⌃") // Left Control
        #expect(KeyCodeHelper.keyString(for: 60) == "⇧") // Right Shift
        #expect(KeyCodeHelper.keyString(for: 61) == "⌥") // Right Option
        #expect(KeyCodeHelper.keyString(for: 62) == "⌃") // Right Control
    }

    @Test func keyStringCoversCommonKeysAndFunctions() {
        #expect(KeyCodeHelper.keyString(for: 49) == "Space")
        #expect(KeyCodeHelper.keyString(for: 36) == "Return")
        #expect(KeyCodeHelper.keyString(for: 53) == "Escape")
        #expect(KeyCodeHelper.keyString(for: 11) == "B")
        #expect(KeyCodeHelper.keyString(for: 18) == "1")
        #expect(KeyCodeHelper.keyString(for: 122) == "F1")
        #expect(KeyCodeHelper.keyString(for: 111) == "F12")
        #expect(KeyCodeHelper.keyString(for: 126) == "↑")
    }

    @Test func keyStringReturnsEmptyForUnknownCode() {
        #expect(KeyCodeHelper.keyString(for: 9999) == "")
    }
}

// MARK: - Регистрация горячей клавиши в системе

struct HotkeyRegistrationTests {

    @Test func carbonKeyCodeMapsLettersNumbersAndSymbols() {
        #expect(HotkeyManager.carbonKeyCode(for: "A") == 0)
        #expect(HotkeyManager.carbonKeyCode(for: "B") == 11)
        #expect(HotkeyManager.carbonKeyCode(for: "1") == 18)
        #expect(HotkeyManager.carbonKeyCode(for: "0") == 29)
        #expect(HotkeyManager.carbonKeyCode(for: "Space") == 49)
        #expect(HotkeyManager.carbonKeyCode(for: "/") == 44)
        #expect(HotkeyManager.carbonKeyCode(for: ".") == 47)
    }

    @Test func carbonKeyCodeIsCaseInsensitiveForLetters() {
        #expect(HotkeyManager.carbonKeyCode(for: "a") == HotkeyManager.carbonKeyCode(for: "A"))
        #expect(HotkeyManager.carbonKeyCode(for: "k") == HotkeyManager.carbonKeyCode(for: "K"))
    }

    @Test func carbonKeyCodeReturnsNilForUnknownKey() {
        #expect(HotkeyManager.carbonKeyCode(for: "Ё") == nil)
        #expect(HotkeyManager.carbonKeyCode(for: "Whatever") == nil)
    }

    @Test func carbonModifiersMapEveryFlag() {
        #expect(HotkeyManager.carbonModifiers(from: [.command]) == UInt32(cmdKey))
        #expect(HotkeyManager.carbonModifiers(from: [.shift]) == UInt32(shiftKey))
        #expect(HotkeyManager.carbonModifiers(from: [.option]) == UInt32(optionKey))
        #expect(HotkeyManager.carbonModifiers(from: [.control]) == UInt32(controlKey))
        #expect(HotkeyManager.carbonModifiers(from: []) == 0)
    }

    @Test func carbonModifiersCombinesFlags() {
        let combined = HotkeyManager.carbonModifiers(from: [.command, .shift])
        #expect(combined == UInt32(cmdKey) | UInt32(shiftKey))
    }
}

// MARK: - Сравнение версий

struct VersionComparisonTИests {

    @Test func normalizedVersionStripsPrefixes() {
        #expect(BarXUpdateManager.normalizedVersion("v1.0.2") == "1.0.2")
        #expect(BarXUpdateManager.normalizedVersion("V2.1") == "2.1")
        #expect(BarXUpdateManager.normalizedVersion("release-2.0") == "2.0")
        #expect(BarXUpdateManager.normalizedVersion("1.3.5-beta") == "1.3.5")
    }

    @Test func normalizedVersionKeepsPlainVersions() {
        #expect(BarXUpdateManager.normalizedVersion("1.5.0") == "1.5.0")
    }

    @Test func newerVersionWithMoreComponentsIsDetected() {
        #expect(BarXUpdateManager.isNewerVersion("1.0.1", than: "1.0"))
        #expect(BarXUpdateManager.isNewerVersion("1.1.0", than: "1.0.9"))
        #expect(BarXUpdateManager.isNewerVersion("2.0.0", than: "1.9.9"))
    }

    @Test func equalOrOlderVersionsAreNotNewer() {
        #expect(!BarXUpdateManager.isNewerVersion("1.0.0", than: "1.0.0"))
        #expect(!BarXUpdateManager.isNewerVersion("1.0.0", than: "1.5.0"))
        #expect(!BarXUpdateManager.isNewerVersion("0.9", than: "1.0"))
    }

    @Test func missingComponentsAreTreatedAsZero() {
        #expect(BarXUpdateManager.isNewerVersion("1.0.1", than: "1.0.0.0"))
        #expect(!BarXUpdateManager.isNewerVersion("1.0", than: "1.0.0"))
    }

    @Test func unparsableVersionsNeverReportUpdate() {
        // Пустая или нечисловая версия не должна считаться обновлением
        #expect(!BarXUpdateManager.isNewerVersion("", than: "1.0"))
        #expect(!BarXUpdateManager.isNewerVersion("abc", than: "1.0"))
        #expect(!BarXUpdateManager.isNewerVersion("1.0", than: ""))
    }
}

// MARK: - Идентичность приложений

struct AppIdentityTests {

    private func app(_ path: String, id: UUID = UUID(), name: String = "App") -> AppItem {
        AppItem(name: name, path: path, icon: "app.fill", preset: "Все приложения")
    }

    @Test func appsAreSameWhenPathsMatchIgnoringCase() {
        // UUID при каждом сканировании новый — сравнивать можно только путь
        let scanned = app("/Applications/Safari.app")
        let persisted = app("/applications/safari.app")
        #expect(AppStateManager.isSameApp(scanned, persisted))
    }

    @Test func appsAreDifferentWhenPathsDiffer() {
        #expect(!AppStateManager.isSameApp(app("/Applications/A.app"), app("/Applications/B.app")))
    }

    @Test func emptyPathsFallBackToIdentifier() {
        let id = UUID()
        let first = AppItem(name: "Без пути", path: "", icon: "app.fill", preset: "")
        let second = AppItem(name: "Без пути", path: "", icon: "app.fill", preset: "")
        // Оба пустых пути — сравниваем по id, а у свежесозданных он разный
        #expect(!AppStateManager.isSameApp(first, second))

        var matching = first
        matching.id = id
        var other = second
        other.id = id
        #expect(AppStateManager.isSameApp(matching, other))
    }

    @Test @MainActor func itemDecodesTolerantlyFromPartialData() throws {
        // Старые сохранённые данные без новых полей не должны теряться
        let json = #"{"name":"Safari","path":"/Applications/Safari.app"}"#
        let decoded = try JSONDecoder().decode(AppItem.self, from: Data(json.utf8))
        #expect(decoded.name == "Safari")
        #expect(decoded.type == .application)
        #expect(decoded.launchCount == 0)
        #expect(decoded.icon == "app.fill")
    }

    @Test @MainActor func legacyItemDecodesWithRealIconOn() throws {
        // Старые данные без useRealIcon — показываем настоящую иконку
        let json = #"{"name":"Safari","path":"/Applications/Safari.app","type":"application"}"#
        let decoded = try JSONDecoder().decode(AppItem.self, from: Data(json.utf8))
        #expect(decoded.useRealIcon == true)
    }
}

// MARK: - Настоящая иконка элемента

struct RealIconPreferenceTests {

    @Test func realIconForExistingApplication() {
        // /Applications существует на любой macOS
        let item = AppItem(
            name: "Приложение",
            path: "/Applications",
            icon: "app.fill",
            preset: "",
            type: .application
        )
        #expect(item.prefersRealIcon)
    }

    @Test func realIconForExistingFolder() {
        let item = AppItem(
            name: "Папка",
            path: "/Applications",
            icon: "folder.fill",
            preset: "",
            type: .folder
        )
        #expect(item.prefersRealIcon)
    }

    @Test func urlNeverUsesRealIcon() {
        let item = AppItem(
            name: "Сайт",
            path: "https://example.com",
            icon: "globe",
            preset: "",
            type: .url
        )
        #expect(!item.prefersRealIcon)
    }

    @Test func userDisabledRealIconFallsBackToSymbol() {
        let item = AppItem(
            name: "Приложение",
            path: "/Applications",
            icon: "star.fill",
            preset: "",
            type: .application,
            useRealIcon: false
        )
        #expect(!item.prefersRealIcon)
    }

    @Test func missingPathFallsBackToSymbol() {
        let item = AppItem(
            name: "Пропало",
            path: "/Applications/НетТакогоПриложения.app",
            icon: "app.fill",
            preset: "",
            type: .application
        )
        #expect(!item.prefersRealIcon)
    }

    @Test func emptyPathFallsBackToSymbol() {
        let item = AppItem(name: "Без пути", path: "", icon: "app.fill", preset: "")
        #expect(!item.prefersRealIcon)
    }
}

// MARK: - Типы действий

struct ActionItemTypeTests {

    /// Новые типы декодируются из строки и обратно.
    @Test func actionTypesRoundTripThroughRawValue() {
        let types: [AppItem.ItemType] = [.shell, .applescript, .shortcut, .deeplink]
        for type in types {
            #expect(AppItem.ItemType(rawValue: type.rawValue) == type)
        }
    }

    /// Старые сохранённые данные с type:"action" по-прежнему декодируются.
    @Test func legacyActionTypeStillDecodes() throws {
        let json = #"{"name":"X","path":"https://e.com","type":"action"}"#
        let decoded = try JSONDecoder().decode(AppItem.self, from: Data(json.utf8))
        #expect(decoded.type == .action)
    }

    /// Исполняемые действия — ровно shell/applescript/shortcut/deeplink.
    @Test func executableActionTypesAreExactlyTheActionKinds() {
        let executable = Set(AppItem.ItemType.allCases.filter(\.isExecutableAction))
        #expect(executable == [.shell, .applescript, .shortcut, .deeplink])
    }

    /// Опасные (нужно подтверждение) — только shell и AppleScript.
    @Test func onlyShellAndScriptNeedConfirmation() {
        #expect(AppItem.ItemType.shell.needsExecutionConfirmation)
        #expect(AppItem.ItemType.applescript.needsExecutionConfirmation)
        #expect(!AppItem.ItemType.shortcut.needsExecutionConfirmation)
        #expect(!AppItem.ItemType.deeplink.needsExecutionConfirmation)
    }

    /// У каждого типа есть человекочитаемое имя и иконка по умолчанию.
    @Test func everyTypeHasTitleAndDefaultIcon() {
        for type in AppItem.ItemType.allCases {
            #expect(!type.title.isEmpty, "Пустое имя у типа \(type)")
            #expect(!type.defaultIcon.isEmpty, "Пустая иконка у типа \(type)")
        }
    }

    /// Payload действия берётся из поля path.
    @Test func actionPayloadIsStoredInPath() {
        let item = AppItem(
            name: "Очистить корзину",
            path: "rm -rf ~/.Trash/*",
            icon: "terminal",
            preset: "",
            type: .shell
        )
        #expect(item.actionPayload == "rm -rf ~/.Trash/*")
    }
}

// MARK: - Расчёт панели

struct BarLayoutTests {

    /// В одной строке — максимум 5, а в панели может быть больше (листание).
    @Test func perRowLimitIsFiveAndBelowPanelLimit() {
        #expect(BarXSettings.maxBarAppsPerPage == 5)
        #expect(BarXSettings.maxBarApps > BarXSettings.maxBarAppsPerPage)
        #expect(BarXSettings.defaultBarAppsPerPage <= BarXSettings.maxBarAppsPerPage)
    }

    @Test func iconSizeShrinksAsMoreAppsFitOnPage() {
        let forFew = BarXSettings.maxBarIconSize(perPage: 3, showNames: false)
        let forMany = BarXSettings.maxBarIconSize(perPage: BarXSettings.maxBarAppsPerPage, showNames: false)
        #expect(forMany <= forFew)
    }

    @Test func iconSizeNeverLeavesAllowedRange() {
        for perPage in 1...BarXSettings.maxBarAppsPerPage {
            let size = BarXSettings.maxBarIconSize(perPage: perPage, showNames: false)
            #expect(size >= BarXSettings.barIconSizeRange.lowerBound)
            #expect(size <= BarXSettings.barIconSizeRange.upperBound)
        }
    }

    @Test func iconSizeIsAlwaysEven() {
        // Чётность нужна слайдеру, чтобы значение попадало на шаг
        for perPage in 1...BarXSettings.maxBarAppsPerPage {
            let size = BarXSettings.maxBarIconSize(perPage: perPage, showNames: false)
            #expect(size.truncatingRemainder(dividingBy: 2) == 0)
        }
    }

    @Test func showingNamesLeavesLessRoomForIcon() {
        let withoutNames = BarXSettings.maxBarIconSize(perPage: 4, showNames: false)
        let withNames = BarXSettings.maxBarIconSize(perPage: 4, showNames: true)
        #expect(withNames <= withoutNames)
    }
}

// MARK: - Резервное копирование

struct BackupTests {

    @Test func everyDefaultSettingIsBackedUp() {
        // Каждая настройка обязана попадать в бэкап, иначе после импорта
        // пользователь теряет часть параметров
        let backupKeys = Set(BarXBackup.preferenceKeys)
        for key in BarXSettings.defaultValues.keys {
            #expect(backupKeys.contains(key), "Ключ \(key) не включён в бэкап")
        }
    }

    @Test func userDataKeysAreDeclared() {
        let dataKeys = Set(BarXBackup.dataKeys)
        for key in ["barAppsData", "recentAppsData", "pinnedAppsData",
                    "presetsData", "installedAppsData", "themesData"] {
            #expect(dataKeys.contains(key))
        }
    }

    @Test func importRejectsForeignData() throws {
        #expect(throws: BarXBackupError.self) {
            try BarXBackup.importData(Data("не бэкап".utf8))
        }
    }
}

// MARK: - Темы

struct ThemeTests {

    @Test func themesContainBuiltInDefaults() {
        let manager = ThemeManager()
        #expect(manager.themes.count >= 18)
        #expect(manager.selectedTheme != nil)
    }

    @Test func textColorIsReadableOnLightBackground() {
        let manager = ThemeManager()
        // Светлая сплошная тема раньше получала белый текст — не читалась
        let light = Theme(name: "Светлая", colors: ["#FDE68A"], isGradient: false, textColor: .auto)
        #expect(manager.getTextColor(for: light) == .black)
    }

    @Test func textColorIsReadableOnDarkBackground() {
        let manager = ThemeManager()
        let dark = Theme(name: "Тёмная", colors: ["#1F2937"], isGradient: false, textColor: .auto)
        #expect(manager.getTextColor(for: dark) == .white)
    }

    @Test func explicitTextColorOverridesAutomaticChoice() {
        let manager = ThemeManager()
        let forced = Theme(name: "Принудительная", colors: ["#FFFFFF"],
                           isGradient: false, textColor: .dark)
        #expect(manager.getTextColor(for: forced) == .black)
    }

    @Test func radialGradientNeedsTwoColors() {
        let manager = ThemeManager()
        let single = Theme(name: "Один", colors: ["#FF0000"],
                           isGradient: true, gradientDirection: GradientDirection.radial.rawValue)
        #expect(manager.getRadialGradient(for: single, radius: 200) == nil)
    }
}

// MARK: - Масштабирование значков

struct ImageResizeTests {

    /// Валидное растровое изображение заданного размера.
    private static func makeImage(width: Int, height: Int) -> NSImage {
        let image = NSImage(size: NSSize(width: width, height: height))
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return image }
        rep.size = NSSize(width: width, height: height)
        image.addRepresentation(rep)
        return image
    }

    @Test func resizePreservesAspectRatio() {
        let image = Self.makeImage(width: 100, height: 50)
        let result = image.resized(to: NSSize(width: 26, height: 26))
        // 100×50 вписывается в квадрат 26×26 → 26×13
        #expect(Int(result.size.width.rounded()) == 26)
        #expect(Int(result.size.height.rounded()) == 13)
    }

    /// Иконки обязаны быть чёткими на Retina: в растре пикселей вдвое больше,
    /// чем логических точек. Иначе на экранах Retina картинка растягивается
    /// и выглядит мутной.
    @Test func resizeProducesRetinaResolution() {
        let image = Self.makeImage(width: 128, height: 128)
        let result = image.resized(to: NSSize(width: 24, height: 24))

        // Логический размер — 24 точки
        #expect(Int(result.size.width.rounded()) == 24)
        // А растр — 48 пикселей (Retina 2x)
        let pixelsWide = result.representations
            .compactMap { $0 as? NSBitmapImageRep }
            .map(\.pixelsWide)
        #expect(
            pixelsWide.contains(48),
            "Ожидался растр 48 px (Retina 2x) для 24 точек, получено \(pixelsWide)"
        )
    }

    @Test func resizeHandlesDegenerateSizesWithoutCrashing() {
        let image = Self.makeImage(width: 10, height: 10)
        // Нулевой и отрицательный размеры отбрасываются, картинка не портится
        #expect(image.resized(to: .zero).size == image.size)
        #expect(image.resized(to: NSSize(width: -5, height: -5)).size == image.size)
        #expect(image.resized(to: NSSize(width: 0, height: 12)).size == image.size)
    }

    /// Регрессия краша «больше ~6 приложений — падение».
    ///
    /// `resized` использовал непотокобезопасный `lockFocus`, а его вызывают из
    /// `DispatchQueue.global()` при загрузке значков. Параллельные вызовы дёргали
    /// общий графический контекст и роняли приложение. Здесь гоним много
    /// независимых масштабирований сразу — как при загрузке многих значков.
    @Test func resizeIsSafeUnderHeavyConcurrency() async {
        let iterations = 64

        let sizes: [NSSize] = await withTaskGroup(of: NSSize.self) { group in
            for _ in 0..<iterations {
                group.addTask {
                    // У каждой задачи свой источник — как в приложении:
                    // NSWorkspace отдаёт отдельный NSImage на каждое приложение.
                    let source = Self.makeImage(width: 64, height: 64)
                    return source.resized(to: NSSize(width: 24, height: 24)).size
                }
            }
            var collected: [NSSize] = []
            for await size in group { collected.append(size) }
            return collected
        }

        #expect(sizes.count == iterations)
        #expect(sizes.allSatisfy {
            Int($0.width.rounded()) == 24 && Int($0.height.rounded()) == 24
        }, "Параллельное масштабирование дало неверные размеры — похоже на гонку")
    }
}

// MARK: - Краш главного меню (Auto Layout)

@MainActor
struct MainMenuCrashTests {

    /// Открытие главного меню раньше падало.
    ///
    /// Причина: `sizingOptions = [.preferredContentSize]` заставлял AppKit читать
    /// `preferredContentSize` внутри `updateViewConstraints`, а `.onAppear` меню
    /// в тот же момент подгружал папки/пресеты и сбрасывал граф SwiftUI. AppKit
    /// ловил реентерабельное обновление констрейнтов и падал через
    /// `_crashOnException` в `_postWindowNeedsUpdateConstraints`.
    ///
    /// Тест открывает меню тем же путём, что и кнопка «Главное меню» в настройках,
    /// и прокручивает run loop, чтобы окно успело пройти цикл отрисовки и
    /// раскладки — именно там происходило падение. Если бы краш остался,
    /// процесс упал бы (SIGTRAP) и до `#expect` мы бы не дошли.
    @Test func showMainMenuOpensWithoutAutoLayoutCrash() {
        BarXWindowManager.shared.showMainMenu()

        // Прокручиваем run loop: окно проходит display cycle
        // (updateConstraintsIfNeeded → updateViewConstraints), где был краш.
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))

        let menuWindow = NSApp.windows.first { $0.title == "BarX" }
        #expect(
            menuWindow != nil,
            "Окно главного меню открылось и не упало при раскладке"
        )

        // Проверка обрезки: окно без sizingOptions задаётся один раз через
        // setContentSize(fittingSize). Если после onAppear (папки/пресеты уже
        // подгружены) контенту нужно больше, чем есть окно — меню обрезано.
        // Регрессия отследится падением: desired > actual.
        if let contentView = menuWindow?.contentView {
            let desired = contentView.fittingSize
            let actual = contentView.frame.size
            #expect(
                desired.height <= actual.height + 2.0,
                "Меню обрезано: контенту нужно \(desired.height)pt, окно даёт \(actual.height)pt"
            )
        }

        // Убираем за собой окно, чтобы не влиять на другие тесты.
        BarXWindowManager.shared.closeMainMenuWindow()
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
    }
}

// MARK: - Размер окна «Добавить элемент»

@MainActor
struct AddItemSizeTests {

    /// Окно «Добавить элемент» должно быть подогнано вплотную: содержимое
    /// помещается (не обрезается), но и без большой пустоты внизу. Раньше окно
    /// было 540×660 при кадре вида 500×620 — щели по периметру и ~100 пт
    /// пустого места снизу.
    @Test func addItemWindowIsSnug() {
        let content = AddItemView(presetId: UUID(), onAdded: {})
            .formContent
            .environmentObject(AppStateManager.shared)
        let natural = NSHostingController(rootView: content).view.fittingSize
        let window = AddItemView.windowSize

        // Содержимое помещается в окно — не обрезается снизу и по ширине.
        #expect(
            natural.height <= window.height,
            "Обрезка: содержимому нужно \(natural.height)пт, окно даёт \(window.height)пт"
        )
        #expect(
            natural.width <= window.width,
            "Обрезка по ширине: \(natural.width)пт > \(window.width)пт"
        )

        // Но и без большой пустоты: запас — только слот под плашку дубликата
        // и отступ перед кнопками. Раньше окно было 660 пт при содержимом 556
        // — около 100 пт пустого места внизу.
        let reserve = window.height - natural.height
        #expect(
            reserve <= 60,
            "Пустота внизу \(reserve)пт — слишком много, вернулся старый Spacer"
        )
    }

    /// Худший случай — состояние с многострочным редактором действия (Shell /
    /// AppleScript). Окно обязано вместить и его (иначе скрипт обрежется),
    /// но остаток — только слот под плашку дубликата, без большой пустоты.
    @Test func actionEditorStateFitsWindow() {
        for type: AppItem.ItemType in [.shell, .applescript] {
            let content = AddItemView(presetId: UUID(), onAdded: {}, initialType: type)
                .formContent
                .environmentObject(AppStateManager.shared)
            let natural = NSHostingController(rootView: content).view.fittingSize
            let window = AddItemView.windowSize(for: type)

            #expect(
                natural.height <= window.height,
                "Обрезка (\(type.rawValue)): содержимому нужно \(natural.height)пт, окно даёт \(window.height)пт"
            )
            let reserve = window.height - natural.height
            #expect(
                reserve <= 60,
                "Пустота (\(type.rawValue)) \(reserve)пт — слишком много"
            )
        }
    }

    /// Компактные типы обязаны использовать комппактное окно, а многострочные
    /// редакторы — расширенное (иначе окно либо обрежет скрипт, либо будет пустеть).
    @Test func windowSizeIsTallOnlyForMultilineActions() {
        for type in AppItem.ItemType.allCases {
            let tall = type == .shell || type == .applescript
            let size = AddItemView.windowSize(for: type)
            if tall {
                #expect(size.height == AddItemView.tallWindowHeight, "\(type.rawValue) должен быть высоким")
            } else {
                #expect(size.height == AddItemView.windowSize.height, "\(type.rawValue) должен быть компактным")
            }
        }
    }
}

// MARK: - Библиотека deep links

struct DeepLinkCatalogTests {

    /// Каталог не пуст, у каждого приложения есть схема и хотя бы один шаблон.
    @Test func catalogEntriesAreComplete() {
        #expect(!DeepLinkCatalog.apps.isEmpty)
        for app in DeepLinkCatalog.apps {
            #expect(!app.scheme.isEmpty, "Пустая схема у \(app.app)")
            #expect(!app.examples.isEmpty, "Нет шаблонов у \(app.app)")
            for ex in app.examples {
                #expect(
                    ex.template.contains(app.scheme + "://") || ex.template.contains(app.scheme + ":"),
                    "Шаблон «\(ex.template)» не использует схему \(app.scheme)"
                )
            }
        }
    }

    /// Подстановка значений в плейсхолдеры `{...}`.
    @Test func resolveReplacesPlaceholders() {
        let out = DeepLinkCatalog.resolve(
            "spotify:track:{id}",
            replacements: ["id": "abc123"]
        )
        #expect(out == "spotify:track:abc123")
    }

    /// Плейсхолдеры без значения остаются как есть (не ломают ссылку).
    @Test func resolveLeavesUnknownPlaceholders() {
        let out = DeepLinkCatalog.resolve("tg://resolve?domain={username}", replacements: [:])
        #expect(out == "tg://resolve?domain={username}")
    }
}
