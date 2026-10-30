//
//  Models.swift
//  BarX
//
//  Модели данных: приложение, папка, тема
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers
import Combine
import ServiceManagement
import UserNotifications
import ApplicationServices

// MARK: - Models

struct AppItem: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var path: String
    var icon: String
    /// Показывать настоящую иконку файла (приложения/папки) вместо
    /// выбранного символа. Символ остаётся «запасным» вариантом.
    var useRealIcon: Bool = true
    var preset: String
    var type: ItemType = .application
    var isPinned: Bool = false
    var launchCount: Int = 0
    var lastLaunched: Date?

    enum ItemType: String, Codable, CaseIterable, Identifiable {
        case application
        case folder
        case url
        /// Устаревший обобщённый тип. Оставляем ради совместимости со старыми
        /// сохранёнными данными, но новые элементы создают конкретные типы ниже.
        case action
        case shell
        case applescript
        case shortcut
        case deeplink
        /// Заголовок-разделитель внутри папки. Не запускается — только визуально
        /// группирует элементы; `name` хранит текст заголовка.
        case section

        var id: String { rawValue }

        /// Человекочитаемое имя типа.
        var title: String {
            switch self {
            case .application: return "Приложение"
            case .folder: return "Папка"
            case .url: return "Ссылка"
            case .action: return "Действие"
            case .shell: return "Shell-команда"
            case .applescript: return "AppleScript"
            case .shortcut: return "Команда Shortcuts"
            case .deeplink: return "Deep link"
            case .section: return "Раздел"
            }
        }

        /// Символ по умолчанию для типа.
        var defaultIcon: String {
            switch self {
            case .application: return "app.fill"
            case .folder: return "folder.fill"
            case .url: return "globe"
            case .action: return "bolt.fill"
            case .shell: return "terminal"
            case .applescript: return "doc.text"
            case .shortcut: return "square.grid.2x2"
            case .deeplink: return "link"
            case .section: return "line.3.horizontal"
            }
        }

        /// Типы, которые исполняются как действие (а не «открыть файл»).
        var isExecutableAction: Bool {
            switch self {
            case .shell, .applescript, .shortcut, .deeplink: return true
            default: return false
            }
        }

        /// Типы, которым для запуска нужна подтверждение пользователя
        /// (выполняют произвольный код).
        var needsExecutionConfirmation: Bool {
            switch self {
            case .shell, .applescript: return true
            default: return false
            }
        }

        /// Типы, у которых вместо файлового пути — другой payload
        /// (команда, скрипт, имя шортката, URL-схема).
        var hasNonFilePathPayload: Bool {
            switch self {
            case .shell, .applescript, .shortcut, .deeplink, .url: return true
            default: return false
            }
        }

        /// Заголовок-раздел: не запускается и не требует пути.
        var isSection: Bool { self == .section }

        /// Элементы, для которых обязателен заполненный `path`.
        /// У раздела путь не нужен — его роль выполняет `name`.
        var requiresPath: Bool { self != .section }
    }

    /// Payload действия: для новых типов это `path` (команда/скрипт/имя/URL).
    var actionPayload: String { path }

    /// Брать ли настоящую иконку из файла. Актуально только для приложений
    /// и папок с существующим путём — у ссылок и действий файла нет.
    var prefersRealIcon: Bool {
        guard useRealIcon, type == .application || type == .folder else { return false }
        return !path.isEmpty && FileManager.default.fileExists(atPath: path)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: AppItem, rhs: AppItem) -> Bool {
        lhs.id == rhs.id
    }
    
    /// Декодирование терпимо к отсутствующим полям: старые сохранённые
    /// данные не «теряются» после добавления новых свойств в модель.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? container.decode(UUID.self, forKey: .id)) ?? UUID()
        name = (try? container.decode(String.self, forKey: .name)) ?? "Без названия"
        path = (try? container.decode(String.self, forKey: .path)) ?? ""
        icon = (try? container.decode(String.self, forKey: .icon)) ?? "app.fill"
        // Старые сохранённые элементы без поля показываем настоящей иконкой.
        useRealIcon = (try? container.decode(Bool.self, forKey: .useRealIcon)) ?? true
        preset = (try? container.decode(String.self, forKey: .preset)) ?? "Все приложения"
        type = (try? container.decode(ItemType.self, forKey: .type)) ?? .application
        isPinned = (try? container.decode(Bool.self, forKey: .isPinned)) ?? false
        launchCount = (try? container.decode(Int.self, forKey: .launchCount)) ?? 0
        lastLaunched = try? container.decode(Date.self, forKey: .lastLaunched)
    }
    
    init(
        name: String,
        path: String,
        icon: String,
        preset: String,
        type: ItemType = .application,
        useRealIcon: Bool = true
    ) {
        self.name = name
        self.path = path
        self.icon = icon
        self.preset = preset
        self.type = type
        self.useRealIcon = useRealIcon
    }
}

struct Preset: Identifiable, Codable {
    var id = UUID()
    var name: String
    var icon: String
    var items: [AppItem] = []
    var isFavorite: Bool = false
    
    init(name: String, icon: String, items: [AppItem] = []) {
        self.name = name
        self.icon = icon
        self.items = items
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? container.decode(UUID.self, forKey: .id)) ?? UUID()
        name = (try? container.decode(String.self, forKey: .name)) ?? "Папка"
        icon = (try? container.decode(String.self, forKey: .icon)) ?? "folder"
        items = (try? container.decode([AppItem].self, forKey: .items)) ?? []
        isFavorite = (try? container.decode(Bool.self, forKey: .isFavorite)) ?? false
    }
}

struct Theme: Identifiable, Codable {
    var id = UUID()
    var name: String
    var colors: [String]
    var isGradient: Bool
    var gradientDirection: String?
    var isCustom: Bool = false
    var textColor: TextColor = .auto
    
    enum TextColor: String, Codable, CaseIterable {
        case auto = "Авто"
        case light = "Светлый"
        case dark = "Тёмный"
    }
    
    init(name: String, colors: [String], isGradient: Bool, gradientDirection: String? = nil, isCustom: Bool = false, textColor: TextColor = .auto) {
        self.name = name
        self.colors = colors
        self.isGradient = isGradient
        self.gradientDirection = gradientDirection
        self.isCustom = isCustom
        self.textColor = textColor
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? container.decode(UUID.self, forKey: .id)) ?? UUID()
        name = (try? container.decode(String.self, forKey: .name)) ?? "Тема"
        colors = (try? container.decode([String].self, forKey: .colors)) ?? []
        isGradient = (try? container.decode(Bool.self, forKey: .isGradient)) ?? true
        gradientDirection = try? container.decode(String.self, forKey: .gradientDirection)
        isCustom = (try? container.decode(Bool.self, forKey: .isCustom)) ?? false
        textColor = (try? container.decode(TextColor.self, forKey: .textColor)) ?? .auto
    }
}

enum GradientDirection: String, CaseIterable {
    case horizontal = "Горизонтальный"
    case vertical = "Вертикальный"
    case diagonal = "Диагональный"
    case radial = "Радиальный"
}
