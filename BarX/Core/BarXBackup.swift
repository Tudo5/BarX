//
//  BarXBackup.swift
//  BarX
//
//  Экспорт и импорт настроек
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers
import Combine
import ServiceManagement
import UserNotifications
import ApplicationServices

// MARK: - BarXBackup (экспорт/импорт настроек и данных)

enum BarXBackupError: LocalizedError {
    case invalidFormat

    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "Файл не является резервной копией BarX."
        }
    }
}

enum BarXBackup {
    static let preferenceKeys: [String] = [
        // Первый запуск
        "hasCompletedOnboarding",
        // Основные
        "launchAtLogin", "showDockIcon", "autoCheckUpdates",
        "showAppIcons", "showPresetCount", "hideMenuAfterLaunch",
        "showNotifications", "autoRefreshApps", "autoRefreshInterval",
        // Анимации
        "animationSpeed", "animationProfile", "animationsEnabled",
        "animRespectReduceMotion", "animHoverEnabled", "animAppearEnabled",
        "animTransitionsEnabled", "animPulseEnabled", "animStaggerDelay",
        "animHoverDuration", "animPressDuration", "animStandardDuration", "animSpringResponse",
        // Панель Bar и недавние
        "barAppsPerPage", "barIconSize", "barShowNames", "barShowCounter", "barPanelStyle",
        "maxRecentApps",
        // Launcher
        "launcherEnabled", "launcherHotkeyKey",
        "launcherAtCursor", "launcherShowPanelApps", "launcherShowDetails", "launcherMaxResults",
        "launcherWindowWidth", "launcherWindowHeight", "launcherWindowX", "launcherWindowY",
        "launcherHasPosition",
        // Внешний вид
        "selectedThemeId", "appearanceShowPreview", "appearanceCustomOnly", "appearanceGridColumns",
        "appearanceCardRadius", "appearanceBackgroundOpacity", "appearanceShadow",
        "appearanceAccent", "appearanceTintIcons", "appearanceAnimatedBackground",
        // Приложения
        "appsViewMode", "appsShowPath", "appsSortOrder", "appsConfirmDelete"
    ]

    static let dataKeys: [String] = [
        "barAppsData", "recentAppsData", "pinnedAppsData", "presetsData",
        "installedAppsData", "themesData", "customColorsData", "customThemeIds"
    ]

    /// Динамические ключи закладок (`bookmark_<путь>`): FileAccessHelper пишет
    /// их под именем, включающим путь, поэтому заранее перечислить нельзя.
    private static let bookmarkKeyPrefix = "bookmark_"

    static var allKeys: [String] { preferenceKeys + dataKeys }

    static var suggestedFileName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return "BarX-Backup-\(formatter.string(from: Date())).barxbackup"
    }

    /// Все закладки доступа к папкам.
    ///
    /// Раньше закладки в бэкап не попадали: после импорта на другой машине
    /// папки требовали доступ заново, потому что сохранённые ранее
    /// разрешения терялись.
    private static func bookmarkKeys(in store: UserDefaults) -> [String] {
        store.dictionaryRepresentation().keys.filter { $0.hasPrefix(bookmarkKeyPrefix) }
    }

    static func exportData() throws -> Data {
        var payload: [String: Any] = [
            "__barx_backup": true,
            "__barx_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0",
            "__barx_date": Date()
        ]

        let store = UserDefaults.standard
        for key in allKeys + bookmarkKeys(in: store) {
            if let value = store.object(forKey: key) {
                payload[key] = value
            }
        }

        return try PropertyListSerialization.data(fromPropertyList: payload, format: .xml, options: 0)
    }

    /// Возвращает количество применённых ключей.
    @discardableResult
    static func importData(_ data: Data) throws -> Int {
        guard let payload = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let dictionary = payload as? [String: Any] else {
            throw BarXBackupError.invalidFormat
        }

        let store = UserDefaults.standard
        var applied = 0
        for (key, value) in dictionary
        where allKeys.contains(key) || key.hasPrefix(bookmarkKeyPrefix) {
            store.set(value, forKey: key)
            applied += 1
        }
        store.synchronize()
        return applied
    }

    /// Удаляет все данные, включая закладки доступа к папкам.
    ///
    /// Общая точка для «Удалить все данные»: раньше закладки оставались
    /// висеть в UserDefaults, хотя папки, ради которых они создавались,
    /// были удалены.
    static func eraseAllData() {
        let store = UserDefaults.standard
        for key in dataKeys + bookmarkKeys(in: store) {
            store.removeObject(forKey: key)
        }
        store.synchronize()
    }
}
