//
//  LauncherManager.swift
//  BarX
//
//  Окно Launcher, поиск и запуск приложений
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers
import Combine
import ServiceManagement
import UserNotifications
import ApplicationServices

// MARK: - LauncherManager

class LauncherManager: ObservableObject {
    static let shared = LauncherManager()
    
    private static let launcherEnabledKey = "launcherEnabled"
    
    @Published var isLauncherVisible = false
    @Published var searchText = ""
    @Published var filteredApps: [AppItem] = []
    @Published var selectedIndex = 0
    /// Настройка сохраняется в UserDefaults и переживает перезапуск.
    @Published var launcherEnabled: Bool {
        didSet {
            guard oldValue != launcherEnabled else { return }
            UserDefaults.standard.set(launcherEnabled, forKey: Self.launcherEnabledKey)
            if launcherEnabled {
                setupHotkeys()
            } else {
                hideLauncher()
                cleanup()
            }
        }
    }
    
    private var hotkeyManager = HotkeyManager.shared
    private var appState = AppStateManager.shared
    private var launcherWindow: NSWindow?
    /// Делегат окна нужно удерживать: NSWindow.delegate — слабая ссылка.
    private var windowDelegate: LauncherWindowDelegate?
    private var isSetup = false
    private var localMonitor: Any?
    
    @AppStorage("launcherHotkeyKey") var launcherHotkeyKey: String = "⌘ ⇧ B"
    @AppStorage("launcherWindowWidth") var windowWidth: Double = 500
    @AppStorage("launcherWindowHeight") var windowHeight: Double = 80
    @AppStorage("launcherWindowX") var windowX: Double = 0
    @AppStorage("launcherWindowY") var windowY: Double = 0
    /// Позиция сохранена (0 и отрицательные координаты — тоже валидные).
    @AppStorage("launcherHasPosition") var hasSavedPosition: Bool = false
    
    init() {
        launcherEnabled = UserDefaults.standard.object(forKey: Self.launcherEnabledKey) as? Bool ?? true
        if launcherEnabled {
            setupHotkeys()
        }
    }
    
    /// Перезапуск регистрации горячей клавиши (после смены комбинации
    /// или импорта настроек).
    func restartHotkeys() {
        cleanup()
        if launcherEnabled {
            setupHotkeys()
        }
    }
    
    func setupHotkeys() {
        guard launcherEnabled else { return }
        guard !isSetup else { return }
        
        isSetup = true
        
        // Приводим сохранённую комбинацию к каноническому виду и отбрасываем
        // некорректные значения (например, одиночную букву без модификаторов)
        let normalized = KeyCodeHelper.normalizeHotkey(launcherHotkeyKey)
        if normalized != launcherHotkeyKey {
            launcherHotkeyKey = normalized
        }
        if !KeyCodeHelper.isUsableHotkey(launcherHotkeyKey) {
            launcherHotkeyKey = "⌘ ⇧ B"
        }
        
        // Регистрация идёт через Carbon RegisterEventHotKey, а не через
        // NSEvent-монитор: монитор лишь наблюдал за клавишами и не мог
        // перехватить их, поэтому комбинация уходила в активное приложение.
        hotkeyManager.onHotkeyPressed = { [weak self] in
            self?.toggleLauncher()
        }
        hotkeyManager.registerHotkey(launcherHotkeyKey)
    }
    
    func cleanup() {
        isSetup = false
        hotkeyManager.onHotkeyPressed = nil
        hotkeyManager.cleanup()
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }
    
    func toggleLauncher() {
        if isLauncherVisible {
            hideLauncher()
        } else {
            showLauncher()
        }
    }
    
    func showLauncher() {
        guard launcherEnabled else { return }
        
        if let window = launcherWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate()
            isLauncherVisible = true
            return
        }
        
        // Уничтожаем устаревшее окно, иначе оно утечёт
        if let staleWindow = launcherWindow {
            staleWindow.delegate = nil
            staleWindow.close()
            launcherWindow = nil
            windowDelegate = nil
        }
        
