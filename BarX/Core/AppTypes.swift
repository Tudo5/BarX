//
//  AppTypes.swift
//  BarX
//
//  Категории настроек и доступ к файлам
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers
import Combine
import ServiceManagement
import UserNotifications
import ApplicationServices

// MARK: - SettingsCategory

enum SettingsCategory: String, CaseIterable, Hashable {
    case general = "Основные"
    case appearance = "Внешний вид"
    case animations = "Анимации"
    case apps = "Приложения"
    case bar = "Панель Bar"
    case presets = "Папки"
    case launcher = "Launcher"
    case about = "О программе"

    var icon: String {
        switch self {
        case .general:
            return "gearshape"
        case .appearance:
            return "paintbrush"
        case .animations:
            return "sparkles"
        case .apps:
            return "app.badge"
        case .bar:
            return "menubar.rectangle"
        case .presets:
            return "folder"
        case .launcher:
            return "magnifyingglass"
        case .about:
            return "info.circle"
        }
    }

    /// Короткое пояснение для поиска по настройкам.
    var keywords: String {
        switch self {
        case .general: return "запуск, автозапуск, уведомления, обновления, данные"
        case .appearance: return "темы, цвета, градиенты, оформление, предпросмотр"
        case .animations: return "анимации, скорость, переходы, появление, пружина"
        case .apps: return "приложения, поиск, сортировка, сетка, список"
        case .bar: return "панель, значки, порядок, размер"
        case .presets: return "папки, элементы, наборы"
        case .launcher: return "launcher, поиск, горячая клавиша"
        case .about: return "версия, о программе, контакты"
        }
    }
}

// MARK: - FileAccessHelper

class FileAccessHelper {
    static let shared = FileAccessHelper()
    private let defaults = UserDefaults.standard
    
    func saveBookmark(for url: URL) {
        do {
            let bookmarkData = try url.bookmarkData(
                options: .minimalBookmark,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            defaults.set(bookmarkData, forKey: "bookmark_\(url.path)")
            defaults.synchronize()
        } catch {
            Log.error("Не удалось сохранить закладку для \(url.path): \(error.localizedDescription)")
        }
    }
    
    func getBookmarkedURL(for path: String) -> URL? {
        guard let bookmarkData = defaults.data(forKey: "bookmark_\(path)") else {
            return nil
        }
        
        do {
            var isStale = false
            let url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: .withoutUI,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            if !isStale {
                return url
            }
        } catch {
            Log.warning("Не удалось восстановить закладку для \(path): \(error.localizedDescription)")
        }
        return nil
    }
    
    func requestAccessAndOpen(path: String, completion: @escaping (Bool) -> Void) {
        let openPanel = NSOpenPanel()
        openPanel.title = "Разрешить доступ к папке"
        openPanel.message = "BarX запрашивает доступ к папке\n\(path)"
        openPanel.prompt = "Разрешить"
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.allowsMultipleSelection = false
        
        let url = URL(fileURLWithPath: path)
        if FileManager.default.fileExists(atPath: path) {
            openPanel.directoryURL = url
        }
        
        openPanel.begin { response in
            if response == .OK, let selectedURL = openPanel.url {
                self.saveBookmark(for: selectedURL)
                NSWorkspace.shared.open(selectedURL)
                completion(true)
            } else {
                completion(false)
            }
        }
    }
}
