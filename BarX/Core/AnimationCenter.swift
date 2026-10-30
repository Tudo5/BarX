//
//  AnimationCenter.swift
//  BarX
//
//  Отдельный модуль анимаций: единые тайминги, переходы и модификаторы.
//  Все анимации приложения берут параметры отсюда, поэтому профиль,
//  скорость, длительности и группы анимаций настраиваются в одном месте
//  (раздел «Анимации» в настройках).
//

import SwiftUI
import AppKit
import Combine

// MARK: - Профиль анимации

enum BarXAnimationProfile: String, CaseIterable, Identifiable {
    case smooth = "Плавно"
    case spring = "Пружина"
    case snappy = "Быстро"
    case expressive = "Выразительно"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .smooth: return "wind"
        case .spring: return "circle.dotted"
        case .snappy: return "bolt.fill"
        case .expressive: return "sparkles"
        }
    }

    var description: String {
        switch self {
        case .smooth: return "Мягкие линейные переходы без отскока"
        case .spring: return "Живая пружина с лёгким отскоком"
        case .snappy: return "Мгновенный отклик, короткие дистанции"
        case .expressive: return "Выраженное движение, масштаб и подъём"
        }
    }

    /// Множитель длительности для профиля.
    var timeScale: Double {
        switch self {
        case .smooth: return 1.0
        case .spring: return 1.12
        case .snappy: return 0.7
        case .expressive: return 1.3
        }
    }

    /// Насколько элемент увеличивается при наведении.
    var hoverScale: Double {
        switch self {
        case .smooth: return 1.02
        case .spring: return 1.03
        case .snappy: return 1.01
        case .expressive: return 1.06
        }
    }

    /// Смещение «всплытия» при появлении.
    var liftOffset: Double {
        switch self {
        case .smooth: return 5
        case .spring: return 8
        case .snappy: return 2
        case .expressive: return 14
        }
    }

    /// Затухание пружины.
    var damping: Double {
        switch self {
        case .smooth: return 1.0
        case .spring: return 0.72
        case .snappy: return 0.9
        case .expressive: return 0.6
        }
    }
}

// MARK: - AnimationCenter

final class AnimationCenter: ObservableObject {
    static let shared = AnimationCenter()

    // MARK: Общие

    @AppStorage("animationsEnabled") private var animationsEnabled: Bool = true
    @AppStorage("animationProfile") private var profileRaw: String = BarXAnimationProfile.smooth.rawValue
    /// Общий множитель скорости: 0.3 — эталон, меньше — быстрее, больше — плавнее.
    @AppStorage("animationSpeed") private var speedFactor: Double = 0.3
    @AppStorage("animRespectReduceMotion") private var respectReduceMotionFlag: Bool = true

    // MARK: Группы анимаций

    @AppStorage("animHoverEnabled") private var hoverGroupEnabled: Bool = true
    @AppStorage("animAppearEnabled") private var appearGroupEnabled: Bool = true
    @AppStorage("animTransitionsEnabled") private var transitionsGroupEnabled: Bool = true
    @AppStorage("animPulseEnabled") private var pulseGroupEnabled: Bool = true
    @AppStorage("animStaggerDelay") private var staggerValue: Double = 0.03
    @AppStorage("appearanceAnimatedBackground") private var animatedBackgroundFlag: Bool = true

    // MARK: Точные длительности (в секундах)

    @AppStorage("animHoverDuration") private var hoverBase: Double = 0.12
    @AppStorage("animPressDuration") private var pressBase: Double = 0.08
    @AppStorage("animStandardDuration") private var standardBase: Double = 0.22
    @AppStorage("animSpringResponse") private var springBase: Double = 0.28

    private init() {}

    // MARK: - Общие настройки (чтение и запись из раздела «Анимации»)

    var isEnabled: Bool {
        get { animationsEnabled }
        set { animationsEnabled = newValue; notify() }
    }

    var profile: BarXAnimationProfile {
        get { BarXAnimationProfile(rawValue: profileRaw) ?? .smooth }
        set { profileRaw = newValue.rawValue; notify() }
    }

    var speed: Double {
        get { speedFactor > 0 ? speedFactor : 0.3 }
        set { speedFactor = newValue; notify() }
    }

    var respectReduceMotion: Bool {
        get { respectReduceMotionFlag }
        set { respectReduceMotionFlag = newValue; notify() }
    }

    /// Системная настройка «Уменьшить движение».
    var systemReduceMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    // MARK: - Группы

    var hoverEnabled: Bool {
        get { hoverGroupEnabled }
        set { hoverGroupEnabled = newValue; notify() }
    }

    var appearEnabled: Bool {
        get { appearGroupEnabled }
        set { appearGroupEnabled = newValue; notify() }
    }

    var transitionsEnabled: Bool {
        get { transitionsGroupEnabled }
        set { transitionsGroupEnabled = newValue; notify() }
    }

    var pulseEnabled: Bool {
        get { pulseGroupEnabled }
        set { pulseGroupEnabled = newValue; notify() }
    }

