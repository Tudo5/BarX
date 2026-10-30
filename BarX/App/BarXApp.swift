//
//  BarXApp.swift
//  BarX
//
//  Точка входа, делегат приложения и уведомления
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers
import Combine
import ServiceManagement
import UserNotifications
import ApplicationServices

// MARK: - Расширения Notification

extension Notification.Name {
    static let presetsDidChange = Notification.Name("presetsDidChange")
    static let themeDidChange = Notification.Name("themeDidChange")
    static let appListDidChange = Notification.Name("appListDidChange")
    static let launcherDidChange = Notification.Name("launcherDidChange")
    static let barItemsDidChange = Notification.Name("barItemsDidChange")
}

// MARK: - BarXApp - Точка входа

@main
struct BarXApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppStateManager.shared
    
    var body: some Scene {
        MenuBarExtra {
            BarXMenuView()
                .environmentObject(appState)
        } label: {
            Image(systemName: "sparkles")
        }
        .menuBarExtraStyle(.window)
    }
}

// MARK: - AppDelegate

class AppDelegate: NSObject, NSApplicationDelegate {
    private let appState = AppStateManager.shared
    private var refreshTimer: Timer?
    private var autoUpdateWorkItem: DispatchWorkItem?
    private var refreshWorkItem: DispatchWorkItem?
    
    func applicationWillFinishLaunching(_ notification: Notification) {
        // Настройки должны быть зарегистрированы до первого чтения @AppStorage
        BarXSettings.registerDefaults()
        // Иконка в Dock — по настройке (по умолчанию BarX работает как агент)
        AppEnvironment.applyDockIconSetting()
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Автозапуск: синхронизируем реальный статус системы с настройкой
        syncLaunchAtLoginStatus()
        
        // Состояние уже загружено в init AppStateManager — повторно не читаем.
        // Задержку перед настройкой убрали: раньше здесь стоял asyncAfter(0.3),
        // из-за чего горячая клавиша первые 300 мс не работала.
        if LauncherManager.shared.launcherEnabled {
            LauncherManager.shared.setupHotkeys()
        }
        startAutoRefreshTimer()
        scheduleAutoUpdateCheck()
        NotificationHelper.shared.requestAuthorizationIfNeeded()
        
        // Первый запуск: короткое приветствие с выбором приложений и темы.
        // Без него пользователь видел пустую панель и не понимал, зачем она.
        if !OnboardingState.isCompleted {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                BarXWindowManager.shared.showOnboarding()
            }
        }
        
        Log.info("BarX запущен (версия \(BarXUpdateManager.shared.currentVersionString))")
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        autoUpdateWorkItem?.cancel()
        refreshWorkItem?.cancel()
        refreshTimer?.invalidate()
        LauncherManager.shared.cleanup()
        appState.saveAllState()
    }
    
    func applicationDidBecomeActive(_ notification: Notification) {
        // При возврате к BarX обновляем список приложений (не чаще раза в минуту)
        guard BarXSettings.autoRefreshApps else { return }
        refreshWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard BarXSettings.autoRefreshApps else { return }
            self?.appState.refreshApps()
        }
        refreshWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 60, execute: work)
    }
    
    /// Реальная проверка автозапуска: пользователь мог удалить BarX из «Объектов входа».
    private func syncLaunchAtLoginStatus() {
        let actual = LoginItemManager.isEnabled
        if BarXSettings.launchAtLogin != actual {
            UserDefaults.standard.set(actual, forKey: "launchAtLogin")
        }
    }
    
    /// Периодическое автообновление списка приложений по настройке.
    private func startAutoRefreshTimer() {
        refreshTimer?.invalidate()
        guard BarXSettings.autoRefreshApps else { return }
        let interval = max(60, BarXSettings.autoRefreshIntervalMinutes * 60)
        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard BarXSettings.autoRefreshApps else { return }
            self?.appState.refreshApps()
            Log.debug("Автообновление списка приложений")
        }
        refreshTimer = timer
    }
    
    /// Проверка обновлений при запуске (если включено в настройках).
    private func scheduleAutoUpdateCheck() {
        guard BarXSettings.autoCheckUpdates else { return }
        let work = DispatchWorkItem {
            guard BarXSettings.autoCheckUpdates else { return }
            BarXUpdateManager.shared.checkForUpdates(silentIfNoUpdate: true)
        }
        autoUpdateWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: work)
    }
}
