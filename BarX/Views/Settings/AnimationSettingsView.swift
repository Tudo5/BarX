//
//  AnimationSettingsView.swift
//  BarX
//
//  Раздел «Анимации»: профили, скорость, группы эффектов,
//  точные длительности и живой предпросмотр.
//

import SwiftUI
import AppKit
import Combine

// MARK: - AnimationSettingsView

struct AnimationSettingsView: View {
    @StateObject private var center = AnimationCenter.shared

    @State private var toast: String?
    @State private var demoExpanded = false
    @State private var demoSelection = 0
    @State private var demoReplay = 0

    private var animations: AnimationCenter { center }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            previewCard
            profileSection
            speedSection
            groupsSection
            fineTuningSection
            resetSection
            if let toast {
                SettingsHint(text: toast, color: .green)
                    .transition(.opacity)
            }
        }
        .padding(.vertical, 4)
        .animation(animations.quick, value: toast)
    }

    // MARK: - Шапка

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Анимации")
                    .font(.headline)
                    .adaptiveTextColor()
                Text("Профиль, скорость и точные длительности эффектов BarX")
                    .font(.caption)
                    .adaptiveTextColor()
                    .opacity(0.6)
            }

            Spacer()

            Toggle("Анимации", isOn: Binding(
                get: { animations.isEnabled },
                set: { animations.isEnabled = $0 }
            ))
            .toggleStyle(.switch)
            .tint(.white)
            .controlSize(.small)
            .adaptiveTextColor()
        }
    }

    // MARK: - Живой предпросмотр

    private var previewCard: some View {
        SettingsCard(title: "Предпросмотр", icon: "eye") {
            Text(statusLine)
                .font(.caption)
                .adaptiveTextColor()
                .opacity(0.6)

            AnimationDemoStrip(
                expanded: demoExpanded,
                selection: demoSelection,
                replay: demoReplay,
                onSelect: { index in demoSelection = index }
            )

            HStack(spacing: 8) {
                Button {
                    demoExpanded.toggle()
                    replayDemo()
                } label: {
                    Label(demoExpanded ? "Свернуть" : "Развернуть",
                          systemImage: demoExpanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.bordered)
                .tint(.white)
                .controlSize(.small)

                Button {
                    replayDemo()
                } label: {
                    Label("Проиграть появление", systemImage: "play.circle")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.bordered)
                .tint(.white)
                .controlSize(.small)

                Spacer()
            }
        }
    }

    private var statusLine: String {
        if !animations.isEnabled {
            return "Анимации выключены — интерфейс реагирует мгновенно"
        }
        if animations.respectReduceMotion && animations.systemReduceMotion {
            return "Система просит уменьшить движение — эффекты ограничены"
        }
        return "Профиль «\(animations.profile.rawValue)» · скорость \(speedLabel)"
    }

    private func replayDemo() {
        demoReplay += 1
    }

    // MARK: - Профиль

    private var profileSection: some View {
        SettingsCard(title: "Профиль", icon: "wand.and.stars") {
            HStack(spacing: 8) {
                ForEach(BarXAnimationProfile.allCases) { profile in
                    AnimationProfileChip(
                        profile: profile,
                        isSelected: animations.profile == profile
                    ) {
                        animations.profile = profile
                        replayDemo()
                    }
                }
            }
            .disabled(!animations.isEnabled)
            .opacity(animations.isEnabled ? 1 : 0.45)

            SettingsHint(text: animations.profile.description)

            VStack(alignment: .leading, spacing: 4) {
                SettingsInfoRow(label: "Множитель длительности", value: String(format: "×%.2f", animations.profile.timeScale))
                SettingsInfoRow(label: "Масштаб при наведении", value: String(format: "×%.2f", animations.profile.hoverScale))
                SettingsInfoRow(label: "Смещение появления", value: String(format: "%.0f pt", animations.profile.liftOffset))
                SettingsInfoRow(label: "Затухание пружины", value: String(format: "%.2f", animations.profile.damping))
            }
            .opacity(animations.isEnabled ? 1 : 0.45)
        }
    }

    // MARK: - Скорость

    private var speedSection: some View {
        SettingsCard(title: "Скорость", icon: "speedometer") {
            SettingsInfoRow(label: "Общий множитель", value: speedLabel)
            Slider(
                value: Binding(get: { animations.speed }, set: { animations.speed = $0 }),
                in: 0.05...0.8,
                step: 0.01
            )
            .tint(.white)

            HStack(spacing: 6) {
                speedPreset("Очень быстро", 0.10)
                speedPreset("Быстро", 0.18)
                speedPreset("Обычно", 0.30)
                speedPreset("Плавно", 0.50)
                speedPreset("Медленно", 0.75)
                Spacer()
            }

            Toggle("Учитывать системное «Уменьшить движение»", isOn: Binding(
                get: { animations.respectReduceMotion },
                set: { animations.respectReduceMotion = $0 }
            ))
            .toggleStyle(SwitchToggleStyle(tint: .white))
            .adaptiveTextColor()
            .help("Если в macOS включено уменьшение движения, BarX отключит эффекты")
        }
        .disabled(!animations.isEnabled)
        .opacity(animations.isEnabled ? 1 : 0.45)
    }

    private var speedLabel: String {
        let value = animations.speed
        let seconds = String(format: "%.2f", value)
        if value < 0.14 { return "очень быстро (\(seconds))" }
        if value < 0.24 { return "быстро (\(seconds))" }
        if value < 0.4 { return "обычно (\(seconds))" }
        if value < 0.6 { return "плавно (\(seconds))" }
        return "медленно (\(seconds))"
    }

    private func speedPreset(_ title: String, _ value: Double) -> some View {
        let isActive = abs(animations.speed - value) < 0.005
        return Button {
            withAnimation(AnimationCenter.shared.spring) {
                animations.speed = value
            }
            replayDemo()
        } label: {
            Text(title)
                .font(.system(size: 11, weight: isActive ? .semibold : .regular))
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(isActive ? Color.white.opacity(0.22) : Color.white.opacity(0.07))
                )
                .adaptiveTextColor()
                .opacity(isActive ? 1 : 0.75)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Группы эффектов

    private var groupsSection: some View {
        SettingsCard(title: "Группы эффектов", icon: "switch.2") {
            groupToggle(
                "Наведение и нажатие",
                subtitle: "Подсветка строк, увеличение иконок, отклик на клик",
                isOn: Binding(get: { animations.hoverEnabled }, set: { animations.hoverEnabled = $0 })
            )
            groupToggle(
                "Появление элементов",
                subtitle: "Плавное всплытие строк, карточек и списков",
                isOn: Binding(get: { animations.appearEnabled }, set: { animations.appearEnabled = $0 })
            )
            groupToggle(
                "Переходы между экранами",
                subtitle: "Смена разделов настроек, страниц и панелей",
                isOn: Binding(get: { animations.transitionsEnabled }, set: { animations.transitionsEnabled = $0 })
            )
            groupToggle(
                "Пульсация и свечение",
                subtitle: "Дыхание логотипа, индикаторы, блики загрузки",
                isOn: Binding(get: { animations.pulseEnabled }, set: { animations.pulseEnabled = $0 })
            )
            groupToggle(
                "Живой фон меню",
                subtitle: "Медленно перемещающиеся световые пятна в главном меню",
                isOn: Binding(get: { animations.animatedBackground }, set: { animations.animatedBackground = $0 })
            )

            Divider().background(Color.white.opacity(0.2))

            SettingsInfoRow(
                label: "Задержка каскада",
                value: String(format: "%.0f мс", animations.staggerDelay * 1000)
            )
            Slider(
                value: Binding(get: { animations.staggerDelay }, set: { animations.staggerDelay = $0 }),
                in: 0...0.15,
                step: 0.005
            )
            .tint(.white)
            .disabled(!animations.appearEnabled)
            .opacity(animations.appearEnabled ? 1 : 0.45)
            SettingsHint(text: "Пауза между появлением соседних элементов списка")
        }
        .disabled(!animations.isEnabled)
        .opacity(animations.isEnabled ? 1 : 0.45)
    }

    private func groupToggle(_ title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .adaptiveTextColor()
                Text(subtitle)
                    .font(.system(size: 10))
                    .adaptiveTextColor()
                    .opacity(0.5)
            }
        }
        .toggleStyle(SwitchToggleStyle(tint: .white))
    }

    // MARK: - Точные длительности

    private var fineTuningSection: some View {
        SettingsCard(title: "Точные длительности", icon: "slider.horizontal.below.rectangle") {
            durationRow(
                "Наведение",
                seconds: Binding(get: { animations.hoverDuration }, set: { animations.hoverDuration = $0 }),
                range: 0.02...0.6
            )
            durationRow(
                "Нажатие",
                seconds: Binding(get: { animations.pressDuration }, set: { animations.pressDuration = $0 }),
                range: 0.02...0.4
            )
            durationRow(
                "Смена состояний",
                seconds: Binding(get: { animations.standardDuration }, set: { animations.standardDuration = $0 }),
                range: 0.05...0.8
            )
            durationRow(
                "Отклик пружины",
                seconds: Binding(get: { animations.springResponse }, set: { animations.springResponse = $0 }),
                range: 0.05...1.0
            )

            Divider().background(Color.white.opacity(0.2))

            VStack(alignment: .leading, spacing: 3) {
                Text("Итоговые значения")
                    .font(.system(size: 11, weight: .semibold))
                    .adaptiveTextColor()
                    .opacity(0.7)
                SettingsInfoRow(label: "Наведение", value: seconds(animations.effectiveHoverDuration))
                SettingsInfoRow(label: "Нажатие", value: seconds(animations.effectivePressDuration))
                SettingsInfoRow(label: "Смена состояний", value: seconds(animations.effectiveStandardDuration))
                SettingsInfoRow(label: "Перестроение списков", value: seconds(animations.effectiveLayoutDuration))
                SettingsInfoRow(label: "Пружина", value: seconds(animations.effectiveSpringResponse))
                SettingsInfoRow(label: "Упругая пружина", value: seconds(animations.effectiveBouncyResponse))
            }

            Button {
                withAnimation(animations.spring) {
                    replayDemo()
                }
            } label: {
                Label("Проверить на примере", systemImage: "play.circle")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.bordered)
            .tint(.white)
            .controlSize(.small)
        }
        .disabled(!animations.isEnabled)
        .opacity(animations.isEnabled ? 1 : 0.45)
    }

    private func durationRow(_ title: String, seconds: Binding<Double>, range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            SettingsInfoRow(label: title, value: String(format: "%.3f с", seconds.wrappedValue))
            Slider(value: seconds, in: range, step: 0.005)
                .tint(.white)
        }
    }

    private func seconds(_ value: Double) -> String {
        String(format: "%.3f с", value)
    }

    // MARK: - Сброс

    private var resetSection: some View {
        SettingsCard(title: "Сброс", icon: "arrow.counterclockwise") {
            HStack(spacing: 8) {
                Button("Сбросить всё") {
                    resetAll()
                }
                .buttonStyle(.bordered)
                .tint(.orange)
                .controlSize(.small)

                Button("Только длительности") {
                    withAnimation(animations.spring) {
                        animations.hoverDuration = 0.12
                        animations.pressDuration = 0.08
                        animations.standardDuration = 0.22
                        animations.springResponse = 0.28
                        animations.staggerDelay = 0.03
                    }
                    showToast("Длительности сброшены")
                }
                .buttonStyle(.bordered)
                .tint(.white)
                .controlSize(.small)

                Spacer()
            }
            SettingsHint(text: "Сброс затрагивает только параметры анимаций — темы и данные не изменяются.")
        }
    }

    private func resetAll() {
        withAnimation(animations.standard) {
            animations.isEnabled = true
            animations.profile = .smooth
            animations.speed = 0.3
            animations.respectReduceMotion = true
            animations.hoverEnabled = true
            animations.appearEnabled = true
            animations.transitionsEnabled = true
            animations.pulseEnabled = true
            animations.animatedBackground = true
            animations.staggerDelay = 0.03
            animations.hoverDuration = 0.12
            animations.pressDuration = 0.08
            animations.standardDuration = 0.22
            animations.springResponse = 0.28
        }
        replayDemo()
        showToast("Анимации сброшены к значениям по умолчанию")
    }

    private func showToast(_ message: String) {
        withAnimation(animations.quick) { toast = message }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(animations.quick) {
                if toast == message { toast = nil }
            }
        }
    }
}

