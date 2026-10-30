//
//  AppearanceSettingsView.swift
//  BarX
//
//  Раздел «Внешний вид»: темы, предпросмотр, анимации и оформление.
//  Список встроенных тем не меняется — переработана только подача.
//

import SwiftUI
import AppKit
import Combine

// MARK: - AppearanceSettingsView

struct AppearanceSettingsView: View {
    @StateObject private var themeManager = ThemeManager.shared

    // Предпросмотр
    @AppStorage("appearanceShowPreview") private var showPreview = true
    @AppStorage("appearanceCustomOnly") private var showOnlyCustom = false
    @AppStorage("appearanceGridColumns") private var gridColumns = 4

    // Оформление
    @AppStorage("appearanceCardRadius") private var cardRadius: Double = 10
    @AppStorage("appearanceBackgroundOpacity") private var backgroundOpacity: Double = 0.95
    @AppStorage("appearanceShadow") private var shadowStrength: Double = 0.45
    @AppStorage("appearanceAccent") private var accentHex: String = "#8B5CF6"
    @AppStorage("appearanceTintIcons") private var tintIcons = true

    // Своя тема
    @State private var customColor1 = Color(hex: "#8B5CF6")
    @State private var customColor2 = Color(hex: "#06B6D4")
    @State private var customColor3 = Color(hex: "#EC4899")
    @State private var customColor4 = Color(hex: "#F59E0B")
    @State private var selectedDirection: GradientDirection = .horizontal
    @State private var selectedTextColor: Theme.TextColor = .auto
    @State private var themeSearch = ""
    @State private var didLoadStoredColors = false
    @State private var lastSavedName: String?

