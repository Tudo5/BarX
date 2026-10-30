//
//  BarXActionButton.swift
//  BarX
//
//  Кнопка действия в меню с анимациями наведения и «подсветкой» акцента.
//

import SwiftUI
import AppKit
import Combine

// MARK: - BarXActionButton

struct BarXActionButton: View {
    let icon: String
    let title: String
    var shortcut: String? = nil
    var accent: Color? = nil
    var isSpinning: Bool = false
    let action: () -> Void

    @State private var isHovered = false
    @StateObject private var animations = AnimationCenter.shared

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .frame(width: 20)
                    .adaptiveTextColor()
                    .foregroundStyle(accent ?? .white)
                    .rotationEffect(.degrees(isSpinning ? 360 : 0))
                    .animation(
                        isSpinning ? .linear(duration: 1).repeatForever(autoreverses: false) : animations.hover,
                        value: isSpinning
                    )

                Text(title)
                    .adaptiveTextColor()

                Spacer()

                if let shortcut, !shortcut.isEmpty {
                    Text(shortcut)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .adaptiveTextColor()
                        .opacity(0.65)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(Color.white.opacity(isHovered ? 0.16 : 0.1))
                        )
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .adaptiveTextColor()
                    .opacity(isHovered ? 0.7 : 0)
                    .offset(x: isHovered ? 0 : -4)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        isHovered
                            ? (accent ?? .white).opacity(0.14)
                            : Color.clear
                    )
            )
            .overlay(alignment: .leading) {
                Capsule()
                    .fill(accent ?? .clear)
                    .frame(width: 2, height: isHovered ? 18 : 0)
                    .padding(.leading, 4)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(animations.hover) { isHovered = hovering }
            if hovering { NSCursor.pointingHand.set() }
        }
    }
}
