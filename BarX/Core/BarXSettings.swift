//
//  BarXSettings.swift
//  BarX
//
//  Настройки приложения, автозапуск, разрешения, окружение
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers
import Combine
import ServiceManagement
import UserNotifications
import ApplicationServices

// MARK: - BarXSettings
// Единый источник правды для всех настроек раздела «Основные».
// Значения по умолчанию регистрируются в UserDefaults, поэтому их видят
// и @AppStorage в SwiftUI, и обычный код (AppStateManager, LauncherManager).

enum BarXSettings {
    static let defaultValues: [String: Any] = [
        // Запуск
        "launchAtLogin": false,
        "showDockIcon": false,
        "autoCheckUpdates": true,
        // Общие
        "showAppIcons": true,
        "showPresetCount": true,
        // Меню скрывается сразу после запуска приложения — иначе панель
        // остаётся открытой поверх экрана и перекрывает то, что запустил.
        "hideMenuAfterLaunch": true,
        // Системные уведомления («Приложение запущено», «Доступно обновление»).
        // Флаг единый и гасит ВСЕ уведомления сразу — включаем по умолчанию,
        // иначе пропадают и уведомления об обновлениях тоже.
        "showNotifications": true,
        "autoRefreshApps": true,
        "autoRefreshInterval": 30.0,
        // Анимации
        "animationSpeed": 0.3,
        "animationProfile": BarXAnimationProfile.smooth.rawValue,
        "animationsEnabled": true,
        "animRespectReduceMotion": true,
        "animHoverEnabled": true,
        "animAppearEnabled": true,
        "animTransitionsEnabled": true,
        "animPulseEnabled": true,
        "animStaggerDelay": 0.03,
        "animHoverDuration": 0.12,
        "animPressDuration": 0.08,
        "animStandardDuration": 0.22,
        "animSpringResponse": 0.28,
        // Панель Bar
        "barAppsPerPage": 5,
        "barIconSize": 36.0,
        "barShowNames": false,
        "barShowCounter": true,
        "barPanelStyle": "icons",
        // Недавние
        "maxRecentApps": 10,
        // Launcher
        // Ключи launcherEnabled/launcherHotkeyKey обязаны быть в дефолтах:
        // иначе «Сбросить настройки» их не трогал, хотя сообщение обещало
        // возврат раздела Launcher к исходному состоянию.
        "launcherEnabled": true,
        "launcherHotkeyKey": "⌘ ⇧ B",
        "launcherAtCursor": false,
        "launcherShowPanelApps": true,
        "launcherShowDetails": true,
        "launcherMaxResults": 40,
        // Внешний вид
        "selectedThemeId": "",
        "appearanceShowPreview": true,
        "appearanceCustomOnly": false,
        "appearanceCardRadius": 10.0,
        "appearanceBackgroundOpacity": 0.95,
        "appearanceShadow": 0.45,
        "appearanceAccent": "#8B5CF6",
        "appearanceGridColumns": 4,
        "appearanceTintIcons": true,
        "appearanceAnimatedBackground": true,
        // Приложения
        "appsViewMode": "list",
        "appsShowPath": true,
        "appsSortOrder": "name",
        "appsConfirmDelete": true
    ]

    private static let registerOnce: Void = {
        UserDefaults.standard.register(defaults: BarXSettings.defaultValues)
    }()

    private static var store: UserDefaults {
        registerDefaults()
        return UserDefaults.standard
    }
    
    /// Явная регистрация значений по умолчанию (вызывается при старте приложения).
    static func registerDefaults() {
        _ = registerOnce
    }

    // MARK: Лимиты панели Bar

    /// Максимум приложений во всей панели. Их может быть больше, чем помещается
    /// в одну строку — лишние уезжают на следующую страницу (листание).
    static let maxBarApps = 10

