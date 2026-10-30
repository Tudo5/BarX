//
//  AboutView.swift
//  BarX
//
//  Раздел «О программе»: версия, возможности и контакт в Telegram.
//

import SwiftUI
import AppKit
import Combine

// MARK: - AboutView

struct AboutView: View {
    @StateObject private var themeManager = ThemeManager.shared

    @AppStorage("appearanceAccent") private var accentHex: String = "#8B5CF6"

    @State private var logoPulse = false
    @State private var visibleFeatures = 0

    /// Контакт для связи
    static let telegramHandle = "@Dreamssport"
    static let telegramURL = "https://t.me/Dreamssport"

    @StateObject private var animations = AnimationCenter.shared

    /// Версия читается из Info.plist, а не хардкодится
    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var body: some View {
        VStack(spacing: 18) {
            logoBlock
            descriptionBlock
            featuresGrid
            contactBlock
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .onAppear {
            withAnimation(animations.pulse) { logoPulse = true }
            animateFeatures()
        }
    }

    // MARK: - Логотип

    private var logoBlock: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color(hex: accentHex).opacity(0.18))
                    .frame(width: 104, height: 104)
                    .blur(radius: 14)

                Circle()
                    .stroke(Color(hex: accentHex).opacity(0.35), lineWidth: 1)
                    .frame(width: 88, height: 88)
                    .scaleEffect(logoPulse ? 1.08 : 0.94)
                    .opacity(logoPulse ? 0.25 : 0.7)
                    .animation(animations.pulse, value: logoPulse)

                Image(systemName: "sparkles")
                    .font(.system(size: 46, weight: .semibold))
                    .adaptiveTextColor()
                    .scaleEffect(logoPulse ? 1.04 : 0.97)
                    .animation(animations.pulse, value: logoPulse)
            }
            .frame(height: 110)

            Text("BarX")
                .font(.system(size: 30, weight: .bold))
                .adaptiveTextColor()

            HStack(spacing: 6) {
                Text("Версия \(version)")
                    .font(.system(size: 12, weight: .medium))
                    .adaptiveTextColor()
                    .opacity(0.75)

                Text("сборка \(buildNumber)")
                    .font(.system(size: 10))
                    .adaptiveTextColor()
                    .opacity(0.5)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.white.opacity(0.12)))
            }
        }
    }

    // MARK: - Описание

    private var descriptionBlock: some View {
        VStack(spacing: 6) {
            Text("Панель быстрого доступа к приложениям в строке меню macOS")
                .font(.system(size: 13, weight: .medium))
                .adaptiveTextColor()
                .opacity(0.85)
                .multilineTextAlignment(.center)

            Text("Панель Bar, папки с программами, Launcher с горячей клавишей, темы и гибкие настройки — всё в одном приложении.")
                .font(.system(size: 11))
                .adaptiveTextColor()
                .opacity(0.55)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Возможности

    private var featuresGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
            spacing: 10
        ) {
            ForEach(Array(features.enumerated()), id: \.offset) { index, feature in
                FeatureCard(icon: feature.icon, title: feature.title, subtitle: feature.subtitle)
                    .opacity(index < visibleFeatures ? 1 : 0)
                    .offset(y: index < visibleFeatures ? 0 : 8)
                    .animation(animations.spring, value: visibleFeatures)
            }
        }
        .padding(.horizontal, 8)
    }

    private struct Feature {
        let icon: String
        let title: String
        let subtitle: String
    }

    private var features: [Feature] {
        [
            Feature(icon: "pin.fill", title: "Панель Bar", subtitle: "Любимые приложения в один клик"),
            Feature(icon: "folder.fill", title: "Папки", subtitle: "Наборы программ и файлов"),
            Feature(icon: "magnifyingglass", title: "Launcher", subtitle: "Поиск по горячей клавише"),
            Feature(icon: "sparkles", title: "Анимации", subtitle: "4 профиля и своя скорость"),
            Feature(icon: "paintpalette.fill", title: "Темы", subtitle: "Готовые и свои градиенты"),
            Feature(icon: "clock.arrow.circlepath", title: "Недавние", subtitle: "История запусков")
        ]
    }

    private func animateFeatures() {
        for index in features.indices {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.06 * Double(index)) {
                withAnimation(animations.spring) { visibleFeatures = index + 1 }
            }
        }
    }

    // MARK: - Контакт

    private var contactBlock: some View {
        VStack(spacing: 8) {
            Divider()
                .background(Color.white.opacity(0.25))
                .padding(.horizontal, 60)

            Text("Связь и поддержка")
                .font(.system(size: 11, weight: .medium))
                .adaptiveTextColor()
                .opacity(0.55)

            Button {
                if let url = URL(string: Self.telegramURL) {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 13))
                    Text("Telegram")
                        .font(.system(size: 13, weight: .semibold))
                    Text(Self.telegramHandle)
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .opacity(0.85)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(hex: "#2AABEE").opacity(0.85))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.25), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .hoverLift()
            .help("Написать в Telegram \(Self.telegramHandle)")

            Text("Разработано с ❤️ для macOS")
                .font(.system(size: 10))
                .adaptiveTextColor()
                .opacity(0.4)
                .padding(.top, 2)
        }
    }
}

// MARK: - FeatureCard

struct FeatureCard: View {
    let icon: String
    let title: String
    let subtitle: String

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 9) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 30, height: 30)
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .adaptiveTextColor()
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .adaptiveTextColor()
                Text(subtitle)
                    .font(.system(size: 10))
                    .adaptiveTextColor()
                    .opacity(0.55)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(isHovered ? 0.1 : 0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .onHover { hovering in
            withAnimation(AnimationCenter.shared.hover) { isHovered = hovering }
        }
    }
}
