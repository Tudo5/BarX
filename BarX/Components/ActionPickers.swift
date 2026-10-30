//
//  ActionPickers.swift
//  BarX
//
//  Редакторы-шторки для действий: библиотека deep links (словарь URL-схем
//  популярных приложений) и выбор установленной команды Apple Shortcuts.
//

import SwiftUI
import AppKit

// MARK: - Deep link: модель каталога

struct DeepLinkExample: Identifiable, Hashable {
    let id = UUID()
    let label: String
    /// Шаблон ссылки. `{...}` — плейсхолдер, который пользователь заменяет.
    let template: String
}

struct DeepLinkApp: Identifiable, Hashable {
    let id = UUID()
    let app: String
    let icon: String
    let scheme: String
    let examples: [DeepLinkExample]
}

// MARK: - Каталог deep links

/// Словарь URL-схем популярных приложений. Шаблоны — отправная точка:
/// пользователь вставляет их и подставляет свои значения (ID, поиск и т.п.).
enum DeepLinkCatalog {
    static let apps: [DeepLinkApp] = [
        DeepLinkApp(app: "Spotify", icon: "music.note", scheme: "spotify", examples: [
            DeepLinkExample(label: "Главная", template: "spotify:"),
            DeepLinkExample(label: "Открыть трек", template: "spotify:track:{id}"),
            DeepLinkExample(label: "Открыть плейлист", template: "spotify:playlist:{id}"),
            DeepLinkExample(label: "Поиск", template: "spotify:search:{query}"),
            DeepLinkExample(label: "Моя музыка", template: "spotify:collection:tracks")
        ]),
        DeepLinkApp(app: "Apple Music", icon: "music.note.list", scheme: "music", examples: [
            DeepLinkExample(label: "Библиотека", template: "music://library"),
            DeepLinkExample(label: "Плейлист", template: "music://playlist/{id}")
        ]),
        DeepLinkApp(app: "YouTube", icon: "play.rectangle.fill", scheme: "youtube", examples: [
            DeepLinkExample(label: "Главная", template: "youtube://"),
            DeepLinkExample(label: "Видео", template: "youtube://watch?v={id}")
        ]),
        DeepLinkApp(app: "Netflix", icon: "film.fill", scheme: "nflx", examples: [
            DeepLinkExample(label: "Главная", template: "nflx://"),
            DeepLinkExample(label: "Видео", template: "nflx://title/{id}")
        ]),
        DeepLinkApp(app: "Telegram", icon: "paperplane.fill", scheme: "tg", examples: [
            DeepLinkExample(label: "Написать", template: "tg://resolve?domain={username}"),
            DeepLinkExample(label: "Сообщение", template: "tg://msg?text={text}")
        ]),
        DeepLinkApp(app: "Slack", icon: "number.square.fill", scheme: "slack", examples: [
            DeepLinkExample(label: "Открыть команду", template: "slack://open?team={id}"),
            DeepLinkExample(label: "Канал", template: "slack://channel?team={id}&id={channel}")
        ]),
        DeepLinkApp(app: "Discord", icon: "bubble.left.and.bubble.right.fill", scheme: "discord", examples: [
            DeepLinkExample(label: "Открыть", template: "discord://"),
            DeepLinkExample(label: "Сервер", template: "discord://-/channels/{guild}/{channel}")
        ]),
        DeepLinkApp(app: "Zoom", icon: "video.fill", scheme: "zoommtg", examples: [
            DeepLinkExample(label: "Войти в встречу", template: "zoommtg://zoom.us/join?confno={id}"),
            DeepLinkExample(label: "Начать", template: "zoommtg://zoom.us/start?confno={id}")
        ]),
        DeepLinkApp(app: "Notion", icon: "square.grid.2x2.fill", scheme: "notion", examples: [
            DeepLinkExample(label: "Главная", template: "notion://"),
            DeepLinkExample(label: "Страница", template: "notion://www.notion.so/{page}")
        ]),
        DeepLinkApp(app: "Obsidian", icon: "book.closed.fill", scheme: "obsidian", examples: [
            DeepLinkExample(label: "Открыть хранилище", template: "obsidian://open?vault={vault}"),
            DeepLinkExample(label: "Заметка", template: "obsidian://open?vault={vault}&file={file}")
        ]),
        DeepLinkApp(app: "Figma", icon: "square.on.square.fill", scheme: "figma", examples: [
            DeepLinkExample(label: "Файл", template: "figma://file/{id}")
        ]),
        DeepLinkApp(app: "GitHub", icon: "chevron.left.forwardslash.chevron.right", scheme: "github", examples: [
            DeepLinkExample(label: "Приложение", template: "github://"),
            DeepLinkExample(label: "Репозиторий", template: "github://{owner}/{repo}")
        ]),
        DeepLinkApp(app: "Google Chrome", icon: "globe", scheme: "googlechrome", examples: [
            DeepLinkExample(label: "Открыть URL", template: "googlechrome://{url}"),
            DeepLinkExample(label: "Новый tab", template: "googlechrome://newtab")
        ]),
        DeepLinkApp(app: "Firefox", icon: "flame.fill", scheme: "firefox", examples: [
            DeepLinkExample(label: "Открыть URL", template: "firefox://{url}")
        ]),
        DeepLinkApp(app: "Visual Studio Code", icon: "chevron.left.forwardslash.chevron.right", scheme: "vscode", examples: [
            DeepLinkExample(label: "Папка", template: "vscode://file/{path}"),
            DeepLinkExample(label: "Поиск", template: "vscode://vscode.editor.action/?query={query}")
        ]),
        DeepLinkApp(app: "Яндекс.Музыка", icon: "music.note", scheme: "yandexmusic", examples: [
            DeepLinkExample(label: "Главная", template: "yandexmusic://"),
            DeepLinkExample(label: "Трек", template: "yandexmusic://track/{id}")
        ]),
        DeepLinkApp(app: "VK", icon: "person.2.fill", scheme: "vk", examples: [
            DeepLinkExample(label: "Главная", template: "vk://"),
            DeepLinkExample(label: "Стена", template: "vk://wall{owner}_{post}")
        ])
    ]

