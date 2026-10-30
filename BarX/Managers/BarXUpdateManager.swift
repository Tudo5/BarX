//
//  BarXUpdateManager.swift
//  BarX
//
//  Проверка и установка обновлений — через Sparkle 2.
//
//  Публичный интерфейс (isChecking / checkForUpdates / currentVersionString)
//  сохранён, чтобы не переписывать места вызова в UI. Статические хелперы
//  сравнения версий оставлены для юнит-тестов.
//
//  Конфигурация Sparkle живёт в Info.plist:
//    SUFeedURL         — адрес appcast.xml
//    SUPublicEDKey     — публичный EdDSA-ключ (приватный — в Связке ключей)
//    SUEnableAutomaticChecks / SUAutomaticallyUpdate
//

import SwiftUI
import AppKit
import Combine
import Sparkle

class BarXUpdateManager: ObservableObject {
    static let shared = BarXUpdateManager()

    /// Идёт проверка — кнопки показывают спиннер и блокируются.
    @Published var isChecking = false

    /// Оставлено для совместимости со старым UI: Sparkle показывает своё окно
    /// обновления, поэтому постоянный «бейдж» больше не выставляется.
    @Published var updateAvailable = false
    @Published var updateVersion = ""

    private let controller: SPUStandardUpdaterController
    private var canCheckObservation: NSKeyValueObservation?

    /// Текущая версия приложения (единый источник — Info.plist).
    var currentVersionString: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.5.1"
    }

    var updater: SPUUpdater { controller.updater }

    private init() {
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )

        // Настройка «Автоматически проверять обновления» управляет планировщиком Sparkle.
        controller.updater.automaticallyChecksForUpdates = BarXSettings.autoCheckUpdates

        // `canCheckForUpdates == false`, пока идёт проверка/загрузка обновления.
        // Подписываемся через KVO и переносим в `isChecking` на главном потоке.
        canCheckObservation = controller.updater.observe(
            \.canCheckForUpdates,
            options: [.initial, .new]
        ) { [weak self] updater, _ in
            DispatchQueue.main.async {
                self?.isChecking = !updater.canCheckForUpdates
            }
        }
    }

    /// Запускает проверку обновлений.
    /// - Parameter silentIfNoUpdate: `true` — фоновая проверка без всплывающего
    ///   «у вас последняя версия» (для автопроверки при запуске).
    func checkForUpdates(silentIfNoUpdate: Bool = false) {
        if silentIfNoUpdate {
            controller.updater.checkForUpdatesInBackground()
        } else {
            controller.updater.checkForUpdates()
        }
    }

    // MARK: - Сравнение версий (оставлено для юнит-тестов)

    /// "v1.3.5-beta" → "1.3.5", "release-2.0" → "2.0"
    static func normalizedVersion(_ raw: String) -> String {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("v") || value.hasPrefix("V") {
            value.removeFirst()
        }
        // Отбрасываем префиксы вида "release-" / "beta-"
        if let lastDash = value.lastIndex(of: "-"),
           value[value.startIndex..<lastDash].contains(where: { !$0.isNumber && $0 != "." }) {
            value = String(value[value.index(after: lastDash)...])
        }
        // Убираем суффикс предрелиза: 1.3.5-beta → 1.3.5
        value = value.split(separator: "-").first.map(String.init) ?? value
        // Оставляем только цифры и точки
        value = value.filter { $0.isNumber || $0 == "." }
        return value
    }

    /// Сравнивает версии по числовым компонентам.
    static func isNewerVersion(_ newVersion: String, than oldVersion: String) -> Bool {
        // Если из строки версии не удалось извлечь ни одного числа —
        // считаем, что обновления нет (а не «версия пустая»)
        let newParts = newVersion.split(separator: ".").compactMap { Int($0) }
        let oldParts = oldVersion.split(separator: ".").compactMap { Int($0) }
        guard !newParts.isEmpty, !oldParts.isEmpty else { return false }

        let maxCount = max(newParts.count, oldParts.count)

        for i in 0..<maxCount {
            let newPart = i < newParts.count ? newParts[i] : 0
            let oldPart = i < oldParts.count ? oldParts[i] : 0

            if newPart > oldPart { return true }
            if newPart < oldPart { return false }
        }

        return false
    }
}