    @StateObject private var animations = AnimationCenter.shared

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            if showPreview { previewSection }
            themesSection
            appearanceSection
            customThemeSection
        }
        .padding(.vertical, 4)
        .onAppear {
            loadStoredColors()
        }
    }

    // MARK: - Шапка

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Внешний вид")
                    .font(.headline)
                    .adaptiveTextColor()
                Text("Темы, анимации и оформление интерфейса")
                    .font(.caption)
                    .adaptiveTextColor()
                    .opacity(0.6)
            }

            Spacer()

            if themeManager.isPreviewMode {
                HStack(spacing: 8) {
                    Button {
                        withAnimation(animations.spring) { themeManager.applyPreviewTheme() }
                    } label: {
                        Label("Применить", systemImage: "checkmark")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .controlSize(.small)

                    Button {
                        withAnimation(animations.spring) { themeManager.cancelPreview() }
                    } label: {
                        Label("Отменить", systemImage: "xmark")
                    }
                    .buttonStyle(.bordered)
                    .tint(.white)
                    .controlSize(.small)
                }
                .transition(animations.appearTransition)
            } else {
                Toggle("Только свои темы", isOn: $showOnlyCustom)
                    .toggleStyle(.switch)
                    .tint(.white)
                    .controlSize(.small)
                    .adaptiveTextColor()
                    .onChange(of: showOnlyCustom) { _, _ in
                        themeManager.objectWillChange.send()
                    }
            }
        }
        .animation(animations.spring, value: themeManager.isPreviewMode)
    }

    // MARK: - Предпросмотр

    private var previewSection: some View {
        SettingsCard(title: "Предпросмотр", icon: "eye") {
            MenuPreviewMock(
                theme: themeManager.effectiveTheme,
                accent: Color(hex: accentHex),
                cornerRadius: cardRadius,
                backgroundOpacity: backgroundOpacity,
                shadow: shadowStrength
            )
            .frame(height: 116)

            HStack(spacing: 8) {
                Text(themeManager.effectiveTheme?.name ?? "Тема не выбрана")
                    .font(.caption)
                    .adaptiveTextColor()
                    .opacity(0.7)

                if themeManager.isPreviewMode {
                    Text("предпросмотр")
                        .font(.system(size: 9, weight: .semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Color.orange.opacity(0.3)))
                        .adaptiveTextColor()
                        .transition(.scale.combined(with: .opacity))
                }

                Spacer()

                Toggle("Показывать", isOn: $showPreview)
                    .toggleStyle(.switch)
                    .tint(.white)
                    .controlSize(.mini)
                    .adaptiveTextColor()
            }
            .animation(animations.spring, value: themeManager.isPreviewMode)
        }
    }

    // MARK: - Темы

    private var themesSection: some View {
        SettingsCard(title: "Темы", icon: "paintpalette") {
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                        .adaptiveTextColor()
                        .opacity(0.5)
                    TextField("Найти тему", text: $themeSearch)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .adaptiveTextColor()
                    if !themeSearch.isEmpty {
                        Button {
                            themeSearch = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 10))
                                .adaptiveTextColor()
                                .opacity(0.5)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(Color.white.opacity(0.08))
                )

                Spacer()

                Text("Колонок: \(gridColumns)")
                    .font(.caption2)
                    .adaptiveTextColor()
                    .opacity(0.55)

                Stepper("", value: $gridColumns, in: 2...6)
                    .labelsHidden()
                    .controlSize(.mini)
            }

            if filteredThemes.isEmpty {
                SettingsHint(text: "Темы не найдены — попробуйте другой запрос.")
            } else {
                LazyVGrid(columns: gridColumnsList, spacing: 10) {
                    ForEach(filteredThemes) { theme in
                        ThemeButton(
                            theme: theme,
                            isCustom: theme.isCustom,
                            cornerRadius: cardRadius,
                            tintIcons: tintIcons,
                            onSelect: {
                                withAnimation(animations.spring) {
                                    themeManager.selectTheme(theme, applyImmediately: false)
                                }
                            },
                            onApply: {
                                withAnimation(animations.spring) {
                                    themeManager.selectTheme(theme, applyImmediately: true)
                                }
                            },
                            onDelete: {
                                withAnimation(animations.spring) {
                                    themeManager.deleteCustomTheme(theme)
                                }
                            }
                        )
                    }
                }
                .animation(animations.spring, value: filteredThemes.count)
            }

            SettingsHint(text: "Клик — предпросмотр, двойной клик — применить, правый клик — меню.")
        }
    }

    private var filteredThemes: [Theme] {
        var list = showOnlyCustom ? themeManager.getCustomThemes() : themeManager.themes
        let query = themeSearch.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty {
            list = list.filter { $0.name.localizedCaseInsensitiveContains(query) }
        }
        return list
    }

    private var gridColumnsList: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 10), count: max(2, min(6, gridColumns)))
    }

    // MARK: - Оформление

    private var appearanceSection: some View {
        SettingsCard(title: "Оформление", icon: "square.on.circle") {
            SettingsInfoRow(label: "Скругление карточек", value: String(format: "%.0f pt", cardRadius))
            Slider(value: $cardRadius, in: 4...24, step: 1)
                .tint(.white)

            SettingsInfoRow(label: "Плотность фона", value: String(format: "%.0f%%", backgroundOpacity * 100))
            Slider(value: $backgroundOpacity, in: 0.5...1.0, step: 0.05)
                .tint(.white)

            SettingsInfoRow(label: "Тень панелей", value: String(format: "%.0f%%", shadowStrength * 100))
            Slider(value: $shadowStrength, in: 0...1, step: 0.05)
                .tint(.white)

            Divider().background(Color.white.opacity(0.2))

            HStack(spacing: 10) {
                SettingsInfoRow(label: "Акцентный цвет", value: accentHex.uppercased())
                ColorPicker("", selection: Binding(
                    get: { Color(hex: accentHex) },
                    set: { accentHex = $0.toHex() }
                ), supportsOpacity: false)
                .labelsHidden()
                .frame(width: 40, height: 24)
            }

            HStack(spacing: 8) {
                ForEach(accentPresets, id: \.self) { hex in
                    AccentSwatch(hex: hex, isSelected: accentHex == hex) {
                        withAnimation(animations.spring) { accentHex = hex }
                    }
                }
                Spacer()
            }

            Toggle("Подкрашивать значки акцентным цветом", isOn: $tintIcons)
                .toggleStyle(SwitchToggleStyle(tint: .white))
                .adaptiveTextColor()

            Button {
                withAnimation(animations.spring) {
                    cardRadius = 10
                    backgroundOpacity = 0.95
                    shadowStrength = 0.45
                    accentHex = "#8B5CF6"
                    tintIcons = true
                }
            } label: {
                Label("Сбросить оформление", systemImage: "arrow.counterclockwise")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.bordered)
            .tint(.white)
            .controlSize(.small)
        }
    }

    private var accentPresets: [String] {
        ["#8B5CF6", "#06B6D4", "#10B981", "#F59E0B", "#EC4899", "#EF4444", "#3B82F6", "#A3A3A3"]
    }

    // MARK: - Своя тема

    private var customThemeSection: some View {
        SettingsCard(title: "Своя тема", icon: "wand.and.stars") {
            Text("Выберите цвета — предпросмотр обновляется сразу")
                .font(.caption)
                .adaptiveTextColor()
                .opacity(0.6)

            HStack(spacing: 14) {
                colorWell("Цвет 1", $customColor1)
                colorWell("Цвет 2", $customColor2)
                colorWell("Цвет 3", $customColor3)
                colorWell("Цвет 4", $customColor4)

                Spacer()

                if !themeManager.customColors.isEmpty {
                    Button {
                        withAnimation(animations.spring) { loadStoredColors(force: true) }
                    } label: {
                        Label("Вернуть последние", systemImage: "clock.arrow.circlepath")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                    .adaptiveTextColor()
                    .opacity(0.75)
                }
            }

            GradientPreviewStrip(
                colors: draftColors,
                direction: selectedDirection,
                cornerRadius: cardRadius
            )
            .frame(height: 44)

            Picker("Направление", selection: $selectedDirection) {
                ForEach(GradientDirection.allCases, id: \.self) { direction in
                    Text(direction.rawValue).tag(direction)
                }
            }
            .pickerStyle(.segmented)
            .colorMultiply(.white)

            Picker("Цвет текста", selection: $selectedTextColor) {
                ForEach(Theme.TextColor.allCases, id: \.self) { color in
                    Text(color.rawValue).tag(color)
                }
            }
            .pickerStyle(.segmented)
            .colorMultiply(.white)

            HStack(spacing: 8) {
                Button {
                    applyCustomTheme()
                } label: {
                    Label("Добавить тему", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.white)

                if let lastSavedName {
                    Text("Готово: \(lastSavedName)")
                        .font(.caption)
                        .adaptiveTextColor()
                        .opacity(0.7)
                        .transition(.opacity)
                }
            }
            .animation(animations.spring, value: lastSavedName)
        }
    }

    private func colorWell(_ title: String, _ binding: Binding<Color>) -> some View {
        VStack(spacing: 4) {
            ColorPicker(title, selection: binding, supportsOpacity: false)
                .labelsHidden()
                .frame(width: 38, height: 30)
            Text(title.replacingOccurrences(of: "Цвет ", with: ""))
                .font(.system(size: 9))
                .adaptiveTextColor()
                .opacity(0.5)
        }
    }

    private var draftColors: [String] {
        [customColor1, customColor2, customColor3, customColor4].map { $0.toHex() }
    }

    // MARK: - Логика

    private func loadStoredColors(force: Bool = false) {
        if didLoadStoredColors && !force { return }
        didLoadStoredColors = true

        let stored = themeManager.customColors
        if stored.indices.contains(0) { customColor1 = stored[0] }
        if stored.indices.contains(1) { customColor2 = stored[1] }
        if stored.indices.contains(2) { customColor3 = stored[2] }
        if stored.indices.contains(3) { customColor4 = stored[3] }
    }

    private func applyCustomTheme() {
        let colors = draftColors

        // Уникальное имя: после удаления темы нумерация не повторяется
        let existingNames = Set(themeManager.getCustomThemes().map { $0.name })
        var index = themeManager.getCustomThemes().count + 1
        var name = "Моя тема \(index)"
        while existingNames.contains(name) {
            index += 1
            name = "Моя тема \(index)"
        }

        let theme = Theme(
            name: name,
            colors: colors,
            isGradient: colors.count >= 2,
            gradientDirection: selectedDirection.rawValue,
            isCustom: true,
            textColor: selectedTextColor
        )

        themeManager.addCustomColors(colors.compactMap { Color(hex: $0) })
        withAnimation(animations.spring) {
            themeManager.addCustomTheme(theme)
            themeManager.selectTheme(theme, applyImmediately: true)
            lastSavedName = name
        }
    }
}

// MARK: - AccentSwatch

struct AccentSwatch: View {
    let hex: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(Color(hex: hex))
                .frame(width: 22, height: 22)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(isSelected ? 0.95 : 0.2), lineWidth: isSelected ? 2 : 1)
                )
                .scaleEffect(isSelected ? 1.14 : 1.0)
                .animation(AnimationCenter.shared.spring, value: isSelected)
        }
        .buttonStyle(.plain)
        .help(hex.uppercased())
    }
}

