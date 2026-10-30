//
//  ThemeManager.swift
//  BarX
//
//  Темы и цвета оформления
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers
import Combine
import ServiceManagement
import UserNotifications
import ApplicationServices

// MARK: - ThemeManager

class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    @Published var themes: [Theme] = []
    @Published var customColors: [Color] = []
    @Published var selectedTheme: Theme?
    @Published var previewTheme: Theme?
    @Published var isPreviewMode = false
    
    @AppStorage("selectedThemeId") private var selectedThemeId: String = ""
    @AppStorage("customColorsData") private var customColorsData: Data = Data()
    @AppStorage("themesData") private var themesData: Data = Data()
    @AppStorage("customThemeIds") private var customThemeIdsData: Data = Data()
    
    private var customThemeIds: Set<String> = []
    private var cancellables = Set<AnyCancellable>()

    /// Кэш разрешённых цветов: getTextColor вызывается для каждого текста
    /// интерфейса, а внутри были разбор hex и конвертация NSColor.
    private var textColorCache: [UUID: Color] = [:]
    
    init() {
        loadCustomThemeIds()
        loadDefaultThemes()
        loadCustomColors()
        loadSelectedTheme()
    }
    
    // MARK: - Public Methods
    
    /// Тема, которую нужно рисовать прямо сейчас (с учётом предпросмотра).
    var effectiveTheme: Theme? {
        isPreviewMode ? (previewTheme ?? selectedTheme) : selectedTheme
    }
    
    func reloadThemes() {
        invalidateColorCache()
        loadDefaultThemes()
        loadCustomColors()
        loadSelectedTheme()
        objectWillChange.send()
    }
    
    func loadDefaultThemes() {
        if !themesData.isEmpty {
            if let decoded = try? JSONDecoder().decode([Theme].self, from: themesData) {
                themes = decoded
                return
            }
        }
        
        themes = [
            Theme(name: "Фиолетовый", colors: ["#8B5CF6", "#6D28D9"], isGradient: true, gradientDirection: GradientDirection.horizontal.rawValue, isCustom: false),
            Theme(name: "Океан", colors: ["#06B6D4", "#3B82F6"], isGradient: true, gradientDirection: GradientDirection.horizontal.rawValue, isCustom: false),
            Theme(name: "Закат", colors: ["#F472B6", "#FB923C"], isGradient: true, gradientDirection: GradientDirection.horizontal.rawValue, isCustom: false),
            Theme(name: "Лес", colors: ["#10B981", "#059669"], isGradient: true, gradientDirection: GradientDirection.horizontal.rawValue, isCustom: false),
            Theme(name: "Космос", colors: ["#7C3AED", "#1E1B4B"], isGradient: true, gradientDirection: GradientDirection.diagonal.rawValue, isCustom: false),
            Theme(name: "Розовый", colors: ["#EC4899", "#BE185D"], isGradient: true, gradientDirection: GradientDirection.horizontal.rawValue, isCustom: false),
            Theme(name: "Солнечный", colors: ["#F59E0B", "#FCD34D"], isGradient: true, gradientDirection: GradientDirection.horizontal.rawValue, isCustom: false),
            Theme(name: "Лаванда", colors: ["#A78BFA", "#7C3AED"], isGradient: true, gradientDirection: GradientDirection.vertical.rawValue, isCustom: false),
            Theme(name: "Мятный", colors: ["#34D399", "#059669"], isGradient: true, gradientDirection: GradientDirection.horizontal.rawValue, isCustom: false),
            Theme(name: "Коралл", colors: ["#FB7185", "#E11D48"], isGradient: true, gradientDirection: GradientDirection.horizontal.rawValue, isCustom: false),
            Theme(name: "Бирюза", colors: ["#2DD4BF", "#0D9488"], isGradient: true, gradientDirection: GradientDirection.vertical.rawValue, isCustom: false),
            Theme(name: "Янтарь", colors: ["#FBBF24", "#F59E0B"], isGradient: true, gradientDirection: GradientDirection.diagonal.rawValue, isCustom: false),
            Theme(name: "Сиреневый", colors: ["#C084FC", "#7C3AED"], isGradient: true, gradientDirection: GradientDirection.radial.rawValue, isCustom: false),
            Theme(name: "Неон", colors: ["#34D399", "#60A5FA", "#F472B6"], isGradient: true, gradientDirection: GradientDirection.horizontal.rawValue, isCustom: false),
            Theme(name: "Радуга", colors: ["#F87171", "#FBBF24", "#34D399", "#60A5FA"], isGradient: true, gradientDirection: GradientDirection.diagonal.rawValue, isCustom: false),
            Theme(name: "Графит", colors: ["#6B7280", "#1F2937"], isGradient: true, gradientDirection: GradientDirection.horizontal.rawValue, isCustom: false),
            Theme(name: "Бежевый", colors: ["#FDE68A", "#F59E0B"], isGradient: true, gradientDirection: GradientDirection.horizontal.rawValue, isCustom: false),
            Theme(name: "Ледяной", colors: ["#93C5FD", "#3B82F6"], isGradient: true, gradientDirection: GradientDirection.horizontal.rawValue, isCustom: false),
        ]
        saveThemes()
    }
    
    func loadSelectedTheme() {
        if let theme = themes.first(where: { $0.id.uuidString == selectedThemeId }) {
            selectedTheme = theme
        } else if let firstTheme = themes.first {
            selectedTheme = firstTheme
            selectedThemeId = firstTheme.id.uuidString
        }
    }
    
    func selectTheme(_ theme: Theme, applyImmediately: Bool = false) {
        if applyImmediately {
            selectedTheme = theme
            selectedThemeId = theme.id.uuidString
            isPreviewMode = false
            previewTheme = nil
            objectWillChange.send()
            NotificationCenter.default.post(name: .themeDidChange, object: nil)
        } else {
            previewTheme = theme
            isPreviewMode = true
            objectWillChange.send()
        }
    }
    
    func applyPreviewTheme() {
        if let theme = previewTheme {
            selectedTheme = theme
            selectedThemeId = theme.id.uuidString
            isPreviewMode = false
            previewTheme = nil
            objectWillChange.send()
            NotificationCenter.default.post(name: .themeDidChange, object: nil)
        }
    }
    
    func cancelPreview() {
        isPreviewMode = false
        previewTheme = nil
        objectWillChange.send()
    }
    
    func addCustomTheme(_ theme: Theme) {
        var newTheme = theme
        newTheme.isCustom = true
        themes.append(newTheme)
        customThemeIds.insert(newTheme.id.uuidString)
        saveCustomThemeIds()
        saveThemes()
        selectTheme(newTheme)
        objectWillChange.send()
    }
    
    func deleteCustomTheme(_ theme: Theme) {
        guard theme.isCustom else { return }
        if let index = themes.firstIndex(where: { $0.id == theme.id }) {
            themes.remove(at: index)
            customThemeIds.remove(theme.id.uuidString)
            saveCustomThemeIds()
            saveThemes()
            if selectedTheme?.id == theme.id {
                selectedTheme = themes.first
                selectedThemeId = themes.first?.id.uuidString ?? ""
            }
            // Если удалённая тема была в предпросмотре, выходим из него
            if previewTheme?.id == theme.id {
                previewTheme = nil
                isPreviewMode = false
            }
            // Обновляем кэш цвета и сообщаем об изменении: раньше уведомления
            // не было, и панель/лаунчер продолжали рисоваться в цветах
            // удалённой темы до перезапуска приложения.
            invalidateColorCache()
            NotificationCenter.default.post(name: .themeDidChange, object: nil)
            objectWillChange.send()
        }
    }
    
    func getCustomThemes() -> [Theme] {
        themes.filter { $0.isCustom }
    }
    
    func getDefaultThemes() -> [Theme] {
        themes.filter { !$0.isCustom }
    }
    
    func addCustomColors(_ colors: [Color]) {
        customColors = colors
        saveCustomColors()
        objectWillChange.send()
    }
    
    func getTextColor(for theme: Theme) -> Color {
        if let cached = textColorCache[theme.id] { return cached }
        let resolved = computeTextColor(for: theme)
        textColorCache[theme.id] = resolved
        return resolved
    }

    /// Полная очистка кэша (после смены набора тем).
    private func invalidateColorCache() {
        textColorCache.removeAll()
    }

    private func computeTextColor(for theme: Theme) -> Color {
        switch theme.textColor {
        case .light:
            return .white
        case .dark:
            return .black
        case .auto:
            // Яркость считаем для ЛЮБОЙ темы, а не только для градиентной.
            // Раньше сплошная (не-градиентная) светлая тема всегда получала
            // белый текст — он просто не был виден на светлом фоне.
            let colors = theme.colors.compactMap { Color(hex: $0) }
            guard !colors.isEmpty else { return .white }
            
            // Для градиента усредняем яркость всех цветов: беря только первый,
            // можно ошибиться на переходе светлый → тёмный.
            let average = colors.reduce(0.0) { $0 + getColorBrightness($1) } / Double(colors.count)
            return average > 0.55 ? .black : .white
        }
    }
    
    func getGradient(for theme: Theme) -> LinearGradient? {
        guard theme.isGradient && theme.colors.count >= 2 else { return nil }
        let colors = theme.colors.compactMap { Color(hex: $0) }
        guard colors.count >= 2 else { return nil }
        
        let startPoint: UnitPoint
        let endPoint: UnitPoint
        let direction = theme.gradientDirection ?? GradientDirection.horizontal.rawValue
        
        switch direction {
        case GradientDirection.horizontal.rawValue:
            startPoint = .leading
            endPoint = .trailing
        case GradientDirection.vertical.rawValue:
            startPoint = .top
            endPoint = .bottom
        case GradientDirection.diagonal.rawValue:
            startPoint = .topLeading
            endPoint = .bottomTrailing
        default:
            startPoint = .leading
            endPoint = .trailing
        }
        
        return LinearGradient(
            gradient: Gradient(colors: colors),
            startPoint: startPoint,
            endPoint: endPoint
        )
    }
    
    /// Радиальный градиент с явным радиусом.
    ///
    /// Радиус обязан вычисляться от размера контейнера: раньше он был
    /// захардкожен (100 pt), и на окне шире 200 pt градиент выглядел
    /// как маленькое пятно по центру на пустом фоне.
    func getRadialGradient(for theme: Theme, radius: CGFloat) -> RadialGradient? {
        guard theme.isGradient && theme.gradientDirection == GradientDirection.radial.rawValue else { return nil }
        let colors = theme.colors.compactMap { Color(hex: $0) }
        guard colors.count >= 2 else { return nil }
        
        return RadialGradient(
            gradient: Gradient(colors: colors),
            center: .center,
            startRadius: 0,
            endRadius: max(radius, 1)
        )
    }
    
    /// Совместимая версия без размера контейнера.
    func getRadialGradient(for theme: Theme) -> RadialGradient? {
        getRadialGradient(for: theme, radius: 400)
    }
    
    func getStyleBackground(for theme: Theme) -> AnyView {
        if theme.isGradient {
            return AnyView(
                ZStack {
                    if theme.gradientDirection == GradientDirection.radial.rawValue {
                        if let gradient = getRadialGradient(for: theme) {
                            gradient.opacity(0.95)
                        }
                    } else if let gradient = getGradient(for: theme) {
                        gradient.opacity(0.95)
                    }
                }
            )
        } else {
            return AnyView(
                Color.clear
                    .background(.ultraThinMaterial)
                    .opacity(0.7)
            )
        }
    }
    
    // MARK: - Private Methods
    
    private func loadCustomThemeIds() {
        if !customThemeIdsData.isEmpty {
            if let decoded = try? JSONDecoder().decode([String].self, from: customThemeIdsData) {
                customThemeIds = Set(decoded)
            }
        }
    }
    
    private func saveCustomThemeIds() {
        if let encoded = try? JSONEncoder().encode(Array(customThemeIds)) {
            customThemeIdsData = encoded
        }
    }
    
    private func saveThemes() {
        invalidateColorCache()
        if let encoded = try? JSONEncoder().encode(themes) {
            themesData = encoded
        }
    }
    
    private func loadCustomColors() {
        guard !customColorsData.isEmpty else {
            customColors = []
            return
        }
        if let decoded = try? JSONDecoder().decode([String].self, from: customColorsData) {
            customColors = decoded.compactMap { hex in
                Color(hex: hex)
            }
        }
    }
    
    private func saveCustomColors() {
        let hexColors = customColors.map { $0.toHex() }
        if let encoded = try? JSONEncoder().encode(hexColors) {
            customColorsData = encoded
        }
    }
    
    private func getColorBrightness(_ color: Color) -> Double {
        let rgb = color.srgbComponents
        return (Double(rgb.r) * 299 + Double(rgb.g) * 587 + Double(rgb.b) * 114) / 1000
    }
}
