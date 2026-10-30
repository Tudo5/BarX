//
//  GeneralSettingsView.swift
//  BarX
//
//  Раздел «Основные»
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers
import Combine
import ServiceManagement
import Sparkle
import UserNotifications
import ApplicationServices

struct GeneralSettingsView: View {
    // Запуск
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("showDockIcon") private var showDockIcon = false
    @AppStorage("autoCheckUpdates") private var autoCheckUpdates = true

    // Интерфейс
    @AppStorage("showAppIcons") private var showAppIcons = true
    @AppStorage("showPresetCount") private var showPresetCount = true
    @AppStorage("hideMenuAfterLaunch") private var hideMenuAfterLaunch = true
    @AppStorage("animationSpeed") private var animationSpeed: Double = 0.3

    // Панель Bar
    @AppStorage("barAppsPerPage") private var barAppsPerPage = 5
    @AppStorage("maxRecentApps") private var maxRecentApps = 10

    // Launcher
    @AppStorage("launcherAtCursor") private var launcherAtCursor = false
    @AppStorage("launcherShowPanelApps") private var launcherShowPanelApps = true

    // Уведомления
    @AppStorage("showNotifications") private var showNotifications = true

    // Обновление списка приложений
    @AppStorage("autoRefreshApps") private var autoRefreshApps = true
    @AppStorage("autoRefreshInterval") private var autoRefreshInterval: Double = 30

    @EnvironmentObject var appState: AppStateManager
    @StateObject private var launcherManager = LauncherManager.shared
    @StateObject private var updateManager = BarXUpdateManager.shared

    @State private var loginItemError: String?
    /// Токен перерисовки: инкремент заставляет перечитать статус регистрации.
    @State private var hotkeyCheckToken = 0
    @State private var notificationMessage: String?
    @State private var backupMessage: String?
    @State private var showingResetSettingsAlert = false
    @State private var showingResetDataAlert = false
    @State private var barLimitMessage: String?

    /// Горячая клавиша реально зарегистрирована в системе.
    private var hotkeyIsLive: Bool {
        _ = hotkeyCheckToken
        return launcherManager.launcherEnabled && HotkeyManager.shared.isRegistered
    }