// MARK: - ThemeButton

struct ThemeButton: View {
    let theme: Theme
    let isCustom: Bool
    var cornerRadius: Double = 10
    var tintIcons: Bool = true
    let onSelect: () -> Void
    var onApply: () -> Void = {}
    let onDelete: () -> Void

    @StateObject private var themeManager = ThemeManager.shared
    @State private var isHovered = false
    @StateObject private var animations = AnimationCenter.shared

    private var isActive: Bool {
        themeManager.effectiveTheme?.id == theme.id
    }

    private var isApplied: Bool {
        themeManager.selectedTheme?.id == theme.id && !themeManager.isPreviewMode
    }

    var body: some View {
        VStack(spacing: 5) {
            Button(action: onSelect) {
                ZStack {
                    GradientBackground(theme: theme)
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))

                    if isActive {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(Color.white.opacity(0.9), lineWidth: 2)
                    }

                    HStack(spacing: 4) {
                        ForEach(0..<3, id: \.self) { index in
                            Circle()
                                .fill(Color.white.opacity(0.85 - Double(index) * 0.2))
                                .frame(width: 6, height: 6)
                        }
                    }
                    .opacity(isHovered || isActive ? 1 : 0)

                    if isApplied {
                        VStack {
                            HStack {
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.white)
                                    .padding(4)
                            }
                            Spacer()
                        }
                    }
                }
                .frame(height: 46)
                .shadow(
                    color: .black.opacity(isHovered ? 0.35 : 0.18),
                    radius: isHovered ? 7 : 3,
                    x: 0,
                    y: 2
                )
                .scaleEffect(isHovered ? 1.03 : 1.0)
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                withAnimation(animations.spring) { isHovered = hovering }
                if hovering { NSCursor.pointingHand.set() }
            }
            .simultaneousGesture(
                TapGesture(count: 2).onEnded { onApply() }
            )
            .contextMenu {
                Button("Применить", action: onApply)
                Button("Предпросмотр", action: onSelect)
                if isCustom {
                    Divider()
                    Button("Удалить тему", role: .destructive, action: onDelete)
                }
            }
            .help("\(theme.name): клик — предпросмотр, двойной клик — применить")

            HStack(spacing: 3) {
                if tintIcons {
                    Circle()
                        .fill(Color(hex: theme.colors.first ?? "#8B5CF6"))
                        .frame(width: 6, height: 6)
                }
                Text(theme.name)
                    .font(.system(size: 10))
                    .adaptiveTextColor()
                    .lineLimit(1)
                    .opacity(isActive ? 1 : 0.8)
                if isCustom {
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 9))
                        .adaptiveTextColor()
                        .opacity(0.5)
                }
            }
        }
        .animation(animations.spring, value: isActive)
        .animation(animations.spring, value: isApplied)
    }
}