        isLauncherVisible = true
        searchText = ""
        selectedIndex = 0
        updateFilteredApps()
        
        let hostingController = NSHostingController(
            rootView: LauncherWindowView()
                .environmentObject(self)
                .environmentObject(appState)
                .environmentObject(ThemeManager.shared)
        )
        
        let contentSize = NSSize(
            width: max(320, windowWidth),
            height: max(60, windowHeight)
        )
        let window = NSWindow(contentViewController: hostingController)
        window.title = "BarX Launcher"
        window.styleMask = [.borderless, .fullSizeContentView, .closable, .resizable]
        window.isMovableByWindowBackground = true
        window.setContentSize(contentSize)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.hasShadow = true
        window.isReleasedWhenClosed = false
        
        window.setFrame(launcherFrame(for: contentSize), display: true)
        
        let delegate = LauncherWindowDelegate { [weak self] in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isLauncherVisible = false
                if let monitor = self.localMonitor {
                    NSEvent.removeMonitor(monitor)
                    self.localMonitor = nil
                }
                self.saveLauncherFrame()
            }
        }
        windowDelegate = delegate
        window.delegate = delegate
        
        launcherWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
        
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
        
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            // Не перехватываем клавиши в других окнах BarX (например, в Настройках)
            guard event.window === self.launcherWindow else { return event }
            
            switch event.keyCode {
            case 53:
                self.hideLauncher()
                return nil
            case 36:
                self.executeSelected()
                return nil
            case 126:
                if !self.filteredApps.isEmpty {
                    self.selectedIndex = max(0, self.selectedIndex - 1)
                }
                return nil
            case 125:
                if !self.filteredApps.isEmpty {
                    self.selectedIndex = min(self.filteredApps.count - 1, self.selectedIndex + 1)
                }
                return nil
            default:
                return event
            }
        }
    }
    
    /// Позиция окна Launcher: у курсора, в сохранённом месте или по центру экрана.
    private func launcherFrame(for size: NSSize) -> NSRect {
        if BarXSettings.launcherAtCursor {
            let mouse = NSEvent.mouseLocation
            let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
            if let visible = screen?.visibleFrame {
                let x = min(max(visible.minX + 8, mouse.x - size.width / 2), visible.maxX - size.width - 8)
                let y = min(max(visible.minY + 8, mouse.y - size.height / 2), visible.maxY - size.height - 8)
                return NSRect(x: x, y: y, width: size.width, height: size.height)
            }
        }
        
        if hasSavedPosition {
            return NSRect(x: windowX, y: windowY, width: size.width, height: size.height)
        }
        
        if let screen = NSScreen.main {
            let visible = screen.visibleFrame
            let x = visible.minX + (visible.width - size.width) / 2
            let y = visible.minY + (visible.height - size.height) / 2 + 100
            windowX = x
            windowY = y
            hasSavedPosition = true
            return NSRect(x: x, y: y, width: size.width, height: size.height)
        }
        
        return NSRect(origin: .zero, size: size)
    }
    
    /// Сбрасывает сохранённую позицию — окно снова откроется по центру.
    func resetWindowPosition() {
        hasSavedPosition = false
        windowX = 0
        windowY = 0
    }
    
    /// Сбрасывает размер окна Launcher к значениям по умолчанию.
    func resetWindowSize() {
        windowWidth = 500
        windowHeight = 80
        if let window = launcherWindow {
            let size = NSSize(width: 500, height: max(60, windowHeight))
            window.setContentSize(size)
            window.setFrame(launcherFrame(for: size), display: true)
        }
    }
    
    private func saveLauncherFrame() {
        guard let window = launcherWindow else { return }
        let frame = window.frame
        windowX = frame.origin.x
        windowY = frame.origin.y
        windowWidth = frame.width
        windowHeight = frame.height
        hasSavedPosition = true
    }
    
    func hideLauncher() {
        isLauncherVisible = false
        launcherWindow?.orderOut(nil)
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
        saveLauncherFrame()
    }
    
    func closeLauncher() {
        hideLauncher()
        launcherWindow?.delegate = nil
        launcherWindow?.close()
        launcherWindow = nil
        windowDelegate = nil
    }
    
    func updateFilteredApps() {
        var apps: [AppItem]
        
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            apps = []
            if BarXSettings.launcherShowPanelApps {
                apps.append(contentsOf: appState.barApps)
            }
            apps.append(contentsOf: appState.pinnedApps)
            apps.append(contentsOf: appState.recentApps)
        } else {
            apps = appState.installedApps.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.path.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Дедупликация по пути: UUID у просканированных приложений каждый раз новый
        var seenPaths = Set<String>()
        var seenIds = Set<UUID>()
        let unique = apps.filter { app in
            if !app.path.isEmpty {
                return seenPaths.insert(app.path.lowercased()).inserted
            }
            return seenIds.insert(app.id).inserted
        }
        
        // Ограничение количества результатов из настроек Launcher
        let limit = max(1, BarXSettings.launcherMaxResults)
        filteredApps = unique.count > limit ? Array(unique.prefix(limit)) : unique
        
        if selectedIndex >= filteredApps.count {
            selectedIndex = max(0, filteredApps.count - 1)
        }
    }
    
    func executeSelected() {
        guard filteredApps.indices.contains(selectedIndex) else { return }
        let app = filteredApps[selectedIndex]
        launchApp(app, hideLauncherAfterwards: true)
    }
    
    /// Единая точка запуска приложения: открыть, запомнить, уведомить.
    func launchApp(_ app: AppItem, hideLauncherAfterwards: Bool = false) {
        openApp(app)
        markLaunched(app)
        addRecentApp(app)
        NotificationHelper.shared.notifyAppLaunched(app)
        if hideLauncherAfterwards {
            hideLauncher()
        }
    }

    /// Записывает статистику запуска. Раньше `launchCount` и `lastLaunched`
    /// были только в модели и никогда не обновлялись — из-за этого
    /// сортировка «по последнему запуску» и панель сведений не работали.
    private func markLaunched(_ app: AppItem) {
        appState.recordLaunch(of: app)
    }

    func openApp(_ app: AppItem) {
        // Единая точка исполнения: приложения, папки, ссылки, а также
        // действия (shell, AppleScript, Shortcuts, deep links). Раньше тут
        // была только «открыть файл/ссылку», а `case .action` молчал.
        let outcome = ActionExecutor.execute(app)
        if case .failure(let reason) = outcome {
            Log.error("Ошибка исполнения \(app.name): \(reason)")
            DispatchQueue.main.async { [weak self] in
                self?.showLaunchError(for: app, reason: reason)
            }
        }
    }
    
    private func showLaunchError(for app: AppItem, reason: String? = nil) {
        let alert = NSAlert()
        alert.messageText = "Не удалось открыть приложение"
        if let reason {
            alert.informativeText = reason
        } else {
            alert.informativeText = "BarX не смог открыть:\n\(app.name)\n\nВозможно приложение было удалено или перемещено."
        }
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Удалить из BarX")
        
        // Без activate() алерт в меню-баре уходит за окна других приложений
        NSApp.activate()
        let response = alert.runModal()
        if response == .alertSecondButtonReturn {
            appState.removeFromBar(app)
            appState.pinnedApps.removeAll { AppStateManager.isSameApp($0, app) }
            appState.savePinnedApps()
            appState.recentApps.removeAll { AppStateManager.isSameApp($0, app) }
            appState.saveRecentApps()
            appState.objectWillChange.send()
        }
    }
    
    func addRecentApp(_ app: AppItem) {
        appState.addRecentApp(app)
    }
}

// MARK: - LauncherWindowDelegate

class LauncherWindowDelegate: NSObject, NSWindowDelegate {
    private let onClose: () -> Void
    
    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
        super.init()
    }
    
    func windowWillClose(_ notification: Notification) {
        onClose()
    }
}