    /// Максимум приложений в ОДНОЙ строке (на одной странице значков).
    ///
    /// Столько значков гарантированно помещается по центру строки панели.
    /// Отдельная константа от `maxBarApps`: в панели может быть больше приложений,
    /// но в одну строку кладём не больше этого числа.
    static let maxBarAppsPerPage = 5

    /// Значений на страницу по умолчанию.
    static let defaultBarAppsPerPage = 5

    /// Допустимый диапазон размера значка панели.
    static let barIconSizeRange: ClosedRange<Double> = 24...56

    /// Верхняя граница размера значка для заданного числа приложений на странице.
    /// Ряд из `perPage` значков вместе со стрелками листания должен помещаться
    /// в ширину меню BarX (340 pt), иначе значки не встают по центру.
    static func maxBarIconSize(perPage: Int, showNames: Bool) -> Double {
        // В строку не бывает больше `maxBarAppsPerPage` — считаем по нему.
        let count = Double(max(1, min(perPage, maxBarAppsPerPage)))
        // Ширина меню (340) минус горизонтальные отступы секции (8×2)
        // и внутренние отступы ряда (4×2).
        var usable = 340.0 - 16.0 - 8.0
        // Стрелки листания занимают место, только если страниц может быть больше
        // одной (в панели приложений больше, чем помещается в строку).
        if perPage < maxBarApps { usable -= 48.0 }
        // Расстояния между значками.
        usable -= 8.0 * (count - 1)

        let itemWidth = usable / count
        // Плитка занимает size+8, подпись — size+14 (шире на 6 pt).
        let icon = showNames ? itemWidth - 14 : itemWidth - 8
        let capped = min(barIconSizeRange.upperBound, icon)
        let clamped = max(barIconSizeRange.lowerBound, capped)
        return (clamped / 2).rounded(.down) * 2 // чётное значение под шаг слайдера
    }

    // MARK: Чтение

    static var launchAtLogin: Bool { store.bool(forKey: "launchAtLogin") }
    static var showDockIcon: Bool { store.bool(forKey: "showDockIcon") }
    static var autoCheckUpdates: Bool { store.bool(forKey: "autoCheckUpdates") }
    static var showAppIcons: Bool { store.bool(forKey: "showAppIcons") }
    static var showPresetCount: Bool { store.bool(forKey: "showPresetCount") }
    static var hideMenuAfterLaunch: Bool { store.bool(forKey: "hideMenuAfterLaunch") }
    static var showNotifications: Bool { store.bool(forKey: "showNotifications") }
    static var launcherAtCursor: Bool { store.bool(forKey: "launcherAtCursor") }
    static var launcherShowPanelApps: Bool { store.bool(forKey: "launcherShowPanelApps") }
    static var autoRefreshApps: Bool { store.bool(forKey: "autoRefreshApps") }

    static var animationSpeed: Double {
        let value = store.double(forKey: "animationSpeed")
        return value > 0 ? value : 0.3
    }

    static var barAppsPerPage: Int {
        let value = store.integer(forKey: "barAppsPerPage")
        guard value > 0 else { return defaultBarAppsPerPage }
        // В строку не бывает больше `maxBarAppsPerPage` — старые значения обрезаем.
        return min(value, maxBarAppsPerPage)
    }

    static var maxRecentApps: Int {
        let value = store.integer(forKey: "maxRecentApps")
        return value > 0 ? value : 10
    }

    static var autoRefreshIntervalMinutes: Double {
        let value = store.double(forKey: "autoRefreshInterval")
        return value > 0 ? value : 30
    }

    /// Дефолтное значение для конкретного ключа (для сброса).
    static func defaultValue(for key: String) -> Any? {
        defaultValues[key]
    }

    // MARK: Анимации
    // Все анимации приложения идут через AnimationCenter, поэтому профиль
    // и скорость меняются в одном месте и действуют сразу везде.

    static var easeInOut: Animation { AnimationCenter.shared.standard }
    static var quick: Animation { AnimationCenter.shared.hover }
    static var spring: Animation { AnimationCenter.shared.spring }
    static var bouncy: Animation { AnimationCenter.shared.bouncy }
    /// Для перестроения списков: без пружины, чтобы не «дёргалось».
    static var layout: Animation { AnimationCenter.shared.layout }