    var staggerDelay: Double {
        get { max(0, min(0.2, staggerValue)) }
        set { staggerValue = max(0, min(0.2, newValue)); notify() }
    }

    var animatedBackground: Bool {
        get { animatedBackgroundFlag }
        set { animatedBackgroundFlag = newValue; notify() }
    }

    // MARK: - Точные длительности

    var hoverDuration: Double {
        get { hoverBase > 0 ? hoverBase : 0.12 }
        set { hoverBase = max(0.02, newValue); notify() }
    }

    var pressDuration: Double {
        get { pressBase > 0 ? pressBase : 0.08 }
        set { pressBase = max(0.02, newValue); notify() }
    }

    var standardDuration: Double {
        get { standardBase > 0 ? standardBase : 0.22 }
        set { standardBase = max(0.02, newValue); notify() }
    }

    var springResponse: Double {
        get { springBase > 0 ? springBase : 0.28 }
        set { springBase = max(0.05, newValue); notify() }
    }

    /// Анимации активны с учётом системной настройки «Уменьшить движение».
    var isActive: Bool {
        guard animationsEnabled else { return false }
        if respectReduceMotionFlag && systemReduceMotion { return false }
        return true
    }

    private func notify() {
        objectWillChange.send()
    }

    // MARK: - Длительности

    /// Множитель пользовательской скорости.
    private var speedScale: Double { speed / 0.3 }

    private func scaled(_ base: Double) -> Double {
        guard isActive else { return 0.01 }
        return max(0.01, base * speedScale * profile.timeScale)
    }

    // MARK: - Базовые кривые

    /// Наведение и подсветка строк.
    var hover: Animation {
        hoverGroupEnabled ? .easeOut(duration: scaled(hoverDuration)) : .linear(duration: 0.01)
    }

    /// Короткая подсветка.
    var quick: Animation {
        .easeOut(duration: scaled(hoverDuration * 0.85))
    }

    /// Отклик на нажатие.
    var press: Animation {
        hoverGroupEnabled ? .easeOut(duration: scaled(pressDuration)) : .linear(duration: 0.01)
    }

    /// Стандартная анимация интерфейса.
    var standard: Animation {
        .easeInOut(duration: scaled(standardDuration))
    }

    /// Перестроение списков: без пружины и смещений, чтобы не «дёргалось».
    var layout: Animation {
        .easeInOut(duration: scaled(standardDuration * 1.2))
    }

    /// Пружина для «живых» элементов.
    var spring: Animation {
        guard isActive else { return .linear(duration: 0.01) }
        return .spring(
            response: scaled(springResponse),
            dampingFraction: max(0.7, profile.damping),
            blendDuration: 0.05
        )
    }

    /// Более упругая пружина для появления и масштаба.
    var bouncy: Animation {
        guard isActive, appearEnabled else { return .linear(duration: 0.01) }
        return .spring(
            response: scaled(springResponse * 1.2),
            dampingFraction: max(0.45, profile.damping - 0.12),
            blendDuration: 0.08
        )
    }

    /// Плавное «дыхание» подсветки.
    var pulse: Animation {
        guard isActive, pulseGroupEnabled else { return .linear(duration: 0.01) }
        return .easeInOut(duration: 2.4).repeatForever(autoreverses: true)
    }

    /// Постепенное вращение индикаторов.
    var spin: Animation {
        guard isActive, pulseGroupEnabled else { return .linear(duration: 1) }
        return .linear(duration: 1).repeatForever(autoreverses: false)
    }

    /// Своя длительность с учётом профиля.
    func custom(_ seconds: Double) -> Animation {
        .easeInOut(duration: scaled(seconds))
    }

    // MARK: Итоговые длительности (в секундах, для раздела «Анимации»)

    var effectiveHoverDuration: Double { scaled(hoverDuration) }
    var effectivePressDuration: Double { scaled(pressDuration) }
    var effectiveStandardDuration: Double { scaled(standardDuration) }
    var effectiveLayoutDuration: Double { scaled(standardDuration * 1.2) }
    var effectiveSpringResponse: Double { scaled(springResponse) }
    var effectiveBouncyResponse: Double { scaled(springResponse * 1.2) }

    // MARK: - Величины движения

    /// Масштаб при наведении.
    var hoverScale: Double {
        isActive && hoverGroupEnabled ? profile.hoverScale : 1.0
    }

    /// Смещение при появлении.
    var appearOffset: Double {
        isActive && appearEnabled ? profile.liftOffset : 0
    }

    /// Задержка каскада для элемента с индексом.
    func stagger(for index: Int) -> Double {
        guard isActive, appearEnabled else { return 0 }
        return min(0.2, staggerDelay) * Double(index)
    }

    // MARK: - Переходы

    private var transitionsActive: Bool {
        isActive && transitionsGroupEnabled
    }

