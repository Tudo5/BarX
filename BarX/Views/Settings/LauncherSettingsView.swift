//
//  LauncherSettingsView.swift
//  BarX
//
//  Раздел «Launcher»: горячая клавиша, поведение окна и сведения.
//

import SwiftUI
import AppKit
import Combine

// MARK: - LauncherSettingsView

struct LauncherSettingsView: View {
    @StateObject private var launcherManager = LauncherManager.shared

    @AppStorage("launcherAtCursor") private var atCursor = false
    @AppStorage("launcherShowPanelApps") private var showPanelApps = true
    @AppStorage("launcherShowDetails") private var showDetails = true
    @AppStorage("launcherMaxResults") private var maxResults = 40

    @State private var toast: String?

    @StateObject private var animations = AnimationCenter.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerView
            mainSection
            behaviorSection
            if let toast {
                SettingsHint(text: toast, color: .green)
                    .transition(.opacity)
            }
        }
        .padding(.vertical, 4)
        .animation(animations.spring, value: toast)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            // Заставляем SwiftUI перечитать статус регистрации
            launcherManager.objectWillChange.send()
        }
        .onReceive(NotificationCenter.default.publisher(for: .launcherDidChange)) { _ in
            launcherManager.objectWillChange.send()
        }
    }

    // MARK: - Шапка

    private var headerView: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Launcher")
                    .font(.headline)
                    .adaptiveTextColor()
                Text("Быстрый поиск и запуск приложений из любого места")
                    .font(.caption)
                    .adaptiveTextColor()
                    .opacity(0.65)
            }
            Spacer()
            Button {
                launcherManager.toggleLauncher()
            } label: {
                Label("Открыть", systemImage: "arrow.up.forward.app")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.bordered)
            .tint(.white)
            .controlSize(.small)
            .disabled(!launcherManager.launcherEnabled)
        }
    }

    // MARK: - Основное

    private var mainSection: some View {
        SettingsCard(title: "Запуск", icon: "magnifyingglass") {
            Toggle("Включить Launcher", isOn: $launcherManager.launcherEnabled)
                .toggleStyle(SwitchToggleStyle(tint: .white))
                .adaptiveTextColor()

            if launcherManager.launcherEnabled {
                HStack {
                    Text("Горячая клавиша")
                        .adaptiveTextColor()
                        .opacity(0.7)
                    Spacer()
                    HotkeyRecorder(hotkey: $launcherManager.launcherHotkeyKey) { _ in
                        launcherManager.restartHotkeys()
                        showToast("Комбинация обновлена")
                    }
                }

                if let conflict = HotkeyManager.shared.conflicts.first {
                    SettingsHint(
                        text: "Комбинация \(conflict) занята системой или другим приложением — выберите другую.",
                        color: .yellow
                    )
                }

                registrationStatus
            } else {
                SettingsHint(text: "Launcher выключен: горячая клавиша не работает, окно не открывается.")
            }
        }
    }

    /// Раньше здесь была строка про «Универсальный доступ». Комбинация теперь
    /// регистрируется через Carbon RegisterEventHotKey, которому доступ не нужен,
    /// поэтому полезнее показывать, удалось ли зарегистрировать её реально.
    private var registrationStatus: some View {
        let isLive = HotkeyManager.shared.isRegistered

        return VStack(alignment: .leading, spacing: 6) {
            Divider().background(Color.white.opacity(0.2))

            HStack(spacing: 8) {
                Image(systemName: isLive ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                    .foregroundStyle(isLive ? .green : .yellow)
                VStack(alignment: .leading, spacing: 1) {
                    Text(isLive ? "Комбинация активна" : "Комбинация не зарегистрирована")
                        .font(.system(size: 12, weight: .medium))
                        .adaptiveTextColor()
                    Text("Перехватывается системой и работает из любого приложения. Дополнительные разрешения не требуются.")
                        .font(.system(size: 10))
                        .adaptiveTextColor()
                        .opacity(0.55)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Button("Проверить") {
                    launcherManager.restartHotkeys()
                    showToast(HotkeyManager.shared.isRegistered
                              ? "Комбинация работает"
                              : "Не удалось зарегистрировать — возможно, занята")
                }
                .buttonStyle(.bordered)
                .tint(.white)
                .controlSize(.small)
            }
        }
    }

    // MARK: - Поведение

    private var behaviorSection: some View {
        SettingsCard(title: "Поведение окна", icon: "macwindow") {
            Toggle("Открывать рядом с курсором", isOn: $atCursor)
                .toggleStyle(SwitchToggleStyle(tint: .white))
                .adaptiveTextColor()

            Toggle("Показывать приложения панели Bar при пустом поиске", isOn: $showPanelApps)
                .toggleStyle(SwitchToggleStyle(tint: .white))
                .adaptiveTextColor()

            Toggle("Показывать панель сведений", isOn: $showDetails)
                .toggleStyle(SwitchToggleStyle(tint: .white))
                .adaptiveTextColor()
                .help("Справа от списка: размер, путь и быстрые действия")

            Stepper(value: $maxResults, in: 10...80, step: 5) {
                SettingsInfoRow(label: "Максимум результатов", value: "\(maxResults)")
            }
            .adaptiveTextColor()

            HStack(spacing: 8) {
                Button {
                    launcherManager.resetWindowPosition()
                    showToast("Позиция окна сброшена")
                } label: {
                    Label("Сбросить позицию окна", systemImage: "arrow.counterclockwise")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.bordered)
                .tint(.white)
                .controlSize(.small)

                Button {
                    launcherManager.resetWindowSize()
                    showToast("Размер окна сброшен")
                } label: {
                    Label("Сбросить размер", systemImage: "rectangle.compress.vertical")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.bordered)
                .tint(.white)
                .controlSize(.small)

                Spacer()
            }

            LauncherPreviewMock(
                hotkey: launcherManager.launcherHotkeyKey,
                showDetails: showDetails,
                accent: Color(hex: BarXSettings.appearanceAccent)
            )
            .frame(height: 104)

            SettingsHint(text: "Подсказки в окне: ↑ ↓ — выбор, Return — запуск, Esc — закрыть.")
        }
    }

    private func showToast(_ message: String) {
        withAnimation(animations.spring) { toast = message }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(animations.hover) {
                if toast == message { toast = nil }
            }
        }
    }
}

