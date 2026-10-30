//
//  ActionExecutor.swift
//  BarX
//
//  Единая точка исполнения элементов папок/панели/Launcher.
//  Раньше логика открытия была размазана по четырём местам (LauncherManager,
//  FoldersAndItems, PresetsSettingsView, BarXMenuView) и не умела ничего,
//  кроме «открыть приложение/папку/ссылку». Здесь — все типы, включая
//  shell-команды, AppleScript, ярлыки Shortcuts и deep links.
//

import AppKit
import SwiftUI

enum ActionExecutor {

    enum Outcome {
        case success
        /// Ошибка с человекочитаемым объяснением.
        case failure(String)
    }

    /// Результат выполнения внешней команды (shell / Shortcuts).
    struct CommandOutcome {
        let status: Int32
        /// Объединённый stdout + stderr.
        let output: String
        let timedOut: Bool
        var succeeded: Bool { status == 0 && !timedOut }

        static func failure(_ message: String) -> CommandOutcome {
            CommandOutcome(status: -1, output: message, timedOut: false)
        }
    }

    /// Запускает процесс, НЕПРЕРЫВНО читая его вывод (иначе pipe переполняется
    /// на 64 КБ, процесс виснет в записи, а `waitUntilExit` не возвращается —
    /// раньше из-за этого команды «не выполнялись»), и с таймаутом.
    ///
    /// Синхронно ждёт завершения — вызывать ТОЛЬКО из фонового потока,
    /// чтобы не блокировать главный.
    static func runProcess(
        _ executable: String,
        arguments: [String],
        timeout: TimeInterval = 30
    ) -> CommandOutcome {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let pipe = Pipe()
        // stdout и stderr в один поток — читаем всё, что команда напечатала.
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
        } catch {
            return .failure("Не удалось запустить: \(error.localizedDescription)")
        }

