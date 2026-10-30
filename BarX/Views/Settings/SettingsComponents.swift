//
//  SettingsComponents.swift
//  BarX
//
//  Карточки и строки настроек
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers
import Combine
import ServiceManagement
import UserNotifications
import ApplicationServices

// MARK: - GeneralSettingsView

/// Карточка раздела настроек.
struct SettingsCard<Content: View>: View {
    let title: String
    let icon: String
    let content: Content

    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
            }
            .adaptiveTextColor()
            .opacity(0.85)

            VStack(alignment: .leading, spacing: 10) {
                content
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
        }
    }
}

/// Строка «подпись — значение».
struct SettingsInfoRow: View {
    let label: String
    let value: String
    var valueColor: Color = .white

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .adaptiveTextColor()
                .opacity(0.7)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .font(.system(size: 13))
    }
}

/// Подсказка под строкой настроек.
struct SettingsHint: View {
    let text: String
    var color: Color = .white

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "info.circle")
                .font(.system(size: 11))
            Text(text)
                .font(.system(size: 11))
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(color.opacity(0.75))
    }
}