// MARK: - MenuPreviewMock

struct MenuPreviewMock: View {
    let theme: Theme?
    let accent: Color
    let cornerRadius: Double
    let backgroundOpacity: Double
    let shadow: Double

    private let samples = ["safari", "message", "music.note", "photo", "terminal"]

    var body: some View {
        ZStack {
            if let theme {
                GradientBackground(theme: theme)
            } else {
                Color.gray.opacity(0.3)
            }

            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11, weight: .semibold))
                    Text("BarX")
                        .font(.system(size: 12, weight: .semibold))
                    Spacer()
                    Image(systemName: "gearshape")
                        .font(.system(size: 10))
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                }
                .adaptiveTextColor()

                HStack(spacing: 9) {
                    ForEach(Array(samples.enumerated()), id: \.offset) { index, name in
                        RoundedRectangle(cornerRadius: 7)
                            .fill(Color.white.opacity(0.14))
                            .frame(width: 28, height: 28)
                            .overlay(
                                Image(systemName: name)
                                    .font(.system(size: 12))
                                    .foregroundStyle(index == 0 ? accent : .white)
                                    .opacity(index == 0 ? 1 : 0.85)
                            )
                    }
                    Spacer()
                }

                HStack(spacing: 6) {
                    Capsule()
                        .fill(accent)
                        .frame(width: 54, height: 6)
                    Capsule()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 30, height: 6)
                    Spacer()
                }
            }
            .padding(12)
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .opacity(backgroundOpacity)
        .shadow(color: .black.opacity(shadow), radius: 10, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
    }
}

// MARK: - GradientPreviewStrip

struct GradientPreviewStrip: View {
    let colors: [String]
    let direction: GradientDirection
    let cornerRadius: Double

    var body: some View {
        let parsed = colors.compactMap { Color(hex: $0) }
        let gradient = LinearGradient(
            gradient: Gradient(colors: parsed.isEmpty ? [.gray] : parsed),
            startPoint: startPoint,
            endPoint: endPoint
        )
        return RoundedRectangle(cornerRadius: cornerRadius)
            .fill(gradient)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
            .animation(AnimationCenter.shared.spring, value: colors)
    }

    private var startPoint: UnitPoint {
        switch direction {
        case .horizontal: return .leading
        case .vertical: return .top
        case .diagonal: return .topLeading
        case .radial: return .center
        }
    }

    private var endPoint: UnitPoint {
        switch direction {
        case .horizontal: return .trailing
        case .vertical: return .bottom
        case .diagonal: return .bottomTrailing
        case .radial: return .bottomTrailing
        }
    }
}
