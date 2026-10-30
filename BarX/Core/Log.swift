//
//  Log.swift
//  BarX
//
//  Единая точка логирования.
//
//  Раньше проект был исписан `print("✅ ...")` / `print("━━━")` — мусор в консоли
//  и в отчётах Crash Reporter у реальных пользователей. Здесь всё собрано в одном
//  месте и выключается одной строкой.
//
//  В DEBUG-сборке логи пишутся в консоль. В релизе — только ошибки и события,
//  помеченные как «важные»: обычные пользователи ничего не видят, а при
//  обращении в поддержку можно попросить включить подробный режим.
//

import Foundation
import os.log

enum Log {
    /// Подробность логирования.
    ///
    /// - `errorsOnly`: в релизе по умолчанию. Ошибки и предупреждения.
    /// - `standard`:  события, значимые для отладки (запуск, обновления).
    /// - `verbose`:   всё, включая ход сканирования.
    enum Level: Int, Comparable {
        case errorsOnly = 0
        case standard = 1
        case verbose = 2

        static func < (lhs: Level, rhs: Level) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    /// Текущий порог. Ниже него сообщения не выводятся.
    static var level: Level = {
        #if DEBUG
        return .verbose
        #else
        return .errorsOnly
        #endif
    }()

    /// Технический лог для unified logging (Console.app, логи поддержки).
    /// Он не попадает в stdout и потому безопасен в релизе.
    private static let logger = Logger(subsystem: "com.ilya.BarX", category: "BarX")

    // MARK: - Публичные методы

    /// Ошибка: всегда выводится, независимо от уровня.
    static func error(_ message: String) {
        emit(message, level: .errorsOnly, label: "❌", severity: .error)
    }

    /// Предупреждение: всегда выводится.
    static func warning(_ message: String) {
        emit(message, level: .errorsOnly, label: "⚠️", severity: .default)
    }

    /// Обычное событие: показывается со стандартной и выше подробностью.
    static func info(_ message: String) {
        emit(message, level: .standard, label: "ℹ️", severity: .info)
    }

    /// Подробности хода работы: только с максимальной подробностью.
    static func debug(_ message: String) {
        emit(message, level: .verbose, label: "🔍", severity: .debug)
    }

    /// Успешное завершение операции.
    static func success(_ message: String) {
        emit(message, level: .standard, label: "✅", severity: .info)
    }

    // MARK: - Вывод

    private static func emit(
        _ message: String,
        level required: Level,
        label: String,
        severity: OSLogType
    ) {
        // В unified logging пишем всегда: оно и так фильтруется системой
        // и не засоряет stdout у пользователя.
        logger.log("\(message, privacy: .public)")

        guard level >= required else { return }
        print("\(label) \(message)")
    }
}
