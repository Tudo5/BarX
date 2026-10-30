//
//  OnboardingView.swift
//  BarX
//
//  Приветственный экран первого запуска.
//
//  Раньше приложение открывалось в пустое состояние: панель пустая, папок нет,
//  и ни слова о том, как вообще пользоваться. Пользователь видел «иконку в строке
//  меню», не понимал, зачем она, и закрывал. Здесь за три коротких шага человек
//  выбирает приложения, тему и узнаёт горячую клавишу.
//

import SwiftUI
import AppKit
import Combine

// MARK: - OnboardingView

struct OnboardingView: View {
    @EnvironmentObject var appState: AppStateManager
    @EnvironmentObject var themeManager: ThemeManager

    @AppStorage("launcherHotkeyKey") private var hotkey: String = "⌘ ⇧ B"
    @AppStorage("appearanceAccent") private var accentHex: String = "#8B5CF6"

    @State private var page = 0
    @State private var chosenAppPaths: Set<String> = []
    @State private var chosenThemeId: UUID?

    @StateObject private var animations = AnimationCenter.shared

    private let pageCount = 3

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().background(Color.white.opacity(0.15))

            ZStack {
                switch page {
                case 0: welcomePage
                case 1: appsPage
                default: themePage
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider().background(Color.white.opacity(0.15))
            footer
        }
        .frame(width: 620, height: 460)
        .background(GradientBackground(theme: themeManager.effectiveTheme).ignoresSafeArea())
        .onAppear {
            if chosenThemeId == nil { chosenThemeId = themeManager.selectedTheme?.id }
        }
    }