    /// Значение ступеньки, обрезанное до максимума строки панели.
    private var clampedBarAppsPerPage: Int {
        min(barAppsPerPage, BarXSettings.maxBarAppsPerPage)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Основные настройки")
                .font(.headline)
                .adaptiveTextColor()

            startupSection
            interfaceSection
            barSection
            launcherSection
            notificationSection
            refreshSection
            dataSection
        }
        .padding(.vertical, 4)
        .onAppear {
            syncLaunchAtLoginState()
            normalizeBarSettings()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            // Перечитываем статус: пользователь мог изменить системные настройки
            launcherManager.objectWillChange.send()
        }
    }

    // MARK: - Запуск

    private var startupSection: some View {
        SettingsCard(title: "Запуск", icon: "power") {
            Toggle("Запускать BarX вместе с macOS", isOn: Binding(
                get: { launchAtLogin },
                set: { newValue in
                    do {
                        try LoginItemManager.setEnabled(newValue)
                        launchAtLogin = newValue
                        loginItemError = nil
                    } catch {
                        loginItemError = error.localizedDescription
                        launchAtLogin = LoginItemManager.isEnabled
                    }
                }
            ))
            .toggleStyle(SwitchToggleStyle(tint: .white))
            .adaptiveTextColor()

            SettingsInfoRow(label: "Состояние автозапуска", value: LoginItemManager.statusDescription)

            if let loginItemError {
                SettingsHint(text: "Не удалось изменить автозапуск: \(loginItemError)", color: .red)
            } else {
                SettingsHint(text: "BarX запускается вместе с системой и сразу доступен в строке меню.")
            }

            Divider().background(Color.white.opacity(0.2))

            Toggle("Показывать значок BarX в Dock", isOn: $showDockIcon)
                .toggleStyle(SwitchToggleStyle(tint: .white))
                .adaptiveTextColor()
                .onChange(of: showDockIcon) { _, _ in
                    AppEnvironment.applyDockIconSetting()
                }

            Toggle("Автоматически проверять обновления при запуске", isOn: $autoCheckUpdates)
                .toggleStyle(SwitchToggleStyle(tint: .white))
                .adaptiveTextColor()
                .onChange(of: autoCheckUpdates) { _, value in
                    BarXUpdateManager.shared.updater.automaticallyChecksForUpdates = value
                }

            HStack {
                Button {
                    updateManager.checkForUpdates()
                } label: {
                    HStack(spacing: 6) {
                        if updateManager.isChecking {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "arrow.down.circle")
                        }
                        Text(updateManager.isChecking ? "Проверка…" : "Проверить обновления сейчас")
                    }
                    .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.bordered)
                .tint(.white)
                .controlSize(.small)
                .disabled(updateManager.isChecking)

                Spacer()
            }
        }
    }

    // MARK: - Интерфейс

    private var interfaceSection: some View {
        SettingsCard(title: "Интерфейс", icon: "paintbrush") {
            Toggle("Показывать значки приложений", isOn: $showAppIcons)
                .toggleStyle(SwitchToggleStyle(tint: .white))
                .adaptiveTextColor()

            Toggle("Показывать количество элементов в папках", isOn: $showPresetCount)
                .toggleStyle(SwitchToggleStyle(tint: .white))
                .adaptiveTextColor()

            Toggle("Скрывать меню после запуска приложения", isOn: $hideMenuAfterLaunch)
                .toggleStyle(SwitchToggleStyle(tint: .white))
                .adaptiveTextColor()

            Divider().background(Color.white.opacity(0.2))

            VStack(alignment: .leading, spacing: 6) {
                SettingsInfoRow(label: "Скорость анимации", value: String(format: "%.2f с", animationSpeed))
                Slider(value: $animationSpeed, in: 0.1...0.8, step: 0.05)
                    .tint(.white)
                HStack {
                    Text("Медленно").font(.caption2).adaptiveTextColor().opacity(0.5)
                    Spacer()
                    Button("Сбросить") { animationSpeed = 0.3 }
                        .buttonStyle(.plain)
                        .font(.caption2)
                        .adaptiveTextColor()
                        .opacity(0.7)
                    Spacer()
                    Text("Быстро").font(.caption2).adaptiveTextColor().opacity(0.5)
                }
            }
        }
    }

    // MARK: - Панель Bar

    private var barSection: some View {
        SettingsCard(title: "Панель Bar", icon: "menubar.rectangle") {
            // Диапазон на единицу шире максимума строки: при попытке поставить
            // больше значение остаётся прежним, а пользователь видит сообщение.
            Stepper(value: Binding(
                get: { clampedBarAppsPerPage },
                set: { newValue in
                    if newValue > BarXSettings.maxBarAppsPerPage {
                        barLimitMessage = "В одну строку не помещается больше \(BarXSettings.maxBarAppsPerPage) приложений — можно только уменьшить."
                    } else {
                        barLimitMessage = nil
                        barAppsPerPage = newValue
                    }
                }
            ), in: 3...(BarXSettings.maxBarAppsPerPage + 1)) {
                SettingsInfoRow(label: "Приложений в строке панели", value: "\(clampedBarAppsPerPage)")
            }
            .adaptiveTextColor()

            if let barLimitMessage {
                SettingsHint(text: barLimitMessage, color: .orange)
            } else if clampedBarAppsPerPage >= BarXSettings.maxBarAppsPerPage {
                SettingsHint(text: "Достигнут максимум строки — \(BarXSettings.maxBarAppsPerPage) приложения. Остальные уедут на следующую страницу (листание).")
            }

            Stepper(value: $maxRecentApps, in: 3...30, step: 1) {
                SettingsInfoRow(label: "Хранить недавних приложений", value: "\(maxRecentApps)")
            }
            .adaptiveTextColor()
            .onChange(of: maxRecentApps) { _, _ in
                appState.trimRecentApps()
            }

            SettingsInfoRow(label: "Сейчас в панели", value: "\(appState.barApps.count)")

            if appState.barApps.count > BarXSettings.maxBarApps {
                SettingsHint(
                    text: "В панели \(appState.barApps.count) приложений — больше \(BarXSettings.maxBarApps) не помещается. Уберите лишние, новые добавить нельзя.",
                    color: .orange
                )
            }

            Button {
                appState.clearRecentApps()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "clock.arrow.circlepath")
                    Text("Очистить недавние (\(appState.recentApps.count))")
                }
                .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.bordered)
            .tint(.white)
            .controlSize(.small)
            .disabled(appState.recentApps.isEmpty)
        }
    }

    // MARK: - Launcher

    private var launcherSection: some View {
        SettingsCard(title: "Launcher", icon: "magnifyingglass") {
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
                    }
                }

                Toggle("Открывать рядом с курсором", isOn: $launcherAtCursor)
                    .toggleStyle(SwitchToggleStyle(tint: .white))
                    .adaptiveTextColor()

                Toggle("Показывать приложения панели Bar при пустом поиске", isOn: $launcherShowPanelApps)
                    .toggleStyle(SwitchToggleStyle(tint: .white))
                    .adaptiveTextColor()

                Divider().background(Color.white.opacity(0.2))

                // Комбинация перехватывается системой (RegisterEventHotKey),
                // поэтому «Универсальный доступ» больше не требуется.
                // Показываем реальный статус регистрации.
                HStack(spacing: 8) {
                    Image(systemName: hotkeyIsLive ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                        .foregroundStyle(hotkeyIsLive ? .green : .yellow)
                    Text(hotkeyIsLive
                         ? "Горячая клавиша зарегистрирована в системе"
                         : "Комбинация не зарегистрирована")
                        .font(.system(size: 12))
                        .adaptiveTextColor()
                        .opacity(0.8)
                    Spacer()
                    Button("Проверить") {
                        LauncherManager.shared.restartHotkeys()
                        hotkeyCheckToken += 1
                    }
                    .buttonStyle(.bordered)
                    .tint(.white)
                    .controlSize(.small)
                }

                SettingsHint(text: launcherManager.launcherHotkeyKey.isEmpty
                             ? "Назначьте комбинацию, чтобы открывать Launcher из любого приложения."
                             : "Нажмите комбинацию \(KeyCodeHelper.normalizeHotkey(launcherManager.launcherHotkeyKey)), чтобы открыть Launcher.")
            }
        }
    }

    // MARK: - Уведомления

    private var notificationSection: some View {
        SettingsCard(title: "Уведомления", icon: "bell") {
            Toggle("Показывать уведомления", isOn: Binding(
                get: { showNotifications },
                set: { newValue in
                    showNotifications = newValue
                    if newValue {
                        NotificationHelper.shared.requestAuthorizationIfNeeded { granted in
                            notificationMessage = granted
                                ? "Уведомления разрешены"
                                : "macOS не выдала разрешение. Включите его в «Системных настройках» → «Уведомления» → BarX."
                        }
                    } else {
                        notificationMessage = nil
                    }
                }
            ))
            .toggleStyle(SwitchToggleStyle(tint: .white))
            .adaptiveTextColor()

            HStack {
                Button("Проверить уведомление") {
                    sendTestNotification()
                }
                .buttonStyle(.bordered)
                .tint(.white)
                .controlSize(.small)
                .disabled(!showNotifications)

                Spacer()
            }

            if let notificationMessage {
                SettingsHint(text: notificationMessage)
            } else {
                SettingsHint(text: "BarX сообщает о запуске приложения и о выходе новой версии.")
            }
        }
    }

    // MARK: - Обновление списка приложений

    private var refreshSection: some View {
        SettingsCard(title: "Список приложений", icon: "arrow.clockwise") {
            Toggle("Автоматически обновлять список приложений", isOn: $autoRefreshApps)
                .toggleStyle(SwitchToggleStyle(tint: .white))
                .adaptiveTextColor()

            if autoRefreshApps {
                Picker("Интервал проверки", selection: $autoRefreshInterval) {
                    Text("15 минут").tag(15.0)
                    Text("30 минут").tag(30.0)
                    Text("1 час").tag(60.0)
                    Text("3 часа").tag(180.0)
                    Text("6 часов").tag(360.0)
                }
                .pickerStyle(.menu)
                .tint(.white)
                .adaptiveTextColor()
            }

            SettingsInfoRow(label: "Найдено приложений", value: "\(appState.installedApps.count)")
            SettingsInfoRow(label: "Последнее сканирование", value: lastScanText)

            HStack {
                Button {
                    appState.refreshApps()
                } label: {
                    HStack(spacing: 6) {
                        if appState.isLoading {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                        Text(appState.isLoading ? "Сканирование…" : "Обновить сейчас")
                    }
                    .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.bordered)
                .tint(.white)
                .controlSize(.small)
                .disabled(appState.isLoading)

                Spacer()
            }
        }
    }

    // MARK: - Данные

    private var dataSection: some View {
        SettingsCard(title: "Данные и сброс", icon: "externaldrive") {
            SettingsInfoRow(label: "Папок", value: "\(appState.presets.count)")
            SettingsInfoRow(label: "Элементов в папках", value: "\(appState.statistics.items)")

            Divider().background(Color.white.opacity(0.2))

            HStack(spacing: 8) {
                Button("Экспортировать…") { exportSettings() }
                    .buttonStyle(.bordered)
                    .tint(.white)
                    .controlSize(.small)

                Button("Импортировать…") { importSettings() }
                    .buttonStyle(.bordered)
                    .tint(.white)
                    .controlSize(.small)

                Spacer()
            }

            if let backupMessage {
                SettingsHint(text: backupMessage)
            }

            Divider().background(Color.white.opacity(0.2))

            HStack(spacing: 8) {
                Button("Сбросить настройки") {
                    showingResetSettingsAlert = true
                }
                .buttonStyle(.bordered)
                .tint(.orange)
                .controlSize(.small)
                .alert("Сбросить настройки?", isPresented: $showingResetSettingsAlert) {
                    Button("Отмена", role: .cancel) { }
                    Button("Сбросить", role: .destructive) { resetSettings() }
                } message: {
                    Text("Все параметры раздела «Основные», внешнего вида и Launcher вернутся к значениям по умолчанию. Приложения, папки и темы сохранятся.")
                }

                Button("Удалить все данные") {
                    showingResetDataAlert = true
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .controlSize(.small)
                .alert("Удалить все данные BarX?", isPresented: $showingResetDataAlert) {
                    Button("Отмена", role: .cancel) { }
                    Button("Удалить", role: .destructive) { resetAllData() }
                } message: {
                    Text("Будут удалены панель Bar, недавние приложения, все папки и свои темы. Это действие нельзя отменить.")
                }

                Spacer()
            }
        }
    }

    // MARK: - Действия

    private var lastScanText: String {
        guard let date = appState.lastScanDate else { return "ещё не выполнялось" }
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }

    /// Синхронизирует тумблер автозапуска с реальным состоянием системы.
    private func syncLaunchAtLoginState() {
        let actual = LoginItemManager.isEnabled
        if launchAtLogin != actual {
            launchAtLogin = actual
        }
    }

    /// Приводит старые значения панели к текущему лимиту строки
    /// (`BarXSettings.maxBarAppsPerPage` приложений в строке).
    private func normalizeBarSettings() {
        if barAppsPerPage > BarXSettings.maxBarAppsPerPage {
            barAppsPerPage = BarXSettings.maxBarAppsPerPage
        }
    }

    private func sendTestNotification() {
        NotificationHelper.shared.requestAuthorizationIfNeeded { granted in
            guard granted else {
                notificationMessage = "macOS не выдала разрешение. Включите его в «Системных настройках» → «Уведомления» → BarX."
                return
            }
            NotificationHelper.shared.notify(title: "BarX", body: "Уведомления работают 🎉")
            notificationMessage = "Тестовое уведомление отправлено"
        }
    }

    private func exportSettings() {
        let panel = NSSavePanel()
        panel.title = "Экспорт настроек BarX"
        panel.nameFieldStringValue = BarXBackup.suggestedFileName
        panel.allowsOtherFileTypes = true
        panel.canCreateDirectories = true

        NSApp.activate()
        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let data = try BarXBackup.exportData()
            try data.write(to: url, options: .atomic)
            backupMessage = "Сохранено: \(url.lastPathComponent)"
        } catch {
            backupMessage = "Ошибка экспорта: \(error.localizedDescription)"
        }
    }

    private func importSettings() {
        let panel = NSOpenPanel()
        panel.title = "Импорт настроек BarX"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false

        NSApp.activate()
        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let data = try Data(contentsOf: url)
            let applied = try BarXBackup.importData(data)
            AppEnvironment.reloadEverything()
            syncLaunchAtLoginState()
            hotkeyCheckToken += 1
            backupMessage = "Импортировано параметров: \(applied)"
        } catch {
            backupMessage = "Ошибка импорта: \(error.localizedDescription)"
        }
    }

    /// Сброс только настроек — данные пользователя не трогаем.
    private func resetSettings() {
        BarXSettings.resetToDefaults()

        AppEnvironment.applyDockIconSetting()
        LauncherManager.shared.restartHotkeys()
        ThemeManager.shared.reloadThemes()

        syncLaunchAtLoginState()
        hotkeyCheckToken += 1
        backupMessage = "Настройки сброшены к значениям по умолчанию"
    }

    /// Полное удаление данных BarX (панель, недавние, папки, свои темы, закладки).
    private func resetAllData() {
        BarXBackup.eraseAllData()

        appState.barApps = []
        appState.recentApps = []
        appState.pinnedApps = []
        appState.presets = []
        appState.saveAllState()

        ThemeManager.shared.reloadThemes()
        if let first = ThemeManager.shared.themes.first {
            ThemeManager.shared.selectTheme(first, applyImmediately: true)
        }

        appState.scanInstalledApps()
        backupMessage = "Все данные BarX удалены"
    }
}