    /// Извлекает «чистый» схем-плейсхолдер (например `scheme://` для проверки).
    static func resolve(_ template: String, replacements: [String: String]) -> String {
        var result = template
        for (key, value) in replacements {
            result = result.replacingOccurrences(of: "{\(key)}", with: value)
        }
        return result
    }

    /// Извлекает схему из строки ссылки: `spotify:track:123` → `spotify`,
    /// `myapp://profile` → `myapp`. Nil, если схемы нет (пусто или начинается с `://`).
    static func scheme(from link: String) -> String? {
        let trimmed = link.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let colon = trimmed.firstIndex(of: ":") else { return nil }
        let scheme = String(trimmed[..<colon])
        // Схема не должна содержать слэшей — иначе это уже путь, а не схема.
        guard !scheme.isEmpty, !scheme.contains("/") else { return nil }
        return scheme
    }

    /// Приложение из каталога по схеме ссылки (регистронезависимо).
    static func app(forScheme scheme: String) -> DeepLinkApp? {
        let lower = scheme.lowercased()
        return apps.first { $0.scheme.lowercased() == lower }
    }
}

// MARK: - Шторка выбора deep link

struct DeepLinkPickerView: View {
    let onPicked: (String) -> Void
    let onClose: () -> Void

    @EnvironmentObject var appState: AppStateManager
    @State private var query = ""

    private var filtered: [DeepLinkApp] {
        guard !query.isEmpty else { return DeepLinkCatalog.apps }
        return DeepLinkCatalog.apps.filter {
            $0.app.localizedCaseInsensitiveContains(query)
            || $0.scheme.localizedCaseInsensitiveContains(query)
            || $0.examples.contains { $0.label.localizedCaseInsensitiveContains(query) }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Шапка
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Библиотека схем")
                        .font(.title3.bold())
                        .adaptiveTextColor()
                    Text("Выберите приложение и готовую ссылку")
                        .font(.caption)
                        .adaptiveTextColor()
                        .opacity(0.6)
                }
                Spacer()
                Button("Закрыть") { onClose() }
                    .buttonStyle(.bordered)
                    .tint(.white)
                    .controlSize(.small)
            }