// MARK: - AnimationProfileChip

struct AnimationProfileChip: View {
    let profile: BarXAnimationProfile
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false
    private let animations = AnimationCenter.shared

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: profile.icon)
                    .font(.system(size: 15))
                Text(profile.rawValue)
                    .font(.system(size: 10, weight: .medium))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.white.opacity(0.22) : Color.white.opacity(isHovered ? 0.12 : 0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.white.opacity(0.7) : Color.clear, lineWidth: 1.5)
            )
            .adaptiveTextColor()
            .scaleEffect(isSelected ? 1.03 : (isHovered ? 1.02 : 1.0))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(animations.hover) { isHovered = hovering }
            if hovering { NSCursor.pointingHand.set() }
        }
        .help(profile.description)
    }
}

// MARK: - AnimationDemoStrip
// Живая демонстрация текущих настроек анимации.

struct AnimationDemoStrip: View {
    let expanded: Bool
    let selection: Int
    let replay: Int
    let onSelect: (Int) -> Void

    @State private var appeared = false

    private let items = ["safari", "message", "music.note", "photo", "terminal", "gear", "folder", "star"]
    private let animations = AnimationCenter.shared

    var body: some View {
        HStack(spacing: expanded ? 10 : 8) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, name in
                let isSelected = selection == index
                VStack(spacing: 3) {
                    RoundedRectangle(cornerRadius: 9)
                        .fill(Color.white.opacity(isSelected ? 0.28 : 0.1))
                        .frame(width: expanded ? 44 : 32, height: expanded ? 44 : 32)
                        .overlay(
                            Image(systemName: name)
                                .font(.system(size: expanded ? 18 : 13))
                                .adaptiveTextColor()
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 9)
                                .stroke(isSelected ? Color.white.opacity(0.75) : Color.clear, lineWidth: 1.5)
                        )
                        .scaleEffect(isSelected ? 1.08 : 1.0)
                        .glowPulse(Color(hex: BarXSettings.appearanceAccent), isActive: isSelected)
                        .onTapGesture { onSelect(index) }

                    if expanded {
                        Text(name)
                            .font(.system(size: 8))
                            .adaptiveTextColor()
                            .opacity(0.5)
                            .lineLimit(1)
                            .frame(width: 46)
                    }
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : CGFloat(animations.appearOffset))
                .animation(animations.spring, value: expanded)
                .animation(animations.spring, value: selection)
                .animation(animations.hover, value: appeared)
            }
            Spacer(minLength: 0)
        }
        .frame(height: expanded ? 74 : 46)
        .onAppear { play() }
        .onChange(of: replay) { _, _ in play() }
    }

    private func play() {
        appeared = false
        guard animations.isActive, animations.appearEnabled else {
            appeared = true
            return
        }
        for index in items.indices {
            DispatchQueue.main.asyncAfter(deadline: .now() + animations.stagger(for: index)) {
                withAnimation(animations.quick) { appeared = true }
            }
        }
    }
}