        // Чтение в отдельном фоновом потоке до EOF — снимает блокировку записи.
        let handle = pipe.fileHandleForReading
        var collected = Data()
        let readGroup = DispatchGroup()
        readGroup.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            collected = handle.readDataToEndOfFile()
            readGroup.leave()
        }

        // Ожидание завершения с таймаутом.
        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning && Date() < deadline {
            usleep(20_000) // 20 мс
        }

        var timedOut = false
        if process.isRunning {
            timedOut = true
            process.terminate()
            let stop = Date().addingTimeInterval(1)
            while process.isRunning && Date() < stop { usleep(20_000) }
            if process.isRunning { process.interrupt() }
        } else {
            process.waitUntilExit()
        }
        _ = readGroup.wait(timeout: .now() + 2)

        let output = String(data: collected, encoding: .utf8) ?? ""
        if timedOut {
            return CommandOutcome(status: -1, output: output, timedOut: true)
        }
        return CommandOutcome(status: process.terminationStatus, output: output, timedOut: false)
    }

    /// Тестовый запуск действия (Shell / AppleScript) прямо из редактора:
    /// выполняет в фоне и возвращает результат на главном потоке (без алертов —
    /// их рисует сам вид). Позволяет убедиться, что команда работает, ДО сохранения.
    static func testRunAction(
        type: AppItem.ItemType,
        payload: String,
        completion: @escaping (CommandOutcome) -> Void
    ) {
        let trimmed = payload.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            completion(.failure("Пусто — введите команду."))
            return
        }
        DispatchQueue.global(qos: .userInitiated).async {
            let result: CommandOutcome
            switch type {
            case .shell:
                result = runProcess("/bin/zsh", arguments: ["-lc", trimmed])
            case .applescript:
                result = runProcess("/usr/bin/osascript", arguments: ["-e", trimmed])
            default:
                result = .failure("Тестовый запуск доступен только для команд и скриптов.")
            }
            DispatchQueue.main.async { completion(result) }
        }
    }

    /// Исполняет элемент. `confirmed` — подтверждение пользователя для
    /// потенциально опасных действий (shell/AppleScript); при `false` такие
    /// действия спросят подтверждение сами.
    @discardableResult
    static func execute(_ item: AppItem, confirmed: Bool = false) -> Outcome {
        switch item.type {
        case .url:
            return openWebURL(item.path, for: item)
        case .deeplink:
            return openDeepLink(item.path, for: item)
        case .shell:
            return runShell(item.path, for: item, confirmed: confirmed)
        case .applescript:
            return runAppleScript(item.path, for: item, confirmed: confirmed)
        case .shortcut:
            return runShortcut(item.path, for: item)
        case .application:
            return openApplication(item)
        case .folder:
            return openFolder(item)
        case .action:
            // Старый обобщённый тип: раньше тут был просто warning и молчание.
            // Теперь трактуем как deep link/URL, если payload похож на схему.
            return openLegacyAction(item)
        case .section:
            // Заголовок-разделитель — только визуально, запускать нечего.
            return .success
        }
    }

    // MARK: - Ссылки и deep links

    private static func openWebURL(_ string: String, for item: AppItem) -> Outcome {
        guard let url = URL(string: string), url.scheme != nil else {
            return .failure("Некорректный адрес: «\(string)»")
        }
        NSWorkspace.shared.open(url)
        return .success
    }

    private static func openDeepLink(_ string: String, for item: AppItem) -> Outcome {
        guard let url = URL(string: string), let scheme = url.scheme, !scheme.isEmpty else {
            return .failure("Некорректный deep link: «\(string)»")
        }
        // Проверяем, что схему вообще умеет открыть система — иначе получим
        // «нет приложения для открытия» без внятного сообщения.
        guard NSWorkspace.shared.urlForApplication(toOpen: url) != nil else {
            return .failure("Нет приложения, открывающего схему «\(scheme)://» для «\(item.name)».")
        }
        NSWorkspace.shared.open(url)
        return .success
    }

    private static func openLegacyAction(_ item: AppItem) -> Outcome {
        let payload = item.path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !payload.isEmpty else {
            return .failure("У действия «\(item.name)» не задано содержимое.")
        }
        if let url = URL(string: payload), url.scheme != nil {
            NSWorkspace.shared.open(url)
            return .success
        }
        return .failure("Не удалось выполнить действие «\(item.name)».")
    }

    // MARK: - Shell

    private static func runShell(
        _ command: String,
        for item: AppItem,
        confirmed: Bool
    ) -> Outcome {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .failure("Пустая команда в действии «\(item.name)».")
        }

        if !confirmed {
            return requestConfirmation(
                title: "Выполнить команду?",
                message: "Действие «\(item.name)» выполнит shell-команду:\n\n\(trimmed)",
                item: item
            )
        }

        // Неблокирующее выполнение: раньше главный поток висел на semaphore.wait
        // (до 30 с), а вывод читался после завершения — большие ответы переполняли
        // pipe и команда «не выполнялась». Теперь всё в фоне, ошибки — на главном.
        DispatchQueue.global(qos: .userInitiated).async {
            let result = runProcess("/bin/zsh", arguments: ["-lc", trimmed])
            DispatchQueue.main.async {
                if result.timedOut {
                    presentError(
                        "Команда превысила лимит времени (30 с) и остановлена."
                            + (result.output.isEmpty ? "" : "\n\n\(result.output)"),
                        item: item
                    )
                } else if result.status != 0 {
                    let detail = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
                    presentError(
                        detail.isEmpty
                            ? "Команда завершилась с кодом \(result.status)."
                            : detail,
                        item: item
                    )
                }
            }
        }
        return .success
    }

    // MARK: - AppleScript

    private static func runAppleScript(
        _ source: String,
        for item: AppItem,
        confirmed: Bool
    ) -> Outcome {
        let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .failure("Пустой скрипт в действии «\(item.name)».")
        }

        if !confirmed {
            return requestConfirmation(
                title: "Выполнить AppleScript?",
                message: "Действие «\(item.name)» выполнит скрипт:\n\n\(trimmed)",
                item: item
            )
        }

        var error: NSDictionary?
        guard let script = NSAppleScript(source: trimmed) else {
            return .failure("Не удалось разобрать AppleScript действия «\(item.name)».")
        }
        script.executeAndReturnError(&error)
        if let error {
            let message = (error[NSAppleScript.errorMessage] as? String) ?? "неизвестная ошибка"
            return .failure("Ошибка AppleScript: \(message)")
        }
        return .success
    }

    // MARK: - Apple Shortcuts

    private static func runShortcut(_ name: String, for item: AppItem) -> Outcome {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .failure("Не задано имя команды Shortcuts в «\(item.name)».")
        }

        // Неблокирующе, как и shell: выполняем в фоне, ошибки — на главном.
        DispatchQueue.global(qos: .userInitiated).async {
            let result = runProcess("/usr/bin/shortcuts", arguments: ["run", trimmed])
            guard result.status != 0 || result.timedOut else { return }

            let output = result.output
            let message: String
            if output.localizedCaseInsensitiveContains("not found")
                || output.localizedCaseInsensitiveContains("no such") {
                message = "Команда Shortcuts «\(trimmed)» не найдена. Проверьте точное имя."
            } else if result.timedOut {
                message = "Shortcuts превысило лимит времени и остановлено."
            } else {
                let detail = output.trimmingCharacters(in: .whitespacesAndNewlines)
                message = detail.isEmpty
                    ? "Shortcuts завершился с кодом \(result.status)."
                    : detail
            }
            DispatchQueue.main.async { presentError(message, item: item) }
        }
        return .success
    }

    // MARK: - Приложения и папки

    private static func openApplication(_ item: AppItem) -> Outcome {
        guard FileManager.default.fileExists(atPath: item.path) else {
            return .failure("Файл «\(item.path)» не найден. Возможно, приложение удалено или перемещено.")
        }
        let url = URL(fileURLWithPath: item.path)
        let configuration = NSWorkspace.OpenConfiguration()
        // Неблокирующее открытие: раньше тут ждал semaphore.wait() прямо на
        // главном потоке — UI подвисал на время запуска приложения. Ошибку
        // запуска ловим асинхронно и показываем на главном потоке.
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, error in
            guard let error else { return }
            DispatchQueue.main.async {
                presentError("Ошибка запуска: \(error.localizedDescription)", item: item)
            }
        }
        return .success
    }

    private static func openFolder(_ item: AppItem) -> Outcome {
        guard FileManager.default.fileExists(atPath: item.path) else {
            return .failure("Папка «\(item.path)» не найдена.")
        }
        if let bookmarked = FileAccessHelper.shared.getBookmarkedURL(for: item.path) {
            NSWorkspace.shared.open(bookmarked)
        } else {
            FileAccessHelper.shared.requestAccessAndOpen(path: item.path) { _ in }
        }
        return .success
    }

    // MARK: - Подтверждение опасных действий

    private static func requestConfirmation(
        title: String,
        message: String,
        item: AppItem
    ) -> Outcome {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Выполнить")
        alert.addButton(withTitle: "Отмена")
        NSApp.activate()
        guard alert.runModal() == .alertFirstButtonReturn else {
            return .failure("Отменено пользователем.")
        }
        return execute(item, confirmed: true)
    }

    /// Показывает ошибку исполнения единообразно (меню-бар активируем, чтобы
    /// алерт не уходил за окна других приложений).
    static func presentError(_ message: String, item: AppItem) {
        let alert = NSAlert()
        alert.messageText = "Не удалось выполнить «\(item.name)»"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        NSApp.activate()
        alert.runModal()
    }
}