            // Поиск
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.caption)
                    .adaptiveTextColor()
                    .opacity(0.5)
                TextField("Поиск по приложению или схеме", text: $query)
                    .textFieldStyle(.plain)
                    .adaptiveTextColor()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )

            if filtered.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.title2)
                        .adaptiveTextColor()
                        .opacity(0.4)
                    Text("Ничего не найдено")
                        .font(.callout)
                        .adaptiveTextColor()
                        .opacity(0.6)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 30)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(filtered) { app in
                            appCard(app)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(16)
    }

    /// Карточка приложения: плитка с иконкой, имя, схема и горизонтальные
    /// чипы готовых ссылок (тап — подставляет шаблон в элемент).
    private func appCard(_ app: DeepLinkApp) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.1))
                    Image(systemName: app.icon)
                        .font(.system(size: 15))
                        .adaptiveTextColor()
                }
                .frame(width: 34, height: 34)

                VStack(alignment: .leading, spacing: 1) {
                    Text(app.app)
                        .font(.subheadline.bold())
                        .adaptiveTextColor()
                    Text(app.scheme + "://")
                        .font(.caption.monospaced())
                        .adaptiveTextColor()
                        .opacity(0.5)
                }
                Spacer()
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(app.examples) { example in
                        Button {
                            onPicked(example.template)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(example.label)
                                    .font(.system(size: 11, weight: .semibold))
                                Text(example.template)
                                    .font(.system(size: 10, design: .monospaced))
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                    .opacity(0.65)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.white.opacity(0.08))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                            )
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .adaptiveTextColor()
                        .help("Подставить: \(example.template)")
                    }
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

// MARK: - Шторка выбора команды Shortcuts

struct ShortcutPickerView: View {
    let onPicked: (String) -> Void
    let onClose: () -> Void

    @State private var names: [String] = []
    @State private var isLoading = true
    @State private var loadFailed = false
    @State private var query = ""

    private var filtered: [String] {
        guard !query.isEmpty else { return names }
        return names.filter { $0.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Команды Shortcuts")
                    .font(.title3.bold())
                    .adaptiveTextColor()
                Spacer()
                Button("Закрыть") { onClose() }
                    .buttonStyle(.bordered)
                    .tint(.white)
                    .controlSize(.small)
            }

            if isLoading {
                HStack {
                    ProgressView()
                    Text("Читаю установленные команды…")
                        .font(.caption)
                        .adaptiveTextColor()
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 30)
                Spacer()
            } else if loadFailed {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .adaptiveTextColor()
                    Text("Не удалось получить список команд.\nУбедитесь, что приложение «Короткие команды» установлено.")
                        .font(.callout)
                        .multilineTextAlignment(.center)
                        .adaptiveTextColor()
                    Button("Повторить") { load() }
                        .buttonStyle(.bordered)
                        .tint(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 30)
                Spacer()
            } else if names.isEmpty {
                Text("Нет установленных команд.")
                    .font(.callout)
                    .adaptiveTextColor()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 30)
                Spacer()
            } else {
                TextField("Поиск", text: $query)
                    .textFieldStyle(.roundedBorder)

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(filtered, id: \.self) { name in
                            Button {
                                onPicked(name)
                            } label: {
                                HStack {
                                    Image(systemName: "square.grid.2x2")
                                        .frame(width: 16)
                                    Text(name)
                                        .lineLimit(1)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .opacity(0.5)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.white.opacity(0.06))
                                )
                            }
                            .buttonStyle(.plain)
                            .adaptiveTextColor()
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(16)
        .onAppear { load() }
    }

    private func load() {
        isLoading = true
        loadFailed = false
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Self.installedShortcuts()
            DispatchQueue.main.async {
                names = result
                isLoading = false
                loadFailed = result.isEmpty
            }
        }
    }

    /// Список команд через системный CLI `/usr/bin/shortcuts list`.
    private static func installedShortcuts() -> [String] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
        process.arguments = ["list"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            return []
        }
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return [] }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let text = String(data: data, encoding: .utf8) else { return [] }
        return text
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}