// MARK: - LauncherPreviewMock

struct LauncherPreviewMock: View {
    let hotkey: String
    let showDetails: Bool
    let accent: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.25))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )

            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 10))
                        .opacity(0.6)
                    Text("Поиск приложений…")
                        .font(.system(size: 10))
                        .opacity(0.45)
                    Spacer()
                    Text(KeyCodeHelper.normalizeHotkey(hotkey))
                        .font(.system(size: 8, design: .monospaced))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.1)))
                        .opacity(0.6)
                }
                .adaptiveTextColor()
                .padding(.horizontal, 8)

                HStack(spacing: 0) {
                    VStack(spacing: 2) {
                        ForEach(0..<3, id: \.self) { index in
                            HStack(spacing: 6) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.white.opacity(0.14))
                                    .frame(width: 16, height: 16)
                                Capsule()
                                    .fill(Color.white.opacity(index == 0 ? 0.35 : 0.2))
                                    .frame(width: index == 0 ? 56 : 40, height: 5)
                                Spacer()
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(index == 0 ? accent.opacity(0.25) : Color.clear)
                            )
                        }
                    }

                    if showDetails {
                        VStack(spacing: 3) {
                            RoundedRectangle(cornerRadius: 5)
                                .fill(Color.white.opacity(0.14))
                                .frame(width: 22, height: 22)
                            Capsule().fill(Color.white.opacity(0.2)).frame(width: 30, height: 4)
                            Capsule().fill(Color.white.opacity(0.14)).frame(width: 24, height: 4)
                        }
                        .frame(width: 44)
                    }
                }
            }
            .padding(8)
        }
    }
}