    // MARK: - Шапка и подвал

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 18, weight: .semibold))
                .adaptiveTextColor()

            VStack(alignment: .leading, spacing: 1) {
                Text("Добро пожаловать в BarX")
                    .font(.system(size: 15, weight: .bold))
                    .adaptiveTextColor()
                Text("Панель быстрого запуска в строке меню")
                    .font(.system(size: 11))
                    .adaptiveTextColor()
                    .opacity(0.6)
            }

            Spacer()

            HStack(spacing: 5) {
                ForEach(0..<pageCount, id: \.self) { index in
                    Capsule()
                        .fill(index == page ? Color.white.opacity(0.9) : Color.white.opacity(0.2))
                        .frame(width: index == page ? 18 : 6, height: 6)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .animation(animations.spring, value: page)
    }

    private var footer: some View {
        HStack {
            Button("Назад") {
                withAnimation(animations.standard) { page = max(0, page - 1) }
            }
            .buttonStyle(.bordered)
            .tint(.white)
            .disabled(page == 0)

            Spacer()

            if page < pageCount - 1 {
                Button("Далее") {
                    withAnimation(animations.standard) { page += 1 }
                }
                .buttonStyle(.borderedProminent)
                .tint(.white)
            } else {
                Button("Начать пользоваться") {
                    finish()
                }
                .buttonStyle(.borderedProminent)
                .tint(.white)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
    }

    // MARK: - Страница 1: приветствие

    private var welcomePage: some View {
        VStack(spacing: 18) {
            Spacer()

            Image(systemName: "menubar.rectangle")
                .font(.system(size: 46, weight: .light))
                .adaptiveTextColor()
                .opacity(0.85)

            Text("Всё под рукой — в одном клике")
                .font(.system(size: 20, weight: .bold))
                .adaptiveTextColor()

            Text("Закрепите любимые приложения в панели, соберите их в папки\nи открывайте любое из них с клавиатуры.")
                .font(.system(size: 12))
                .multilineTextAlignment(.center)
                .adaptiveTextColor()
                .opacity(0.7)

            hotkeyBadge

            VStack(alignment: .leading, spacing: 8) {
                featureRow(icon: "square.grid.2x2", text: "Панель Bar — быстрый запуск закреплённых приложений")
                featureRow(icon: "magnifyingglass", text: "Launcher — поиск по всем установленным приложениям")
                featureRow(icon: "folder", text: "Папки — свои наборы приложений и ссылок")
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.15))
            )
            .frame(maxWidth: 440)

            Spacer()
        }
        .padding(.horizontal, 32)
    }

    /// Показывает реальную комбинацию и объясняет, что доп разрешения не нужны.
    private var hotkeyBadge: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Text("Нажмите")
                    .font(.system(size: 11))
                    .adaptiveTextColor()
                    .opacity(0.65)
                Text(hotkey)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .adaptiveTextColor()
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white.opacity(0.14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                    )
                Text("чтобы открыть Launcher")
                    .font(.system(size: 11))
                    .adaptiveTextColor()
                    .opacity(0.65)
            }
            Text("Работает из любого приложения. Дополнительные разрешения не требуются.")
                .font(.system(size: 10))
                .adaptiveTextColor()
                .opacity(0.45)
        }
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .frame(width: 18)
                .adaptiveTextColor()
                .opacity(0.8)
            Text(text)
                .font(.system(size: 11))
                .adaptiveTextColor()
                .opacity(0.85)
            Spacer()
        }
    }

    // MARK: - Страница 2: первые приложения

    private var appsPage: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Закрепите первые приложения")
                .font(.system(size: 16, weight: .bold))
                .adaptiveTextColor()

            Text("Выберите те, что запускаете чаще всего — они появятся в панели Bar. Максимум \(BarXSettings.maxBarApps).")
                .font(.system(size: 11))
                .adaptiveTextColor()
                .opacity(0.65)

            ScrollView {
                VStack(spacing: 3) {
                    ForEach(suggestedApps) { app in
                        appRow(app)
                    }
                }
                .padding(.vertical, 4)
            }
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.black.opacity(0.12))
            )

            Text("Выбрано: \(chosenAppPaths.count) из \(BarXSettings.maxBarApps)")
                .font(.system(size: 11))
                .adaptiveTextColor()
                .opacity(0.6)
        }
        .padding(24)
    }

    /// Избранные подсказки: известные приложения из общего списка.
    private var suggestedApps: [AppItem] {
        let preferred = ["Safari", "Mail", "Messages", "Calendar", "Notes",
                         "Photos", "Music", "Maps", "FaceTime", "Podcasts",
                         "Xcode", "Terminal", "System Settings"]
        let matched = appState.installedApps.filter { preferred.contains($0.name) }
        let rest = appState.installedApps.filter { !preferred.contains($0.name) }
        return (matched + rest).prefix(30).map { $0 }
    }

    private func appRow(_ app: AppItem) -> some View {
        let isSelected = chosenAppPaths.contains(app.path)
        let isFull = chosenAppPaths.count >= BarXSettings.maxBarApps && !isSelected

        return Button {
            toggle(app)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 14))
                    .foregroundStyle(isSelected ? Color.green : Color.white.opacity(0.4))

                Text(app.name)
                    .font(.system(size: 12))
                    .adaptiveTextColor()
                    .lineLimit(1)

                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.white.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .disabled(isFull)
        .opacity(isFull ? 0.4 : 1)
    }

    private func toggle(_ app: AppItem) {
        withAnimation(animations.quick) {
            if chosenAppPaths.contains(app.path) {
                chosenAppPaths.remove(app.path)
            } else if chosenAppPaths.count < BarXSettings.maxBarApps {
                chosenAppPaths.insert(app.path)
            }
        }
    }

    // MARK: - Страница 3: тема

    private var themePage: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Выберите оформление")
                .font(.system(size: 16, weight: .bold))
                .adaptiveTextColor()

            Text("Тему всегда можно поменять позже в Настройках.")
                .font(.system(size: 11))
                .adaptiveTextColor()
                .opacity(0.65)

            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                    ForEach(themeManager.themes) { theme in
                        themeCell(theme)
                    }
                }
                .padding(8)
            }
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.black.opacity(0.12))
            )
        }
        .padding(24)
    }

    private func themeCell(_ theme: Theme) -> some View {
        let isSelected = chosenThemeId == theme.id

        return Button {
            withAnimation(animations.quick) { chosenThemeId = theme.id }
        } label: {
            VStack(spacing: 6) {
                ThemeSwatch(theme: theme)
                    .frame(height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                    .overlay(
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(
                                isSelected ? Color.white : Color.white.opacity(0.15),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )

                Text(theme.name)
                    .font(.system(size: 10))
                    .adaptiveTextColor()
                    .opacity(isSelected ? 1 : 0.65)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Завершение

    private func finish() {
        // Применяем выбранную тему
        if let themeId = chosenThemeId,
           let theme = themeManager.themes.first(where: { $0.id == themeId }) {
            themeManager.selectTheme(theme, applyImmediately: true)
        }

        // Добавляем выбранные приложения в панель
        for path in chosenAppPaths {
            if let app = appState.installedApps.first(where: { $0.path == path }) {
                _ = appState.addToBar(app)
            }
        }

        OnboardingState.markCompleted()
        BarXWindowManager.shared.closeWindow(id: "onboarding")

        // Сразу показываем готовую панель, чтобы эффект был виден
        DispatchQueue.main.async {
            BarXWindowManager.shared.showMainMenu()
        }
    }
}

// MARK: - ThemeSwatch

/// Миниатюра темы: градиент или сплошной цвет с материалом.
private struct ThemeSwatch: View {
    let theme: Theme

    var body: some View {
        if theme.isGradient, let gradient = ThemeManager.shared.getGradient(for: theme) {
            gradient
        } else if theme.isGradient, let radial = ThemeManager.shared.getRadialGradient(for: theme) {
            radial
        } else if let first = theme.colors.first {
            Color(hex: first)
        } else {
            Color.gray.opacity(0.4)
        }
    }
}

// MARK: - OnboardingState

/// Отметка о прохождении первого запуска.
///
/// Намеренно НЕ входит в `BarXSettings.defaultValues`: сброс настроек
/// не должен заставлять пользователя проходить приветствие заново.
enum OnboardingState {
    private static let key = "hasCompletedOnboarding"

    static var isCompleted: Bool {
        UserDefaults.standard.bool(forKey: key)
    }

    static func markCompleted() {
        UserDefaults.standard.set(true, forKey: key)
    }
}
