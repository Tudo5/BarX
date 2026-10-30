//
//  Styling.swift
//  BarX
//
//  Градиенты, текстовые цвета, рамки и стили кнопок
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers
import Combine
import ServiceManagement
import UserNotifications
import ApplicationServices

// MARK: - NSImage Extension

extension NSImage {
    /// Масштабирует изображение, сохраняя пропорции и качество.
    ///
    /// ВАЖНО: метод обязан быть потокобезопасным — его вызывают из
    /// `DispatchQueue.global()` в семи местах (загрузка значков панели,
    /// Launcher, «Приложения», «Добавить в панель»).
    ///
    /// Прежняя реализация через `lockFocus()`/`unlockFocus()` работала с одним
    /// ОБЩИМ графическим контекстом и была не потокобезопасна: при выборе сразу
    /// многих приложений несколько потоков параллельно захватывали контекст —
    /// приложение падало (гонка, чем больше приложений, тем чаще).
    ///
    /// Здесь растр создаётся напрямую, а контекст делается локальным для потока
    /// (`NSGraphicsContext.current` — thread-local), поэтому параллельные вызовы
    /// друг друга не трогают. Плюс сохраняются пропорции и высокая интерполяция.
    ///
    /// И рисуем сразу под Retina: в масштабе 2.0 пикселей больше, чем точек.
    /// Иначе на экранах Retina изображение растягивалось и выглядело мутным.
    func resized(to target: NSSize) -> NSImage {
        guard target.width > 0, target.height > 0,
              size.width > 0, size.height > 0 else { return self }
        
        // Вписываем в целевой размер (в точках), не меняя соотношение сторон
        let ratio = min(target.width / size.width, target.height / size.height)
        let pointWidth = max(1, (size.width * ratio).rounded())
        let pointHeight = max(1, (size.height * ratio).rounded())
        let pointSize = NSSize(width: pointWidth, height: pointHeight)
        
        // Retina: пикселей вдвое больше, чем точек, — иначе на экранах Retina
        // картинка растягивается и мутнеет. Фиксированный масштаб надёжнее, чем
        // читать NSScreen прямо из фонового потока (UI-объекты требуют главный).
        let scale: CGFloat = 2.0
        let pixelWidth = max(1, Int((pointWidth * scale).rounded()))
        let pixelHeight = max(1, Int((pointHeight * scale).rounded()))
        
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelWidth,
            pixelsHigh: pixelHeight,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            return self
        }
        
        // Логический размер — точки; пикселей в масштабе вдвое больше (Retina)
        bitmap.size = pointSize
        
        // save/restore делают текущий контекст потоковым: каждый поток
        // рисует в свой растр и не мешает остальным.
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        
        guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
            return self
        }
        NSGraphicsContext.current = context
        context.imageInterpolation = .high
        draw(in: NSRect(origin: .zero, size: pointSize), from: .zero, operation: .copy, fraction: 1.0)
        context.flushGraphics()
        
        let newImage = NSImage(size: pointSize)
        newImage.addRepresentation(bitmap)
        return newImage
    }
}

// MARK: - Color Extensions

/// Кэш разобранных hex-значений: цвета тем парсятся постоянно
/// (градиенты, бейджи, предпросмотры), а Scanner каждый раз создавался заново.
private enum HexColorCache {
    static var components: [String: (Double, Double, Double, Double)] = [:]
    static let lock = NSLock()
}