    // MARK: Значения для менеджеров (читаются вне SwiftUI)

    static var barIconSize: Double {
        let value = store.double(forKey: "barIconSize")
        guard value > 0 else { return 36 }
        // Значок крупнее предела не рисуем — иначе ряд не помещается по центру.
        return min(value, maxBarIconSize(perPage: barAppsPerPage, showNames: barShowNames))
    }

    static var barShowNames: Bool { store.bool(forKey: "barShowNames") }
    static var barShowCounter: Bool { store.bool(forKey: "barShowCounter") }
    static var barPanelStyle: String { store.string(forKey: "barPanelStyle") ?? "icons" }

    static var launcherShowDetails: Bool { store.bool(forKey: "launcherShowDetails") }

    static var launcherMaxResults: Int {
        let value = store.integer(forKey: "launcherMaxResults")
        return value > 0 ? value : 40
    }

    static var appearanceAccent: String { store.string(forKey: "appearanceAccent") ?? "#8B5CF6" }

    static var appearanceBackgroundOpacity: Double {
        let value = store.double(forKey: "appearanceBackgroundOpacity")
        return value > 0 ? value : 0.95
    }

    static var appearanceCardRadius: Double {
        let value = store.double(forKey: "appearanceCardRadius")
        return value > 0 ? value : 10
    }

    // MARK: Сброс только настроек (данные пользователя не трогаем)

    static func resetToDefaults() {
        let store = UserDefaults.standard
        for key in defaultValues.keys {
            store.removeObject(forKey: key)
        }
        store.synchronize()
    }
}

// MARK: - LoginItemManager (запуск вместе с macOS)

enum LoginItemManager {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static var statusDescription: String {
        switch SMAppService.mainApp.status {
        case .enabled: return "Включён"
        case .notRegistered: return "Выключен"
        case .notFound: return "Требуется переустановка BarX"
        case .requiresApproval: return "Требуется разрешение в «Системных настройках»"
        @unknown default: return "Неизвестно"
        }
    }

    /// Включает/выключает автозапуск. Бросает ошибку, если система отказала.
    static func setEnabled(_ enabled: Bool) throws {
        let service = SMAppService.mainApp
        if enabled {
            guard service.status != .enabled else { return }
            try service.register()
        } else {
            guard service.status == .enabled else { return }
            try service.unregister()
        }
    }
}

// MARK: - AccessibilityPermission
//
// Горячая клавиша теперь регистрируется через Carbon RegisterEventHotKey,
// которому разрешение «Универсальный доступ» не требуется. Оставляем вспомогательный
// API на случай, если появится функция, реально требующая доступности
// (например, управление фокусом в других приложениях).

enum AccessibilityPermission {
    static var isGranted: Bool { AXIsProcessTrusted() }

    static func request() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    static func openSystemSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }
}

// MARK: - AppEnvironment (применение системных настроек)

enum AppEnvironment {
    /// Показывать ли иконку BarX в Dock.
    static func applyDockIconSetting() {
        NSApplication.shared.setActivationPolicy(BarXSettings.showDockIcon ? .regular : .accessory)
    }

    /// Полная перезагрузка состояния приложения после импорта настроек.
    static func reloadEverything() {
        AppStateManager.shared.loadAllState()
        ThemeManager.shared.reloadThemes()
        applyDockIconSetting()
        LauncherManager.shared.restartHotkeys()
        NotificationHelper.shared.requestAuthorizationIfNeeded()
        postReloadNotifications()
    }

    private static func postReloadNotifications() {
        NotificationCenter.default.post(name: .presetsDidChange, object: nil)
        NotificationCenter.default.post(name: .barItemsDidChange, object: nil)
        NotificationCenter.default.post(name: .themeDidChange, object: nil)
    }
}