    /// Появление «сверху» с масштабом — для выпадающих списков и меню.
    var appearTransition: AnyTransition {
        guard transitionsActive else { return .identity }
        return .asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.94, anchor: .top)),
            removal: .opacity.combined(with: .scale(scale: 0.98, anchor: .top))
        )
    }

    /// Появление «сбоку» — для панелей и сайдбаров.
    var slideTransition: AnyTransition {
        guard transitionsActive else { return .identity }
        return .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .opacity
        )
    }

    /// Мягкое всплытие — для карточек и строк.
    var liftTransition: AnyTransition {
        guard transitionsActive else { return .identity }
        return .asymmetric(
            insertion: .offset(y: CGFloat(appearOffset)).combined(with: .opacity),
            removal: .opacity
        )
    }

    /// Масштабирование — для иконок и акцентов.
    var popTransition: AnyTransition {
        guard transitionsActive else { return .identity }
        return .scale(scale: 0.6, anchor: .center).combined(with: .opacity)
    }

    /// Смена раздела настроек.
    var sectionTransition: AnyTransition {
        guard transitionsActive else { return .identity }
        return .asymmetric(
            insertion: .opacity.combined(with: .offset(x: 14)),
            removal: .opacity
        )
    }

    /// Смена страницы в сетках (иконки, панель Bar).
    var pageTransition: AnyTransition {
        guard transitionsActive else { return .identity }
        return .asymmetric(
            insertion: .opacity.combined(with: .offset(x: 18)),
            removal: .opacity.combined(with: .offset(x: -18))
        )
    }
}

// MARK: - Модификаторы анимации

/// Появление элемента с задержкой (каскадная анимация списков).
struct AnimatedAppearModifier: ViewModifier {
    let delay: Double
    let offset: Double
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : CGFloat(offset))
            .onAppear {
                guard !appeared else { return }
                let center = AnimationCenter.shared
                guard center.isActive, center.appearEnabled else {
                    appeared = true
                    return
                }
                let cappedDelay = min(max(0, delay), 0.2)
                if cappedDelay <= 0 {
                    withAnimation(center.quick) { appeared = true }
                } else {
                    DispatchQueue.main.asyncAfter(deadline: .now() + cappedDelay) {
                        withAnimation(center.quick) { appeared = true }
                    }
                }
            }
    }
}

/// Увеличение и лёгкий подъём при наведении.
struct HoverLiftModifier: ViewModifier {
    @State private var isHovered = false
    let enabled: Bool

    func body(content: Content) -> some View {
        let center = AnimationCenter.shared
        return content
            .scaleEffect(isHovered && enabled ? center.hoverScale : 1.0)
            .offset(y: isHovered && enabled && center.hoverEnabled ? -1 : 0)
            .animation(center.hover, value: isHovered)
            .onHover { hovering in
                isHovered = hovering
                if hovering { NSCursor.pointingHand.set() }
            }
    }
}

/// Плавное «дыхание» подсветки вокруг элемента.
struct GlowPulseModifier: ViewModifier {
    let color: Color
    let isActive: Bool
    @State private var pulse = false

    func body(content: Content) -> some View {
        let center = AnimationCenter.shared
        return content
            .shadow(
                color: isActive && center.pulseEnabled ? color.opacity(pulse ? 0.55 : 0.15) : .clear,
                radius: pulse ? 12 : 4
            )
            .animation(center.pulse, value: pulse)
            .onAppear {
                guard isActive, center.pulseEnabled, center.isActive else { return }
                pulse = true
            }
            .onChange(of: isActive) { _, newValue in
                pulse = newValue
            }
    }
}

/// Блик, пробегающий по элементу (для акцентов и загрузки).
struct ShimmerModifier: ViewModifier {
    let isActive: Bool
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        let center = AnimationCenter.shared
        return content
            .overlay {
                if isActive && center.isActive {
                    GeometryReader { geometry in
                        LinearGradient(
                            colors: [.clear, Color.white.opacity(0.25), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: geometry.size.width * 0.6)
                        .offset(x: phase * geometry.size.width * 1.6)
                    }
                    .allowsHitTesting(false)
                    .clipped()
                }
            }
            .onAppear {
                guard isActive, center.isActive else { return }
                withAnimation(.linear(duration: 1.8).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

extension View {
    /// Каскадное появление элемента.
    func animatedAppear(delay: Double = 0, offset: Double? = nil) -> some View {
        modifier(AnimatedAppearModifier(delay: delay, offset: offset ?? AnimationCenter.shared.appearOffset))
    }

    /// Наведение с увеличением и подъёмом.
    func hoverLift(_ enabled: Bool = true) -> some View {
        modifier(HoverLiftModifier(enabled: enabled))
    }

    /// Пульсирующая подсветка.
    func glowPulse(_ color: Color, isActive: Bool = true) -> some View {
        modifier(GlowPulseModifier(color: color, isActive: isActive))
    }

    /// Пробегающий блик.
    func shimmer(isActive: Bool) -> some View {
        modifier(ShimmerModifier(isActive: isActive))
    }
}