extension Color {
    init(hex: String) {
        let key = hex
        HexColorCache.lock.lock()
        let cached = HexColorCache.components[key]
        HexColorCache.lock.unlock()
        if let cached {
            self.init(.sRGB, red: cached.0, green: cached.1, blue: cached.2, opacity: cached.3)
            return
        }

        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        let red = Double(r) / 255
        let green = Double(g) / 255
        let blue = Double(b) / 255
        let alpha = Double(a) / 255

        HexColorCache.lock.lock()
        HexColorCache.components[key] = (red, green, blue, alpha)
        HexColorCache.lock.unlock()

        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
    
    /// Компоненты цвета в sRGB. Безопасно: у монохромных и динамических
    /// цветов `cgColor.components` может содержать 2 элемента, что раньше
    /// приводило к падению по индексу.
    var srgbComponents: (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) {
        guard let srgb = NSColor(self).usingColorSpace(.sRGB) else {
            return (0, 0, 0, 1)
        }
        return (srgb.redComponent, srgb.greenComponent, srgb.blueComponent, srgb.alphaComponent)
    }
    
    func toHex() -> String {
        let components = srgbComponents
        let r = Float(components.r)
        let g = Float(components.g)
        let b = Float(components.b)
        let a = Float(components.a)
        if a >= 0.999 {
            return String(format: "#%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255))
        } else {
            return String(format: "#%02lX%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255), lroundf(a * 255))
        }
    }
}

// MARK: - GradientBackground

struct GradientBackground: View {
    let theme: Theme?
    @StateObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        if let theme = theme ?? themeManager.selectedTheme {
            if theme.isGradient {
                if theme.gradientDirection == GradientDirection.radial.rawValue {
                    // Радиус берём от реального размера контейнера, иначе
                    // на больших окнах градиент сходится в маленькое пятно.
                    GeometryReader { geo in
                        let diameter = max(geo.size.width, geo.size.height)
                        if let gradient = ThemeManager.shared.getRadialGradient(for: theme, radius: diameter * 0.75) {
                            gradient.opacity(0.95)
                        } else {
                            Color.clear
                        }
                    }
                } else if let gradient = ThemeManager.shared.getGradient(for: theme) {
                    gradient.opacity(0.95)
                } else {
                    Color.clear
                }
            } else {
                ThemeManager.shared.getStyleBackground(for: theme)
            }
        } else {
            Color.clear
        }
    }
}

// MARK: - AdaptiveTextColor

struct AdaptiveTextColor: ViewModifier {
    @StateObject private var themeManager = ThemeManager.shared
    
    func body(content: Content) -> some View {
        let theme = themeManager.effectiveTheme
        let textColor = theme.map { themeManager.getTextColor(for: $0) } ?? .white
        return content.foregroundStyle(textColor)
    }
}

extension View {
    func adaptiveTextColor() -> some View {
        modifier(AdaptiveTextColor())
    }
}

// MARK: - SelectionBorder

struct SelectionBorder: ViewModifier {
    @StateObject private var themeManager = ThemeManager.shared
    let isSelected: Bool
    let isHovered: Bool
    
    func body(content: Content) -> some View {
        let theme = themeManager.effectiveTheme
        let textColor = theme.map { themeManager.getTextColor(for: $0) } ?? .white
        
        return content
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        isSelected ? textColor.opacity(0.6) :
                        isHovered ? textColor.opacity(0.2) :
                        Color.clear,
                        lineWidth: isSelected ? 2 : 1
                    )
                    .padding(-4)
            )
            .padding(4)
            .animation(BarXSettings.quick, value: isSelected)
            .animation(BarXSettings.quick, value: isHovered)
    }
}

extension View {
    func selectionBorder(isSelected: Bool, isHovered: Bool = false) -> some View {
        modifier(SelectionBorder(isSelected: isSelected, isHovered: isHovered))
    }
}

// MARK: - HoverButtonStyle

struct HoverButtonStyle: ButtonStyle {
    @State private var isHovered = false
    @StateObject private var themeManager = ThemeManager.shared
    
    func makeBody(configuration: Configuration) -> some View {
        let theme = themeManager.effectiveTheme
        let textColor = theme.map { themeManager.getTextColor(for: $0) } ?? .white
        
        return configuration.label
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        configuration.isPressed ? textColor.opacity(0.1) : Color.clear
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.98 : isHovered ? 1.01 : 1.0)
            .animation(BarXSettings.quick, value: configuration.isPressed)
            .animation(BarXSettings.quick, value: isHovered)
            .onHover { hovering in
                withAnimation(BarXSettings.quick) {
                    isHovered = hovering
                }
                if hovering {
                    NSCursor.pointingHand.set()
                }
            }
    }
}
