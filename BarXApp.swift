// MARK: - BarXApp.swift - Основной файл (без UpdateManager)

import SwiftUI
import AppKit
import UniformTypeIdentifiers
import Combine
import ServiceManagement

// MARK: - Расширения Notification

extension Notification.Name {
    static let presetsDidChange = Notification.Name("presetsDidChange")
    static let themeDidChange = Notification.Name("themeDidChange")
    static let appListDidChange = Notification.Name("appListDidChange")
    static let launcherDidChange = Notification.Name("launcherDidChange")
    static let favoritesDidChange = Notification.Name("favoritesDidChange")
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
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if LauncherManager.shared.launcherEnabled {
                LauncherManager.shared.setupHotkeys()
            }
            self.appState.loadAllState()
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        LauncherManager.shared.cleanup()
        appState.saveAllState()
    }
}

// MARK: - AppStateManager

class AppStateManager: ObservableObject {
    static let shared = AppStateManager()
    
    @Published var installedApps: [AppItem] = []
    @Published var favoriteApps: [AppItem] = []
    @Published var barApps: [AppItem] = []
    @Published var recentApps: [AppItem] = []
    @Published var pinnedApps: [AppItem] = []
    @Published var presets: [Preset] = []
    @Published var isLoading = false
    
    @AppStorage("favoriteAppsData") private var favoriteAppsData: Data = Data()
    @AppStorage("barAppsData") private var barAppsData: Data = Data()
    @AppStorage("recentAppsData") private var recentAppsData: Data = Data()
    @AppStorage("pinnedAppsData") private var pinnedAppsData: Data = Data()
    @AppStorage("presetsData") private var presetsData: Data = Data()
    
    private init() {
        loadAllState()
        scanInstalledApps()
    }
    
    func loadAllState() {
        loadFavoriteApps()
        loadBarApps()
        loadRecentApps()
        loadPinnedApps()
        loadPresets()
    }
    
    func saveAllState() {
        saveFavoriteApps()
        saveBarApps()
        saveRecentApps()
        savePinnedApps()
        savePresets()
    }
    
    func loadFavoriteApps() {
        if !favoriteAppsData.isEmpty {
            if let decoded = try? JSONDecoder().decode([AppItem].self, from: favoriteAppsData) {
                favoriteApps = decoded
            }
        }
    }
    
    func saveFavoriteApps() {
        if let encoded = try? JSONEncoder().encode(favoriteApps) {
            favoriteAppsData = encoded
        }
        NotificationCenter.default.post(name: .favoritesDidChange, object: nil)
    }
    
    func addToFavorites(_ app: AppItem) {
        guard !isInFavorites(app) else { return }
        var newApp = app
        newApp.isPinned = true
        favoriteApps.append(newApp)
        saveFavoriteApps()
        objectWillChange.send()
    }
    
    func removeFromFavorites(_ app: AppItem) {
        favoriteApps.removeAll { $0.id == app.id }
        saveFavoriteApps()
        objectWillChange.send()
    }
    
    func isInFavorites(_ app: AppItem) -> Bool {
        favoriteApps.contains { $0.id == app.id }
    }
    
    func toggleFavorite(_ app: AppItem) {
        if isInFavorites(app) {
            removeFromFavorites(app)
        } else {
            addToFavorites(app)
        }
    }
    
    func loadBarApps() {
        if !barAppsData.isEmpty {
            if let decoded = try? JSONDecoder().decode([AppItem].self, from: barAppsData) {
                barApps = decoded
            }
        }
    }
    
    func saveBarApps() {
        if let encoded = try? JSONEncoder().encode(barApps) {
            barAppsData = encoded
        }
        NotificationCenter.default.post(name: .barItemsDidChange, object: nil)
    }
    
    func addToBar(_ app: AppItem) {
        guard !isInBar(app) else { return }
        var newApp = app
        newApp.isPinned = true
        barApps.append(newApp)
        saveBarApps()
        objectWillChange.send()
        updateMenuBarItems()
    }
    
    func removeFromBar(_ app: AppItem) {
        barApps.removeAll { $0.id == app.id }
        saveBarApps()
        objectWillChange.send()
        updateMenuBarItems()
    }
    
    func isInBar(_ app: AppItem) -> Bool {
        barApps.contains { $0.id == app.id }
    }
    
    private func updateMenuBarItems() {
        NotificationCenter.default.post(name: .barItemsDidChange, object: nil)
    }
    
    func loadRecentApps() {
        if !recentAppsData.isEmpty {
            if let decoded = try? JSONDecoder().decode([AppItem].self, from: recentAppsData) {
                recentApps = decoded
            }
        }
    }
    
    func saveRecentApps() {
        if let encoded = try? JSONEncoder().encode(recentApps) {
            recentAppsData = encoded
        }
    }
    
    func addRecentApp(_ app: AppItem) {
        if let index = recentApps.firstIndex(where: { $0.id == app.id }) {
            recentApps.remove(at: index)
        }
        recentApps.insert(app, at: 0)
        if recentApps.count > 10 {
            recentApps = Array(recentApps.prefix(10))
        }
        saveRecentApps()
    }
    
    func loadPinnedApps() {
        if !pinnedAppsData.isEmpty {
            if let decoded = try? JSONDecoder().decode([AppItem].self, from: pinnedAppsData) {
                pinnedApps = decoded
            }
        }
    }
    
    func savePinnedApps() {
        if let encoded = try? JSONEncoder().encode(pinnedApps) {
            pinnedAppsData = encoded
        }
    }
    
    func togglePinApp(_ app: AppItem) {
        if let index = pinnedApps.firstIndex(where: { $0.id == app.id }) {
            pinnedApps.remove(at: index)
        } else {
            var pinnedApp = app
            pinnedApp.isPinned = true
            pinnedApps.append(pinnedApp)
        }
        savePinnedApps()
        objectWillChange.send()
    }
    
    func loadPresets() {
        if !presetsData.isEmpty {
            if let decoded = try? JSONDecoder().decode([Preset].self, from: presetsData) {
                presets = decoded
            }
        }
    }
    
    func savePresets() {
        if let encoded = try? JSONEncoder().encode(presets) {
            presetsData = encoded
        }
        NotificationCenter.default.post(name: .presetsDidChange, object: nil)
    }
    
    func addPreset(_ preset: Preset) {
        presets.append(preset)
        savePresets()
    }
    
    func removePreset(_ preset: Preset) {
        presets.removeAll { $0.id == preset.id }
        savePresets()
    }
    
    func scanInstalledApps() {
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let apps = self.performScan()
            DispatchQueue.main.async {
                self.installedApps = apps
                self.isLoading = false
                self.restoreAppStates()
                NotificationCenter.default.post(name: .appListDidChange, object: nil)
            }
        }
    }
    
    private func performScan() -> [AppItem] {
        var apps: [AppItem] = []
        let applicationsURLs = [
            URL(fileURLWithPath: "/Applications"),
            URL(fileURLWithPath: "/System/Applications"),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications")
        ]
        var seenNames = Set<String>()
        
        for applicationsURL in applicationsURLs {
            do {
                let contents = try FileManager.default.contentsOfDirectory(
                    at: applicationsURL,
                    includingPropertiesForKeys: nil,
                    options: .skipsHiddenFiles
                )
                
                for fileURL in contents where fileURL.pathExtension == "app" {
                    let name = fileURL.deletingPathExtension().lastPathComponent
                    if !seenNames.contains(name) {
                        seenNames.insert(name)
                        let icon = getIconForApplication(name)
                        let app = AppItem(
                            name: name,
                            path: fileURL.path,
                            icon: icon,
                            preset: "Все приложения",
                            type: .application
                        )
                        apps.append(app)
                    }
                }
            } catch {
                print("Ошибка сканирования \(applicationsURL.path): \(error)")
            }
        }
        
        return apps.sorted { $0.name < $1.name }
    }
    
    private func restoreAppStates() {
        for i in 0..<installedApps.count {
            let app = installedApps[i]
            if favoriteApps.contains(where: { $0.path == app.path }) {
                installedApps[i].isPinned = true
            }
            if barApps.contains(where: { $0.path == app.path }) {
                installedApps[i].isPinned = true
            }
        }
    }
    
    private func getIconForApplication(_ name: String) -> String {
        let iconMap: [String: String] = [
            "Safari": "safari",
            "Finder": "finder",
            "Messages": "message",
            "Mail": "envelope",
            "Calendar": "calendar",
            "Photos": "photo",
            "Music": "music.note",
            "FaceTime": "video",
            "Maps": "map",
            "Notes": "note.text",
            "Reminders": "checklist",
            "Podcasts": "mic",
            "TV": "tv",
            "Books": "book",
            "App Store": "appstore",
            "System Settings": "gear",
            "Calculator": "plusminus.circle",
            "Chess": "gamecontroller",
            "Font Book": "a.circle",
            "Image Capture": "camera",
            "Preview": "eye",
            "QuickTime Player": "play.rectangle",
            "Stickies": "square.and.pencil",
            "TextEdit": "doc.text",
            "Utilities": "hammer",
            "Xcode": "hammer.fill",
            "Terminal": "terminal"
        ]
        return iconMap[name] ?? "app.fill"
    }
    
    func refreshApps() {
        scanInstalledApps()
    }
    
    func getAppState(_ app: AppItem) -> AppState {
        return AppState(
            isInstalled: installedApps.contains(where: { $0.id == app.id }),
            isFavorite: isInFavorites(app),
            isInBar: isInBar(app),
            isRecent: recentApps.contains(where: { $0.id == app.id }),
            isPinned: pinnedApps.contains(where: { $0.id == app.id })
        )
    }
}

struct AppState {
    let isInstalled: Bool
    let isFavorite: Bool
    let isInBar: Bool
    let isRecent: Bool
    let isPinned: Bool
}

// MARK: - HotkeyManager

class HotkeyManager: ObservableObject {
    static let shared = HotkeyManager()
    
    @Published var isRegistered = false
    @Published var currentHotkey: String = "⌘⇧B"
    @Published var availableHotkeys: [String] = []
    @Published var conflicts: [String] = []
    
    private var keyMonitor: Any?
    private var localMonitor: Any?
    private var isRecording = false
    
    @AppStorage("launcherHotkeyKey") var launcherHotkeyKey: String = "⌘⇧B"
    @AppStorage("launcherEnabled") var launcherEnabled: Bool = true
    
    private init() {
        currentHotkey = launcherHotkeyKey
    }
    
    func registerHotkey(_ hotkey: String) -> Bool {
        if checkConflicts(hotkey) {
            return false
        }
        
        if isSystemHotkey(hotkey) {
            return false
        }
        
        currentHotkey = hotkey
        launcherHotkeyKey = hotkey
        isRegistered = true
        return true
    }
    
    func checkConflicts(_ hotkey: String) -> Bool {
        let systemCombinations = [
            "⌘ Space", "⌃ Space", "⌘⇧ Space", "⌘⌥ Space",
            "⌘ Tab", "⌘⇧ Tab", "⌘`", "⌘⇧`"
        ]
        
        if systemCombinations.contains(hotkey) {
            conflicts.append(hotkey)
            return true
        }
        
        if hotkey.isEmpty || hotkey == " " {
            return true
        }
        
        let onlyModifiers = ["⌘", "⌥", "⇧", "⌃", "⌘⌥", "⌘⇧", "⌘⌃", "⌥⇧", "⌥⌃", "⇧⌃"]
        if onlyModifiers.contains(hotkey) {
            return true
        }
        
        return false
    }
    
    func isSystemHotkey(_ hotkey: String) -> Bool {
        let systemHotkeys = [
            "⌘ Space", "⌃ Space", "⌘⇧ Space", "⌘⌥ Space",
            "⌘ Tab", "⌘⇧ Tab", "⌘`", "⌘⇧`", "⌘Q", "⌘W"
        ]
        return systemHotkeys.contains(hotkey)
    }
    
    func startRecording() {
        isRecording = true
        setupMonitors()
    }
    
    func stopRecording() {
        isRecording = false
        removeMonitors()
    }
    
    private func setupMonitors() {
        removeMonitors()
        
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, self.isRecording else { return event }
            
            let key = KeyCodeHelper.keyString(for: event.keyCode)
            var modifiers: [String] = []
            
            if event.modifierFlags.contains(.command) { modifiers.append("⌘") }
            if event.modifierFlags.contains(.option) { modifiers.append("⌥") }
            if event.modifierFlags.contains(.shift) { modifiers.append("⇧") }
            if event.modifierFlags.contains(.control) { modifiers.append("⌃") }
            
            if !key.isEmpty && !modifiers.isEmpty {
                let hotkey = (modifiers + [key]).joined(separator: " ")
                
                DispatchQueue.main.async {
                    if !self.checkConflicts(hotkey) {
                        self.currentHotkey = hotkey
                        _ = self.registerHotkey(hotkey)
                    }
                    self.stopRecording()
                }
                return nil
            }
            return event
        }
    }
    
    private func removeMonitors() {
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }
    
    func cleanup() {
        removeMonitors()
        isRegistered = false
    }
}

// MARK: - LauncherManager

class LauncherManager: ObservableObject {
    static let shared = LauncherManager()
    
    @Published var isLauncherVisible = false
    @Published var searchText = ""
    @Published var filteredApps: [AppItem] = []
    @Published var selectedIndex = 0
    @Published var recentApps: [AppItem] = []
    @Published var launcherEnabled: Bool = true {
        didSet {
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
    private var isSetup = false
    private var localMonitor: Any?
    private var globalMonitor: Any?
    
    @AppStorage("launcherHotkeyKey") var launcherHotkeyKey: String = "⌘⇧B"
    @AppStorage("launcherWindowWidth") var windowWidth: Double = 500
    @AppStorage("launcherWindowHeight") var windowHeight: Double = 80
    @AppStorage("launcherWindowX") var windowX: Double = 0
    @AppStorage("launcherWindowY") var windowY: Double = 0
    
    init() {
        loadRecentApps()
        if launcherEnabled {
            setupHotkeys()
        }
    }
    
    func setupHotkeys() {
        guard launcherEnabled else { return }
        guard !isSetup else { return }
        
        isSetup = true
        hotkeyManager.registerHotkey(launcherHotkeyKey)
        
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return }
            
            let modifiers = event.modifierFlags.intersection([.command, .option, .shift, .control])
            let keyCode = event.keyCode
            let key = KeyCodeHelper.keyString(for: keyCode)
            
            var expectedModifiers: NSEvent.ModifierFlags = []
            var expectedKey: String = ""
            
            let parts = self.launcherHotkeyKey.components(separatedBy: " ")
            let modMap: [String: NSEvent.ModifierFlags] = [
                "⌘": .command, "⌥": .option, "⇧": .shift, "⌃": .control
            ]
            
            for part in parts {
                if let mod = modMap[part] {
                    expectedModifiers.insert(mod)
                } else {
                    expectedKey = part
                }
            }
            
            if modifiers == expectedModifiers && key == expectedKey {
                DispatchQueue.main.async {
                    self.toggleLauncher()
                }
            }
        }
    }
    
    func cleanup() {
        isSetup = false
        hotkeyManager.cleanup()
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
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
            NSApp.activate(ignoringOtherApps: true)
            isLauncherVisible = true
            return
        }
        
        if launcherWindow != nil {
            launcherWindow = nil
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
        
        let window = NSWindow(contentViewController: hostingController)
        window.title = "BarX Launcher"
        window.setContentSize(NSSize(width: windowWidth, height: windowHeight))
        window.styleMask = [.borderless, .fullSizeContentView, .closable, .resizable]
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.hasShadow = true
        window.isReleasedWhenClosed = false
        
        if windowX > 0 && windowY > 0 {
            window.setFrame(NSRect(x: windowX, y: windowY, width: windowWidth, height: windowHeight), display: true)
        } else if let screen = NSScreen.main {
            let screenRect = screen.frame
            let windowSize = window.frame.size
            let x = (screenRect.width - windowSize.width) / 2
            let y = (screenRect.height - windowSize.height) / 2 + 100
            window.setFrame(NSRect(x: x, y: y, width: windowSize.width, height: windowSize.height), display: true)
            windowX = x
            windowY = y
        }
        
        let delegate = LauncherWindowDelegate { [weak self] in
            DispatchQueue.main.async {
                self?.isLauncherVisible = false
                if let monitor = self?.localMonitor {
                    NSEvent.removeMonitor(monitor)
                    self?.localMonitor = nil
                }
            }
        }
        window.delegate = delegate
        
        launcherWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
        
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            
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
    
    func hideLauncher() {
        isLauncherVisible = false
        launcherWindow?.orderOut(nil)
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
        if let window = launcherWindow {
            let frame = window.frame
            windowX = frame.origin.x
            windowY = frame.origin.y
            windowWidth = frame.width
            windowHeight = frame.height
        }
    }
    
    func closeLauncher() {
        hideLauncher()
        launcherWindow?.close()
        launcherWindow = nil
    }
    
    func updateFilteredApps() {
        if searchText.isEmpty {
            var apps: [AppItem] = []
            apps.append(contentsOf: appState.favoriteApps)
            for app in appState.recentApps {
                if !apps.contains(where: { $0.id == app.id }) {
                    apps.append(app)
                }
            }
            for app in appState.pinnedApps {
                if !apps.contains(where: { $0.id == app.id }) {
                    apps.append(app)
                }
            }
            filteredApps = apps
        } else {
            filteredApps = appState.installedApps.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.path.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        var seen = Set<UUID>()
        filteredApps = filteredApps.filter { seen.insert($0.id).inserted }
        
        if selectedIndex >= filteredApps.count {
            selectedIndex = max(0, filteredApps.count - 1)
        }
    }
    
    func executeSelected() {
        guard filteredApps.indices.contains(selectedIndex) else { return }
        let app = filteredApps[selectedIndex]
        openApp(app)
        addRecentApp(app)
        hideLauncher()
    }
    
    func openApp(_ app: AppItem) {
        let url = URL(fileURLWithPath: app.path)
        let configuration = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, error in
            if let error = error {
                print("Ошибка запуска: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.showLaunchError(for: app)
                }
            }
        }
    }
    
    private func showLaunchError(for app: AppItem) {
        let alert = NSAlert()
        alert.messageText = "Не удалось открыть приложение"
        alert.informativeText = "BarX не смог открыть:\n\(app.name)\n\nВозможно приложение было удалено или перемещено."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Удалить из BarX")
        
        let response = alert.runModal()
        if response == .alertSecondButtonReturn {
            appState.removeFromFavorites(app)
            appState.removeFromBar(app)
            if let index = appState.pinnedApps.firstIndex(where: { $0.id == app.id }) {
                appState.pinnedApps.remove(at: index)
                appState.savePinnedApps()
            }
            if let index = appState.recentApps.firstIndex(where: { $0.id == app.id }) {
                appState.recentApps.remove(at: index)
                appState.saveRecentApps()
            }
        }
    }
    
    func addRecentApp(_ app: AppItem) {
        appState.addRecentApp(app)
        loadRecentApps()
    }
    
    private func loadRecentApps() {
        recentApps = appState.recentApps
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

// MARK: - LauncherWindowView

struct LauncherWindowView: View {
    @EnvironmentObject var launcherManager: LauncherManager
    @EnvironmentObject var appState: AppStateManager
    @EnvironmentObject var themeManager: ThemeManager
    @FocusState private var isFocused: Bool
    @State private var windowHeight: CGFloat = 80
    
    var body: some View {
        ZStack {
            if let theme = themeManager.selectedTheme {
                GradientBackground(theme: theme)
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
            }
            
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16))
                        .adaptiveTextColor()
                        .opacity(0.6)
                    
                    TextField("Поиск приложений...", text: $launcherManager.searchText)
                        .textFieldStyle(.plain)
                        .adaptiveTextColor()
                        .font(.system(size: 18))
                        .focused($isFocused)
                        .onChange(of: launcherManager.searchText) { _ in
                            launcherManager.updateFilteredApps()
                            updateWindowHeight()
                        }
                    
                    if !launcherManager.searchText.isEmpty {
                        Button {
                            launcherManager.searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16))
                                .adaptiveTextColor()
                                .opacity(0.5)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Text(launcherManager.launcherHotkeyKey)
                        .font(.system(size: 11, weight: .medium))
                        .adaptiveTextColor()
                        .opacity(0.3)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(4)
                    
                    Button {
                        launcherManager.closeLauncher()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .adaptiveTextColor()
                            .opacity(0.5)
                    }
                    .buttonStyle(.plain)
                    .help("Закрыть Launcher")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                
                if !launcherManager.filteredApps.isEmpty {
                    Divider()
                        .opacity(0.3)
                        .background(Color.white.opacity(0.3))
                    
                    ScrollView(.vertical, showsIndicators: true) {
                        VStack(spacing: 2) {
                            ForEach(Array(launcherManager.filteredApps.enumerated()), id: \.element.id) { index, app in
                                LauncherAppRow(
                                    app: app,
                                    isSelected: index == launcherManager.selectedIndex
                                ) {
                                    launcherManager.selectedIndex = index
                                    launcherManager.executeSelected()
                                }
                                .onTapGesture {
                                    launcherManager.selectedIndex = index
                                    launcherManager.executeSelected()
                                }
                                .onHover { hovering in
                                    if hovering {
                                        launcherManager.selectedIndex = index
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .frame(maxHeight: min(CGFloat(launcherManager.filteredApps.count * 44 + 8), 300))
                }
            }
        }
        .frame(width: 500, height: windowHeight)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isFocused = true
            }
            updateWindowHeight()
        }
    }
    
    private func updateWindowHeight() {
        let baseHeight: CGFloat = 60
        let rowHeight: CGFloat = 44
        let maxHeight: CGFloat = 360
        let count = launcherManager.filteredApps.count
        
        if count == 0 {
            windowHeight = baseHeight
        } else {
            let calculatedHeight = baseHeight + CGFloat(count) * rowHeight + 8
            windowHeight = min(calculatedHeight, maxHeight)
        }
    }
}

// MARK: - LauncherAppRow

struct LauncherAppRow: View {
    let app: AppItem
    let isSelected: Bool
    let action: () -> Void
    @State private var appIcon: NSImage?
    @State private var isLoadingIcon = false
    @EnvironmentObject var appState: AppStateManager
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 28, height: 28)
                    
                    if let icon = appIcon {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 22, height: 22)
                    } else {
                        Image(systemName: app.icon)
                            .font(.system(size: 14))
                            .adaptiveTextColor()
                    }
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(app.name)
                        .font(.system(size: 14, weight: .medium))
                        .adaptiveTextColor()
                    
                    Text(app.path)
                        .font(.system(size: 11))
                        .adaptiveTextColor()
                        .opacity(0.5)
                        .lineLimit(1)
                }
                
                Spacer()
                
                if appState.isInFavorites(app) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.yellow.opacity(0.7))
                }
                
                if appState.isInBar(app) {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.blue.opacity(0.7))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.white.opacity(0.15) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.white.opacity(0.3) : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.1), value: isSelected)
        .onAppear {
            loadAppIcon()
        }
    }
    
    private func loadAppIcon() {
        guard !isLoadingIcon else { return }
        isLoadingIcon = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let url = URL(fileURLWithPath: app.path)
            let icon = NSWorkspace.shared.icon(forFile: url.path)
            
            if icon.size.width > 0 {
                let resized = icon.resized(to: NSSize(width: 22, height: 22))
                DispatchQueue.main.async {
                    self.appIcon = resized
                    self.isLoadingIcon = false
                }
            } else {
                DispatchQueue.main.async {
                    self.isLoadingIcon = false
                }
            }
        }
    }
}

// MARK: - NSImage Extension

extension NSImage {
    func resized(to size: NSSize) -> NSImage {
        let newImage = NSImage(size: size)
        newImage.lockFocus()
        self.draw(in: NSRect(origin: .zero, size: size))
        newImage.unlockFocus()
        return newImage
    }
}

// MARK: - KeyCodeHelper

struct KeyCodeHelper {
    static func keyString(for keyCode: UInt16) -> String {
        switch keyCode {
        case 0: return "A"
        case 1: return "S"
        case 2: return "D"
        case 3: return "F"
        case 4: return "H"
        case 5: return "G"
        case 6: return "Z"
        case 7: return "X"
        case 8: return "C"
        case 9: return "V"
        case 11: return "B"
        case 12: return "Q"
        case 13: return "W"
        case 14: return "E"
        case 15: return "R"
        case 16: return "Y"
        case 17: return "T"
        case 18: return "1"
        case 19: return "2"
        case 20: return "3"
        case 21: return "4"
        case 22: return "6"
        case 23: return "5"
        case 24: return "="
        case 25: return "9"
        case 26: return "7"
        case 27: return "-"
        case 28: return "8"
        case 29: return "0"
        case 30: return "]"
        case 31: return "O"
        case 32: return "U"
        case 33: return "["
        case 34: return "I"
        case 35: return "P"
        case 37: return "L"
        case 38: return "J"
        case 39: return "'"
        case 40: return "K"
        case 41: return ";"
        case 42: return "\\"
        case 43: return ","
        case 44: return "/"
        case 45: return "N"
        case 46: return "M"
        case 47: return "."
        case 48: return "Tab"
        case 49: return "Space"
        case 50: return "`"
        case 51: return "Delete"
        case 52: return "Enter"
        case 53: return "Escape"
        case 55: return "⌘"
        case 56: return "⇧"
        case 57: return "Caps"
        case 58: return "⌥"
        case 59: return "⌃"
        case 60: return "⇧"
        case 61: return "⇧"
        case 62: return "⇧"
        case 63: return "Fn"
        case 64...78: return "F\(keyCode - 63)"
        case 115: return "Home"
        case 116: return "PageUp"
        case 117: return "Delete"
        case 118: return "End"
        case 119: return "PageDown"
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        default: return ""
        }
    }
}

// MARK: - HotkeyRecorder

struct HotkeyRecorder: View {
    @Binding var hotkey: String
    let onChanged: (String) -> Void
    @State private var isRecording = false
    @State private var currentModifiers: [String] = []
    @State private var currentKey: String = ""
    @State private var hasConflict = false
    @State private var conflictMessage = ""
    @State private var showConflictAlert = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button {
                if isRecording {
                    stopRecording()
                } else {
                    startRecording()
                }
            } label: {
                HStack(spacing: 8) {
                    if isRecording {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(.red)
                            .opacity(0.8)
                    }
                    
                    Text(isRecording ? "Нажмите новую комбинацию..." : hotkey)
                        .font(.system(.body, design: .monospaced))
                        .adaptiveTextColor()
                        .opacity(isRecording ? 0.7 : 0.9)
                }
                .frame(minWidth: 160)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            isRecording ? Color.white.opacity(0.15) : Color.white.opacity(0.08)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(
                                    isRecording ? Color.white.opacity(0.4) :
                                    hasConflict ? Color.red.opacity(0.5) : Color.white.opacity(0.1),
                                    lineWidth: isRecording ? 2 : 1
                                )
                        )
                )
            }
            .buttonStyle(.plain)
            .onAppear {
                setupKeyMonitor()
            }
            
            if hasConflict {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.yellow)
                    Text(conflictMessage)
                        .font(.caption)
                        .foregroundStyle(.yellow)
                        .opacity(0.8)
                }
                .padding(.leading, 4)
            }
        }
    }
    
    private func setupKeyMonitor() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if isRecording {
                handleKeyEvent(event)
                return nil
            }
            return event
        }
    }
    
    private func handleKeyEvent(_ event: NSEvent) {
        let key = KeyCodeHelper.keyString(for: event.keyCode)
        var modifiers: [String] = []
        
        if event.modifierFlags.contains(.command) { modifiers.append("⌘") }
        if event.modifierFlags.contains(.option) { modifiers.append("⌥") }
        if event.modifierFlags.contains(.shift) { modifiers.append("⇧") }
        if event.modifierFlags.contains(.control) { modifiers.append("⌃") }
        
        if !key.isEmpty && !modifiers.isEmpty {
            let hotkeyString = (modifiers + [key]).joined(separator: " ")
            
            let hotkeyManager = HotkeyManager.shared
            if hotkeyManager.checkConflicts(hotkeyString) {
                hasConflict = true
                conflictMessage = "⚠️ Эта комбинация может использоваться системой"
                showConflictAlert = true
                return
            }
            
            if hotkeyManager.isSystemHotkey(hotkeyString) {
                hasConflict = true
                conflictMessage = "⚠️ Системная комбинация macOS"
                showConflictAlert = true
                return
            }
            
            hasConflict = false
            conflictMessage = ""
            hotkey = hotkeyString
            onChanged(hotkeyString)
            stopRecording()
        }
    }
    
    private func startRecording() {
        isRecording = true
        hasConflict = false
        conflictMessage = ""
        currentModifiers = []
        currentKey = ""
    }
    
    private func stopRecording() {
        isRecording = false
        if hotkey.isEmpty {
            hotkey = "⌘⇧B"
            onChanged("⌘⇧B")
        }
    }
}

// MARK: - Models

struct AppItem: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var path: String
    var icon: String
    var preset: String
    var type: ItemType = .application
    var isPinned: Bool = false
    var launchCount: Int = 0
    var lastLaunched: Date?
    
    enum ItemType: String, Codable {
        case application
        case folder
        case url
        case action
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: AppItem, rhs: AppItem) -> Bool {
        lhs.id == rhs.id
    }
}

struct Preset: Identifiable, Codable {
    var id = UUID()
    var name: String
    var icon: String
    var items: [AppItem] = []
    var isFavorite: Bool = false
}

struct Theme: Identifiable, Codable {
    var id = UUID()
    var name: String
    var colors: [String]
    var isGradient: Bool
    var gradientDirection: String?
    var isCustom: Bool = false
    var textColor: TextColor = .auto
    
    enum TextColor: String, Codable, CaseIterable {
        case auto = "Авто"
        case light = "Светлый"
        case dark = "Тёмный"
    }
}

enum GradientDirection: String, CaseIterable {
    case horizontal = "Горизонтальный"
    case vertical = "Вертикальный"
    case diagonal = "Диагональный"
    case radial = "Радиальный"
}

// MARK: - ThemeManager

class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    @Published var themes: [Theme] = []
    @Published var customColors: [Color] = []
    @Published var selectedTheme: Theme?
    @Published var previewTheme: Theme?
    @Published var isPreviewMode = false
    
    @AppStorage("selectedThemeId") private var selectedThemeId: String = ""
    @AppStorage("customColorsData") private var customColorsData: Data = Data()
    @AppStorage("themesData") private var themesData: Data = Data()
    @AppStorage("customThemeIds") private var customThemeIdsData: Data = Data()
    
    private var customThemeIds: Set<String> = []
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        loadCustomThemeIds()
        loadDefaultThemes()
        loadCustomColors()
        loadSelectedTheme()
    }
    
    // MARK: - Public Methods
    
    func reloadThemes() {
        loadDefaultThemes()
        loadSelectedTheme()
        objectWillChange.send()
    }
    
    func loadDefaultThemes() {
        if !themesData.isEmpty {
            if let decoded = try? JSONDecoder().decode([Theme].self, from: themesData) {
                themes = decoded
                return
            }
        }
        
        themes = [
            Theme(name: "Фиолетовый", colors: ["#8B5CF6", "#6D28D9"], isGradient: true, gradientDirection: GradientDirection.horizontal.rawValue, isCustom: false),
            Theme(name: "Океан", colors: ["#06B6D4", "#3B82F6"], isGradient: true, gradientDirection: GradientDirection.horizontal.rawValue, isCustom: false),
            Theme(name: "Закат", colors: ["#F472B6", "#FB923C"], isGradient: true, gradientDirection: GradientDirection.horizontal.rawValue, isCustom: false),
            Theme(name: "Лес", colors: ["#10B981", "#059669"], isGradient: true, gradientDirection: GradientDirection.horizontal.rawValue, isCustom: false),
            Theme(name: "Космос", colors: ["#7C3AED", "#1E1B4B"], isGradient: true, gradientDirection: GradientDirection.diagonal.rawValue, isCustom: false),
            Theme(name: "Розовый", colors: ["#EC4899", "#BE185D"], isGradient: true, gradientDirection: GradientDirection.horizontal.rawValue, isCustom: false),
            Theme(name: "Солнечный", colors: ["#F59E0B", "#FCD34D"], isGradient: true, gradientDirection: GradientDirection.horizontal.rawValue, isCustom: false),
            Theme(name: "Лаванда", colors: ["#A78BFA", "#7C3AED"], isGradient: true, gradientDirection: GradientDirection.vertical.rawValue, isCustom: false),
            Theme(name: "Мятный", colors: ["#34D399", "#059669"], isGradient: true, gradientDirection: GradientDirection.horizontal.rawValue, isCustom: false),
            Theme(name: "Коралл", colors: ["#FB7185", "#E11D48"], isGradient: true, gradientDirection: GradientDirection.horizontal.rawValue, isCustom: false),
            Theme(name: "Бирюза", colors: ["#2DD4BF", "#0D9488"], isGradient: true, gradientDirection: GradientDirection.vertical.rawValue, isCustom: false),
            Theme(name: "Янтарь", colors: ["#FBBF24", "#F59E0B"], isGradient: true, gradientDirection: GradientDirection.diagonal.rawValue, isCustom: false),
            Theme(name: "Сиреневый", colors: ["#C084FC", "#7C3AED"], isGradient: true, gradientDirection: GradientDirection.radial.rawValue, isCustom: false),
            Theme(name: "Неон", colors: ["#34D399", "#60A5FA", "#F472B6"], isGradient: true, gradientDirection: GradientDirection.horizontal.rawValue, isCustom: false),
            Theme(name: "Радуга", colors: ["#F87171", "#FBBF24", "#34D399", "#60A5FA"], isGradient: true, gradientDirection: GradientDirection.diagonal.rawValue, isCustom: false),
            Theme(name: "Графит", colors: ["#6B7280", "#1F2937"], isGradient: true, gradientDirection: GradientDirection.horizontal.rawValue, isCustom: false),
            Theme(name: "Бежевый", colors: ["#FDE68A", "#F59E0B"], isGradient: true, gradientDirection: GradientDirection.horizontal.rawValue, isCustom: false),
            Theme(name: "Ледяной", colors: ["#93C5FD", "#3B82F6"], isGradient: true, gradientDirection: GradientDirection.horizontal.rawValue, isCustom: false),
        ]
        saveThemes()
    }
    
    func loadSelectedTheme() {
        if let theme = themes.first(where: { $0.id.uuidString == selectedThemeId }) {
            selectedTheme = theme
        } else if let firstTheme = themes.first {
            selectedTheme = firstTheme
            selectedThemeId = firstTheme.id.uuidString
        }
    }
    
    func selectTheme(_ theme: Theme, applyImmediately: Bool = false) {
        if applyImmediately {
            selectedTheme = theme
            selectedThemeId = theme.id.uuidString
            isPreviewMode = false
            previewTheme = nil
            objectWillChange.send()
            NotificationCenter.default.post(name: .themeDidChange, object: nil)
        } else {
            previewTheme = theme
            isPreviewMode = true
            objectWillChange.send()
        }
    }
    
    func applyPreviewTheme() {
        if let theme = previewTheme {
            selectedTheme = theme
            selectedThemeId = theme.id.uuidString
            isPreviewMode = false
            previewTheme = nil
            objectWillChange.send()
            NotificationCenter.default.post(name: .themeDidChange, object: nil)
        }
    }
    
    func cancelPreview() {
        isPreviewMode = false
        previewTheme = nil
        objectWillChange.send()
    }
    
    func addCustomTheme(_ theme: Theme) {
        var newTheme = theme
        newTheme.isCustom = true
        themes.append(newTheme)
        customThemeIds.insert(newTheme.id.uuidString)
        saveCustomThemeIds()
        saveThemes()
        selectTheme(newTheme)
        objectWillChange.send()
    }
    
    func deleteCustomTheme(_ theme: Theme) {
        guard theme.isCustom else { return }
        if let index = themes.firstIndex(where: { $0.id == theme.id }) {
            themes.remove(at: index)
            customThemeIds.remove(theme.id.uuidString)
            saveCustomThemeIds()
            saveThemes()
            if selectedTheme?.id == theme.id {
                selectedTheme = themes.first
                selectedThemeId = themes.first?.id.uuidString ?? ""
            }
            objectWillChange.send()
        }
    }
    
    func getCustomThemes() -> [Theme] {
        themes.filter { $0.isCustom }
    }
    
    func getDefaultThemes() -> [Theme] {
        themes.filter { !$0.isCustom }
    }
    
    func addCustomColors(_ colors: [Color]) {
        customColors = colors
        saveCustomColors()
        objectWillChange.send()
    }
    
    func getTextColor(for theme: Theme) -> Color {
        switch theme.textColor {
        case .light:
            return .white
        case .dark:
            return .black
        case .auto:
            if theme.isGradient && !theme.colors.isEmpty {
                let colors = theme.colors.compactMap { Color(hex: $0) }
                if let firstColor = colors.first {
                    let brightness = getColorBrightness(firstColor)
                    return brightness > 0.5 ? Color.black : Color.white
                }
            }
            return .white
        }
    }
    
    func getGradient(for theme: Theme) -> LinearGradient? {
        guard theme.isGradient && theme.colors.count >= 2 else { return nil }
        let colors = theme.colors.compactMap { Color(hex: $0) }
        guard colors.count >= 2 else { return nil }
        
        let startPoint: UnitPoint
        let endPoint: UnitPoint
        let direction = theme.gradientDirection ?? GradientDirection.horizontal.rawValue
        
        switch direction {
        case GradientDirection.horizontal.rawValue:
            startPoint = .leading
            endPoint = .trailing
        case GradientDirection.vertical.rawValue:
            startPoint = .top
            endPoint = .bottom
        case GradientDirection.diagonal.rawValue:
            startPoint = .topLeading
            endPoint = .bottomTrailing
        default:
            startPoint = .leading
            endPoint = .trailing
        }
        
        return LinearGradient(
            gradient: Gradient(colors: colors),
            startPoint: startPoint,
            endPoint: endPoint
        )
    }
    
    func getRadialGradient(for theme: Theme) -> RadialGradient? {
        guard theme.isGradient && theme.gradientDirection == GradientDirection.radial.rawValue else { return nil }
        let colors = theme.colors.compactMap { Color(hex: $0) }
        guard colors.count >= 2 else { return nil }
        
        return RadialGradient(
            gradient: Gradient(colors: colors),
            center: .center,
            startRadius: 0,
            endRadius: 100
        )
    }
    
    func getStyleBackground(for theme: Theme) -> AnyView {
        if theme.isGradient {
            return AnyView(
                ZStack {
                    if theme.gradientDirection == GradientDirection.radial.rawValue {
                        if let gradient = getRadialGradient(for: theme) {
                            gradient.opacity(0.95)
                        }
                    } else if let gradient = getGradient(for: theme) {
                        gradient.opacity(0.95)
                    }
                }
            )
        } else {
            return AnyView(
                Color.clear
                    .background(.ultraThinMaterial)
                    .opacity(0.7)
            )
        }
    }
    
    // MARK: - Private Methods
    
    private func loadCustomThemeIds() {
        if !customThemeIdsData.isEmpty {
            if let decoded = try? JSONDecoder().decode([String].self, from: customThemeIdsData) {
                customThemeIds = Set(decoded)
            }
        }
    }
    
    private func saveCustomThemeIds() {
        if let encoded = try? JSONEncoder().encode(Array(customThemeIds)) {
            customThemeIdsData = encoded
        }
    }
    
    private func saveThemes() {
        if let encoded = try? JSONEncoder().encode(themes) {
            themesData = encoded
        }
    }
    
    private func loadCustomColors() {
        guard !customColorsData.isEmpty else {
            customColors = []
            return
        }
        if let decoded = try? JSONDecoder().decode([String].self, from: customColorsData) {
            customColors = decoded.compactMap { hex in
                Color(hex: hex)
            }
        }
    }
    
    private func saveCustomColors() {
        let hexColors = customColors.map { $0.toHex() }
        if let encoded = try? JSONEncoder().encode(hexColors) {
            customColorsData = encoded
        }
    }
    
    private func getColorBrightness(_ color: Color) -> Double {
        let components = color.cgColor?.components ?? [0, 0, 0, 1]
        let r = Double(components[0])
        let g = Double(components[1])
        let b = Double(components[2])
        return (r * 299 + g * 587 + b * 114) / 1000
    }
}

// MARK: - Color Extensions

extension Color {
    init(hex: String) {
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
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    func toHex() -> String {
        let components = self.cgColor?.components ?? [0, 0, 0, 1]
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        let a = Float(components[3])
        if a == 1.0 {
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
                    if let gradient = ThemeManager.shared.getRadialGradient(for: theme) {
                        gradient.opacity(0.95)
                    } else {
                        Color.clear
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
        let theme = themeManager.isPreviewMode ? themeManager.previewTheme : themeManager.selectedTheme
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
        let theme = themeManager.isPreviewMode ? themeManager.previewTheme : themeManager.selectedTheme
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
            .animation(.easeInOut(duration: 0.15), value: isSelected)
            .animation(.easeInOut(duration: 0.15), value: isHovered)
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
        let theme = themeManager.isPreviewMode ? themeManager.previewTheme : themeManager.selectedTheme
        let textColor = theme.map { themeManager.getTextColor(for: $0) } ?? .white
        
        return configuration.label
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        configuration.isPressed ? textColor.opacity(0.1) : Color.clear
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.98 : isHovered ? 1.01 : 1.0)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
            .animation(.easeInOut(duration: 0.12), value: isHovered)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.12)) {
                    isHovered = hovering
                }
                if hovering {
                    NSCursor.pointingHand.set()
                }
            }
    }
}

// MARK: - BarXWindowManager

@MainActor
final class BarXWindowManager: NSObject {
    static let shared = BarXWindowManager()
    private var windows: [String: NSWindow] = [:]
    private var delegates: [NSObject] = []
    private var mainMenuWindow: NSWindow?
    
    private override init() {
        super.init()
    }
    
    func showWindow<Content: View>(
        id: String,
        title: String,
        size: CGSize,
        content: Content,
        isMainMenu: Bool = false
    ) {
        if let existingWindow = windows[id] {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let hostingController = NSHostingController(
            rootView: content
        )
        
        let window = NSWindow(
            contentViewController: hostingController
        )
        window.title = title
        window.setContentSize(size)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.isReleasedWhenClosed = false
        window.center()
        
        let delegate = BarXWindowDelegate { [weak self, weak window] in
            guard let self else { return }
            if let window {
                self.removeWindow(window)
            }
        }
        window.delegate = delegate
        delegates.append(delegate)
        windows[id] = window
        
        if isMainMenu {
            mainMenuWindow = window
        }
        
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func closeWindow(id: String) {
        guard let window = windows[id] else { return }
        window.close()
        windows.removeValue(forKey: id)
    }
    
    func removeWindow(_ window: NSWindow) {
        for (id, storedWindow) in windows {
            if storedWindow === window {
                windows.removeValue(forKey: id)
                break
            }
        }
    }
    
    func closeAllWindows() {
        for window in windows.values {
            window.close()
        }
        windows.removeAll()
        mainMenuWindow = nil
    }
    
    func showMainMenu() {
        if let mainMenu = mainMenuWindow {
            mainMenu.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let menuView = BarXMenuView()
            .environmentObject(AppStateManager.shared)
        let hostingController = NSHostingController(rootView: menuView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "BarX"
        window.setContentSize(NSSize(width: 300, height: 500))
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.isReleasedWhenClosed = false
        window.center()
        
        let delegate = BarXWindowDelegate { [weak self, weak window] in
            guard let self else { return }
            if let window {
                self.removeWindow(window)
            }
        }
        window.delegate = delegate
        delegates.append(delegate)
        mainMenuWindow = window
        
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - BarXWindowDelegate

final class BarXWindowDelegate: NSObject, NSWindowDelegate {
    private let onClose: () -> Void
    
    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }
    
    func windowWillClose(_ notification: Notification) {
        onClose()
    }
}

// MARK: - SettingsCategory

enum SettingsCategory: String, CaseIterable, Hashable {
    case general = "Основные"
    case appearance = "Внешний вид"
    case apps = "Приложения"
    case bar = "Панель Bar"
    case presets = "Папки"
    case launcher = "Launcher"
    case about = "О программе"
    
    var icon: String {
        switch self {
        case .general:
            return "gearshape"
        case .appearance:
            return "paintbrush"
        case .apps:
            return "app.badge"
        case .bar:
            return "menubar.rectangle"
        case .presets:
            return "folder"
        case .launcher:
            return "magnifyingglass"
        case .about:
            return "info.circle"
        }
    }
}

// MARK: - FileAccessHelper

class FileAccessHelper {
    static let shared = FileAccessHelper()
    private let defaults = UserDefaults.standard
    
    func saveBookmark(for url: URL) {
        do {
            let bookmarkData = try url.bookmarkData(
                options: .minimalBookmark,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            defaults.set(bookmarkData, forKey: "bookmark_\(url.path)")
            defaults.synchronize()
        } catch {
            print("Не удалось сохранить закладку: \(error)")
        }
    }
    
    func getBookmarkedURL(for path: String) -> URL? {
        guard let bookmarkData = defaults.data(forKey: "bookmark_\(path)") else {
            return nil
        }
        
        do {
            var isStale = false
            let url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: .withoutUI,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            if !isStale {
                return url
            }
        } catch {
            print("Не удалось восстановить закладку: \(error)")
        }
        return nil
    }
    
    func requestAccessAndOpen(path: String, completion: @escaping (Bool) -> Void) {
        let openPanel = NSOpenPanel()
        openPanel.title = "Разрешить доступ к папке"
        openPanel.message = "BarX запрашивает доступ к папке\n\(path)"
        openPanel.prompt = "Разрешить"
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.allowsMultipleSelection = false
        
        let url = URL(fileURLWithPath: path)
        if FileManager.default.fileExists(atPath: path) {
            openPanel.directoryURL = url
        }
        
        openPanel.begin { response in
            if response == .OK, let selectedURL = openPanel.url {
                self.saveBookmark(for: selectedURL)
                NSWorkspace.shared.open(selectedURL)
                completion(true)
            } else {
                completion(false)
            }
        }
    }
}
// MARK: - BarXMenuView (исправлен)

struct BarXMenuView: View {
    @EnvironmentObject var appState: AppStateManager
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var launcherManager = LauncherManager.shared
    @State private var searchText = ""
    @State private var filteredPresets: [Preset] = []
    @State private var hoveredPresetId: UUID?
    @State private var refreshTrigger = UUID()
    @State private var hoveredFavoriteId: UUID?
    @State private var hoveredBarAppId: UUID?
    
    var body: some View {
        ZStack {
            if let theme = themeManager.isPreviewMode ? themeManager.previewTheme : themeManager.selectedTheme {
                GradientBackground(theme: theme)
                    .ignoresSafeArea()
            }
            
            VStack(spacing: 0) {
                headerView
                
                Divider()
                    .opacity(0.35)
                    .background(Color.white.opacity(0.3))
                
                searchView
                
                Divider()
                    .opacity(0.35)
                    .background(Color.white.opacity(0.3))
                
                // Панель Bar - всегда отображается
                barPanelView
                
                Divider()
                    .opacity(0.35)
                    .background(Color.white.opacity(0.3))
                
                foldersView
                    .id(refreshTrigger)
                
                Divider()
                    .opacity(0.35)
                    .background(Color.white.opacity(0.3))
                
                actionsView
            }
        }
        .frame(width: 300)
        .onAppear {
            loadPresets()
            updateFilteredPresets()
        }
        .onReceive(NotificationCenter.default.publisher(for: .presetsDidChange)) { _ in
            loadPresets()
            updateFilteredPresets()
            refreshTrigger = UUID()
        }
        .onReceive(NotificationCenter.default.publisher(for: .favoritesDidChange)) { _ in
            appState.objectWillChange.send()
        }
        .onReceive(NotificationCenter.default.publisher(for: .barItemsDidChange)) { _ in
            appState.objectWillChange.send()
        }
        .onChange(of: searchText) { _ in
            updateFilteredPresets()
        }
    }
    
    private var headerView: some View {
        HStack {
            HStack(spacing: 9) {
                Image(systemName: "sparkles")
                    .font(.system(size: 15, weight: .semibold))
                    .adaptiveTextColor()
                Text("BarX")
                    .font(.system(size: 16, weight: .semibold))
                    .adaptiveTextColor()
            }
            Spacer()
            HStack(spacing: 12) {
                Button {
                    showAddAppWindow()
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 14))
                        .adaptiveTextColor()
                        .opacity(0.8)
                }
                .buttonStyle(.plain)
                .help("Добавить приложение")
                
                Button {
                    openSettingsWindow()
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 14))
                        .adaptiveTextColor()
                        .opacity(0.8)
                }
                .buttonStyle(.plain)
                .help("Настройки")
                .keyboardShortcut(",", modifiers: .command)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 12)
    }
    
    private func showAddAppWindow() {
        BarXWindowManager.shared.showWindow(
            id: "addApp",
            title: "Добавить приложение",
            size: CGSize(width: 500, height: 600),
            content: AddAppFromFinderView(
                onAppAdded: { app in
                    appState.addToFavorites(app)
                    appState.addToBar(app)
                    BarXWindowManager.shared.closeWindow(id: "addApp")
                },
                onCancel: {
                    BarXWindowManager.shared.closeWindow(id: "addApp")
                }
            )
            .environmentObject(appState)
        )
    }
    
    private var searchView: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .adaptiveTextColor()
                .opacity(0.6)
            
            TextField("Поиск...", text: $searchText)
                .textFieldStyle(.plain)
                .adaptiveTextColor()
                .font(.system(size: 13))
            
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .adaptiveTextColor()
                        .opacity(0.5)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
    
    // Новая панель Bar - всегда отображается
    private var barPanelView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("📌 ПАНЕЛЬ BAR")
                    .font(.system(size: 10, weight: .semibold))
                    .adaptiveTextColor()
                    .opacity(0.5)
                Spacer()
                Text("\(appState.barApps.count)")
                    .font(.caption2)
                    .adaptiveTextColor()
                    .opacity(0.4)
                Button {
                    showAddAppWindow()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 12))
                        .adaptiveTextColor()
                        .opacity(0.6)
                }
                .buttonStyle(.plain)
                .help("Добавить приложение")
            }
            .padding(.horizontal, 12)
            
            if appState.barApps.isEmpty {
                VStack(spacing: 4) {
                    Text("Нет приложений в панели")
                        .font(.caption)
                        .adaptiveTextColor()
                        .opacity(0.5)
                    Text("Нажмите + чтобы добавить")
                        .font(.caption2)
                        .adaptiveTextColor()
                        .opacity(0.3)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(appState.barApps.prefix(10)) { app in
                            BarAppIcon(
                                app: app,
                                isHovered: hoveredBarAppId == app.id,
                                onLaunch: {
                                    launcherManager.openApp(app)
                                    appState.addRecentApp(app)
                                },
                                onRemove: {
                                    appState.removeFromBar(app)
                                }
                            )
                            .onHover { hovering in
                                hoveredBarAppId = hovering ? app.id : nil
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                }
                .frame(height: 44)
            }
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - BarAppIcon
    struct BarAppIcon: View {
        let app: AppItem
        let isHovered: Bool
        let onLaunch: () -> Void
        let onRemove: () -> Void
        @State private var appIcon: NSImage?
        @State private var isLoadingIcon = false
        
        var body: some View {
            ZStack(alignment: .topTrailing) {
                Button(action: onLaunch) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.08))
                            .frame(width: 36, height: 36)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(
                                        isHovered ? Color.white.opacity(0.3) : Color.white.opacity(0.1),
                                        lineWidth: isHovered ? 1.5 : 1
                                    )
                            )
                            .shadow(color: .black.opacity(0.2), radius: isHovered ? 4 : 2, x: 0, y: 2)
                        
                        if let icon = appIcon {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 24, height: 24)
                        } else {
                            Image(systemName: app.icon)
                                .font(.system(size: 16))
                                .adaptiveTextColor()
                        }
                    }
                }
                .buttonStyle(.plain)
                .help(app.name)
                .onAppear {
                    loadAppIcon()
                }
                
                if isHovered {
                    Button {
                        onRemove()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.red.opacity(0.8))
                            .background(
                                Circle()
                                    .fill(Color.black.opacity(0.5))
                                    .frame(width: 14, height: 14)
                            )
                    }
                    .buttonStyle(.plain)
                    .offset(x: 4, y: -4)
                    .help("Убрать из панели")
                }
            }
            .frame(width: 40, height: 40)
        }
        
        private func loadAppIcon() {
            guard !isLoadingIcon else { return }
            isLoadingIcon = true
            
            DispatchQueue.global(qos: .userInitiated).async {
                let url = URL(fileURLWithPath: app.path)
                let icon = NSWorkspace.shared.icon(forFile: url.path)
                
                if icon.size.width > 0 {
                    let resized = icon.resized(to: NSSize(width: 24, height: 24))
                    DispatchQueue.main.async {
                        self.appIcon = resized
                        self.isLoadingIcon = false
                    }
                } else {
                    DispatchQueue.main.async {
                        self.isLoadingIcon = false
                    }
                }
            }
        }
    }
    
    private var foldersView: some View {
        VStack(spacing: 4) {
            HStack {
                Text("📁 МОИ ПАПКИ")
                    .font(.system(size: 10, weight: .semibold))
                    .adaptiveTextColor()
                    .opacity(0.5)
                Spacer()
                Text("\(filteredPresets.count)")
                    .font(.caption2)
                    .adaptiveTextColor()
                    .opacity(0.4)
                Button {
                    openAddFolderWindow()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 12))
                        .adaptiveTextColor()
                        .opacity(0.6)
                }
                .buttonStyle(.plain)
                .help("Добавить папку")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            
            if filteredPresets.isEmpty && searchText.isEmpty {
                emptyFoldersView
            } else if filteredPresets.isEmpty && !searchText.isEmpty {
                noResultsView
            } else {
                ForEach(filteredPresets) { preset in
                    FolderRow(
                        preset: preset,
                        isHovered: hoveredPresetId == preset.id,
                        onTap: {
                            openItemsWindow(for: preset)
                        },
                        onHover: { hovering in
                            hoveredPresetId = hovering ? preset.id : nil
                        }
                    )
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
    }
    
    private var emptyFoldersView: some View {
        VStack(spacing: 8) {
            Image(systemName: "folder")
                .font(.system(size: 32))
                .adaptiveTextColor()
                .opacity(0.5)
            Text("Нет папок")
                .font(.caption)
                .adaptiveTextColor()
                .opacity(0.7)
            Text("Нажмите + чтобы создать")
                .font(.caption2)
                .adaptiveTextColor()
                .opacity(0.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
    
    private var noResultsView: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 28))
                .adaptiveTextColor()
                .opacity(0.4)
            Text("Ничего не найдено")
                .font(.caption)
                .adaptiveTextColor()
                .opacity(0.6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }
    
    private var actionsView: some View {
        VStack(spacing: 2) {
            BarXActionButton(
                icon: "magnifyingglass",
                title: "Открыть Launcher",
                shortcut: launcherManager.launcherHotkeyKey
            ) {
                launcherManager.toggleLauncher()
            }
            
            BarXActionButton(
                icon: "plus.circle",
                title: "Добавить приложение"
            ) {
                showAddAppWindow()
            }
            
            BarXActionButton(
                icon: "folder.badge.plus",
                title: "Создать папку"
            ) {
                openAddFolderWindow()
            }
            
            Divider()
                .opacity(0.3)
                .background(Color.white.opacity(0.3))
                .padding(.vertical, 4)
            
            BarXActionButton(
                icon: "power",
                title: "Выйти"
            ) {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(8)
    }
    
    private func loadPresets() {
        appState.loadPresets()
    }
    
    private func updateFilteredPresets() {
        if searchText.isEmpty {
            filteredPresets = appState.presets
        } else {
            filteredPresets = appState.presets.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.items.contains { $0.name.localizedCaseInsensitiveContains(searchText) }
            }
        }
    }
    
    private func openAddFolderWindow() {
        BarXWindowManager.shared.showWindow(
            id: "addFolder",
            title: "Новая папка",
            size: CGSize(width: 380, height: 420),
            content: AddFolderView(
                onAdded: {
                    appState.savePresets()
                    updateFilteredPresets()
                    refreshTrigger = UUID()
                }
            )
            .environmentObject(appState)
        )
    }
    
    private func openItemsWindow(for preset: Preset) {
        let windowID = "items-\(preset.id.uuidString)"
        BarXWindowManager.shared.showWindow(
            id: windowID,
            title: preset.name,
            size: CGSize(width: 420, height: 420),
            content: ItemsListView(
                presetName: preset.name,
                items: preset.items,
                onItemSelected: { item in
                    BarXWindowManager.shared.closeWindow(id: windowID)
                    launcherManager.openApp(item)
                    appState.addRecentApp(item)
                },
                onClose: {
                    BarXWindowManager.shared.closeWindow(id: windowID)
                }
            )
            .environmentObject(appState)
        )
    }
    
    private func openSettingsWindow() {
        BarXWindowManager.shared.showWindow(
            id: "settings",
            title: "Настройки BarX",
            size: CGSize(width: 900, height: 650),
            content: SettingsWindow()
                .environmentObject(appState)
        )
    }
}

// MARK: - FolderRow (без изменений)

struct FolderRow: View {
    let preset: Preset
    let isHovered: Bool
    let onTap: () -> Void
    let onHover: (Bool) -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: preset.icon)
                    .frame(width: 20)
                    .adaptiveTextColor()
                Text(preset.name)
                    .adaptiveTextColor()
                Spacer()
                if !preset.items.isEmpty {
                    Text("\(preset.items.count)")
                        .font(.caption)
                        .adaptiveTextColor()
                        .opacity(0.8)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.2))
                        .clipShape(Capsule())
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .adaptiveTextColor()
                    .opacity(0.4)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(HoverButtonStyle())
        .selectionBorder(
            isSelected: false,
            isHovered: isHovered
        )
        .onHover { hovering in
            onHover(hovering)
            if hovering {
                NSCursor.pointingHand.set()
            }
        }
    }
}

// MARK: - ItemsListView (исправлен)

struct ItemsListView: View {
    let presetName: String
    let items: [AppItem]
    let onItemSelected: (AppItem) -> Void
    let onClose: () -> Void
    @EnvironmentObject var appState: AppStateManager
    @StateObject private var themeManager = ThemeManager.shared
    @State private var hoveredItemId: UUID?
    
    var body: some View {
        ZStack {
            if let theme = themeManager.isPreviewMode ? themeManager.previewTheme : themeManager.selectedTheme {
                GradientBackground(theme: theme)
                    .ignoresSafeArea()
            }
            
            VStack(alignment: .leading, spacing: 0) {
                headerView
                Divider()
                    .opacity(0.3)
                    .background(Color.white.opacity(0.3))
                
                if items.isEmpty {
                    emptyStateView
                } else {
                    itemsListView
                }
            }
        }
        .frame(minWidth: 420, minHeight: 300)
    }
    
    private var headerView: some View {
        HStack {
            Image(systemName: "folder")
                .adaptiveTextColor()
            Text(presetName)
                .font(.headline)
                .adaptiveTextColor()
            Spacer()
            Text("\(items.count) элементов")
                .font(.caption)
                .adaptiveTextColor()
                .opacity(0.7)
            Button {
                onClose()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .adaptiveTextColor()
                    .opacity(0.7)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 10) {
            Image(systemName: "folder")
                .font(.system(size: 32))
                .adaptiveTextColor()
                .opacity(0.6)
            Text("Папка пустая")
                .adaptiveTextColor()
                .opacity(0.7)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var itemsListView: some View {
        ScrollView {
            VStack(spacing: 4) {
                ForEach(items) { item in
                    ItemRow(item: item) {
                        openItem(item)
                    }
                    .selectionBorder(
                        isSelected: false,
                        isHovered: hoveredItemId == item.id
                    )
                    .onHover { hovering in
                        if hovering {
                            hoveredItemId = item.id
                        } else {
                            hoveredItemId = nil
                        }
                    }
                }
            }
            .padding(8)
        }
    }
    
    private func openItem(_ item: AppItem) {
        switch item.type {
        case .url:
            // Открываем URL
            if let url = URL(string: item.path) {
                NSWorkspace.shared.open(url)
            }
            
        case .application:
            // Открываем приложение
            let url = URL(fileURLWithPath: item.path)
            if FileManager.default.fileExists(atPath: item.path) {
                let configuration = NSWorkspace.OpenConfiguration()
                NSWorkspace.shared.openApplication(
                    at: url,
                    configuration: configuration
                ) { _, error in
                    if let error {
                        print("Ошибка запуска: \(error)")
                        DispatchQueue.main.async {
                            showLaunchError(for: item)
                        }
                    }
                }
            } else {
                DispatchQueue.main.async {
                    showLaunchError(for: item)
                }
            }
            
        case .folder:
            // Открываем папку
            let url = URL(fileURLWithPath: item.path)
            if let bookmarkedURL = FileAccessHelper.shared.getBookmarkedURL(for: item.path) {
                NSWorkspace.shared.open(bookmarkedURL)
            } else {
                FileAccessHelper.shared.requestAccessAndOpen(path: item.path) { _ in }
            }
            
        case .action:
            print("Action: \(item.name)")
        }
    }
    
    private func showLaunchError(for item: AppItem) {
        let alert = NSAlert()
        alert.messageText = "Не удалось открыть элемент"
        alert.informativeText = "BarX не смог открыть:\n\(item.name)\n\nВозможно файл был удалён или перемещён."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Удалить из папки")
        
        let response = alert.runModal()
        if response == .alertSecondButtonReturn {
            // Удаляем элемент из папки
            if let presetIndex = appState.presets.firstIndex(where: { $0.items.contains(where: { $0.id == item.id }) }),
               let itemIndex = appState.presets[presetIndex].items.firstIndex(where: { $0.id == item.id }) {
                appState.presets[presetIndex].items.remove(at: itemIndex)
                appState.savePresets()
                // Обновляем представление
                appState.objectWillChange.send()
            }
        }
    }
}
// MARK: - ItemRow (исправлен)

struct ItemRow: View {
    let item: AppItem
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Правильная иконка в зависимости от типа
                Image(systemName: item.icon)
                    .frame(width: 20)
                    .adaptiveTextColor()
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.body)
                        .adaptiveTextColor()
                    
                    // Показываем путь или URL в зависимости от типа
                    if item.type == .url {
                        Text(item.path)
                            .font(.caption)
                            .adaptiveTextColor()
                            .opacity(0.7)
                            .lineLimit(1)
                    } else {
                        Text(item.path)
                            .font(.caption)
                            .adaptiveTextColor()
                            .opacity(0.7)
                            .lineLimit(1)
                    }
                }
                Spacer()
                
                // Показываем тип элемента
                if item.type == .url {
                    Image(systemName: "globe")
                        .font(.caption)
                        .adaptiveTextColor()
                        .opacity(0.5)
                }
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .adaptiveTextColor()
                    .opacity(0.5)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(HoverButtonStyle())
    }
}
// MARK: - AddFolderView (без изменений)

struct AddFolderView: View {
    let onAdded: () -> Void
    @EnvironmentObject var appState: AppStateManager
    @FocusState private var isNameFieldFocused: Bool
    @State private var folderName = ""
    @State private var selectedIcon = "folder"
    @State private var currentPage = 0
    @StateObject private var themeManager = ThemeManager.shared
    
    let icons = [
        "folder", "folder.fill", "folder.circle", "folder.circle.fill",
        "gamecontroller.fill", "briefcase.fill", "book.fill", "star.fill",
        "heart.fill", "music.note", "photo", "video", "pencil", "gear",
        "doc", "doc.fill", "link", "hammer", "wrench", "laptopcomputer",
        "iphone", "ipad", "applewatch", "airpods", "keyboard", "mouse",
        "display", "printer", "scanner", "camera", "camera.fill",
        "message", "mail", "phone", "calendar", "clock", "location",
        "map", "cloud", "sun.max", "moon", "paperplane", "paintbrush",
        "scissors", "cart", "bag", "gift", "house", "building.2"
    ]
    
    var displayedIcons: [String] {
        let start = currentPage * 20
        let end = min(start + 20, icons.count)
        return Array(icons[start..<end])
    }
    
    var totalPages: Int {
        Int(ceil(Double(icons.count) / 20.0))
    }
    
    var body: some View {
        ZStack {
            if let theme = themeManager.isPreviewMode ? themeManager.previewTheme : themeManager.selectedTheme {
                GradientBackground(theme: theme)
                    .ignoresSafeArea()
            }
            
            VStack(alignment: .leading, spacing: 16) {
                Text("Новая папка")
                    .font(.title2.bold())
                    .adaptiveTextColor()
                
                Divider()
                    .background(Color.white.opacity(0.3))
                
                nameField
                iconSelector
                Spacer()
                actionButtons
            }
            .padding(24)
            .frame(width: 380, height: 420)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    isNameFieldFocused = true
                }
            }
        }
    }
    
    private var nameField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Название")
                .font(.headline)
                .adaptiveTextColor()
            TextField("Введите название", text: $folderName)
                .textFieldStyle(.roundedBorder)
                .focused($isNameFieldFocused)
                .onSubmit {
                    createFolder()
                }
        }
    }
    
    private var iconSelector: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Иконка")
                .font(.headline)
                .adaptiveTextColor()
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHGrid(rows: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(displayedIcons, id: \.self) { icon in
                        Button {
                            selectedIcon = icon
                        } label: {
                            Image(systemName: icon)
                                .font(.system(size: 22))
                                .frame(width: 44, height: 44)
                                .background(
                                    selectedIcon == icon
                                    ? Color.white.opacity(0.3)
                                    : Color.white.opacity(0.1)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(
                                            selectedIcon == icon
                                            ? Color.white
                                            : Color.clear,
                                            lineWidth: 2
                                        )
                                )
                                .adaptiveTextColor()
                        }
                        .buttonStyle(.plain)
                        .onHover { hovering in
                            if hovering {
                                NSCursor.pointingHand.set()
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(height: 110)
            
            if totalPages > 1 {
                paginationView
            }
        }
    }
    
    private var paginationView: some View {
        HStack {
            Button {
                if currentPage > 0 {
                    currentPage -= 1
                }
            } label: {
                Image(systemName: "chevron.left")
                    .adaptiveTextColor()
                    .opacity(currentPage > 0 ? 1 : 0.3)
            }
            .buttonStyle(.plain)
            .disabled(currentPage == 0)
            
            Spacer()
            
            Text("\(currentPage + 1) / \(totalPages)")
                .font(.caption)
                .adaptiveTextColor()
                .opacity(0.7)
            
            Spacer()
            
            Button {
                if currentPage < totalPages - 1 {
                    currentPage += 1
                }
            } label: {
                Image(systemName: "chevron.right")
                    .adaptiveTextColor()
                    .opacity(currentPage < totalPages - 1 ? 1 : 0.3)
            }
            .buttonStyle(.plain)
            .disabled(currentPage >= totalPages - 1)
        }
        .padding(.top, 4)
    }
    
    private var actionButtons: some View {
        HStack {
            Button("Отмена") {
                BarXWindowManager.shared.closeWindow(id: "addFolder")
            }
            .buttonStyle(.bordered)
            .tint(.white)
            .keyboardShortcut(.cancelAction)
            
            Spacer()
            
            Button("Создать") {
                createFolder()
            }
            .buttonStyle(.borderedProminent)
            .tint(.white)
            .disabled(
                folderName
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .isEmpty
            )
            .keyboardShortcut(.defaultAction)
        }
    }
    
    private func createFolder() {
        let name = folderName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let newPreset = Preset(name: name, icon: selectedIcon)
        appState.addPreset(newPreset)
        onAdded()
        BarXWindowManager.shared.closeWindow(id: "addFolder")
    }
}

// MARK: - BarXActionButton (без изменений)

struct BarXActionButton: View {
    let icon: String
    let title: String
    var shortcut: String? = nil
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .frame(width: 20)
                    .adaptiveTextColor()
                Text(title)
                    .adaptiveTextColor()
                Spacer()
                if let shortcut {
                    Text(shortcut)
                        .font(.system(size: 11))
                        .adaptiveTextColor()
                        .opacity(0.7)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .buttonStyle(HoverButtonStyle())
    }
}

// MARK: - AddAppFromFinderView (исправлен)

struct AddAppFromFinderView: View {
    let onAppAdded: (AppItem) -> Void
    let onCancel: () -> Void
    @EnvironmentObject var appState: AppStateManager
    
    @State private var selectedURL: URL?
    @State private var appName = ""
    @State private var appPath = ""
    @State private var selectedIcon = "app.fill"
    @State private var isDragging = false
    @State private var showingFilePicker = false
    @State private var currentPage = 0
    @StateObject private var themeManager = ThemeManager.shared
    
    let icons = [
        "app.fill", "app", "folder", "folder.fill", "link", "link.circle",
        "doc", "doc.fill", "gear", "gearshape", "gear.circle", "hammer",
        "wrench", "pencil", "pencil.circle", "music.note", "music.note.list",
        "photo", "photo.fill", "video", "video.fill", "star.fill",
        "heart.fill", "safari", "network", "globe", "cloud", "cloud.fill",
        "envelope", "envelope.fill", "message", "message.fill", "phone",
        "phone.fill", "calendar", "calendar.circle", "clock", "clock.fill",
        "map", "map.fill", "location", "location.fill", "camera", "camera.fill",
        "printer", "printer.fill", "display", "iphone", "ipad", "applewatch"
    ]
    
    var displayedIcons: [String] {
        let start = currentPage * 20
        let end = min(start + 20, icons.count)
        return Array(icons[start..<end])
    }
    
    var totalPages: Int {
        Int(ceil(Double(icons.count) / 20.0))
    }
    
    var body: some View {
        ZStack {
            if let theme = themeManager.isPreviewMode ? themeManager.previewTheme : themeManager.selectedTheme {
                GradientBackground(theme: theme)
                    .ignoresSafeArea()
            }
            
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Добавить приложение")
                        .font(.title2.bold())
                        .adaptiveTextColor()
                    
                    Spacer()
                    
                    Button {
                        onCancel()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .adaptiveTextColor()
                            .opacity(0.7)
                    }
                    .buttonStyle(.plain)
                }
                
                Divider()
                    .background(Color.white.opacity(0.3))
                
                VStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isDragging ? Color.white : Color.white.opacity(0.3),
                                style: StrokeStyle(lineWidth: isDragging ? 3 : 2, dash: [6, 4])
                            )
                            .fill(
                                isDragging ? Color.white.opacity(0.08) : Color.clear
                            )
                            .frame(height: 120)
                        
                        VStack(spacing: 12) {
                            Image(systemName: "app.dashed")
                                .font(.system(size: 36))
                                .adaptiveTextColor()
                                .opacity(0.5)
                            
                            Text("Перетащите приложение сюда")
                                .font(.headline)
                                .adaptiveTextColor()
                                .opacity(0.7)
                            
                            Text("или")
                                .font(.caption)
                                .adaptiveTextColor()
                                .opacity(0.5)
                            
                            Button("Выбрать в Finder") {
                                showingFilePicker = true
                            }
                            .buttonStyle(.bordered)
                            .tint(.white)
                            .controlSize(.small)
                        }
                    }
                    .onDrop(of: [.fileURL], isTargeted: $isDragging) { providers in
                        handleDrop(providers: providers)
                        return true
                    }
                }
                
                if selectedURL != nil {
                    VStack(alignment: .leading, spacing: 12) {
                        Divider()
                            .background(Color.white.opacity(0.3))
                        
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Приложение выбрано:")
                                .adaptiveTextColor()
                            Text(appName)
                                .font(.headline)
                                .adaptiveTextColor()
                        }
                        
                        if appState.isInFavorites(AppItem(name: appName, path: appPath, icon: selectedIcon, preset: "Все приложения")) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.yellow)
                                Text("Это приложение уже добавлено в избранное")
                                    .font(.caption)
                                    .adaptiveTextColor()
                                    .opacity(0.7)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Выберите иконку")
                                .font(.subheadline)
                                .adaptiveTextColor()
                                .opacity(0.7)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHGrid(rows: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                                    ForEach(displayedIcons, id: \.self) { icon in
                                        Button {
                                            selectedIcon = icon
                                        } label: {
                                            Image(systemName: icon)
                                                .font(.system(size: 18))
                                                .frame(width: 36, height: 36)
                                                .background(
                                                    selectedIcon == icon
                                                    ? Color.white.opacity(0.3)
                                                    : Color.white.opacity(0.1)
                                                )
                                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 6)
                                                        .stroke(
                                                            selectedIcon == icon
                                                            ? Color.white
                                                            : Color.clear,
                                                            lineWidth: 2
                                                        )
                                                )
                                                .adaptiveTextColor()
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                            .frame(height: 80)
                            
                            if totalPages > 1 {
                                HStack {
                                    Button {
                                        if currentPage > 0 { currentPage -= 1 }
                                    } label: {
                                        Image(systemName: "chevron.left")
                                            .adaptiveTextColor()
                                            .opacity(currentPage > 0 ? 1 : 0.3)
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(currentPage == 0)
                                    
                                    Spacer()
                                    
                                    Text("\(currentPage + 1) / \(totalPages)")
                                        .font(.caption)
                                        .adaptiveTextColor()
                                        .opacity(0.7)
                                    
                                    Spacer()
                                    
                                    Button {
                                        if currentPage < totalPages - 1 { currentPage += 1 }
                                    } label: {
                                        Image(systemName: "chevron.right")
                                            .adaptiveTextColor()
                                            .opacity(currentPage < totalPages - 1 ? 1 : 0.3)
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(currentPage >= totalPages - 1)
                                }
                                .padding(.top, 4)
                            }
                        }
                    }
                }
                
                Spacer()
                
                HStack {
                    Button("Отмена") {
                        onCancel()
                    }
                    .buttonStyle(.bordered)
                    .tint(.white)
                    
                    Spacer()
                    
                    Button("Добавить") {
                        addApp()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.white)
                    .disabled(selectedURL == nil || appState.isInFavorites(AppItem(name: appName, path: appPath, icon: selectedIcon, preset: "Все приложения")))
                }
            }
            .padding(24)
            .frame(width: 500, height: 600)
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: [.application]
            ) { result in
                switch result {
                case .success(let url):
                    processSelectedURL(url)
                case .failure(let error):
                    print("Ошибка выбора файла: \(error)")
                }
            }
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { (item, error) in
                if let data = item as? Data,
                   let url = URL(dataRepresentation: data, relativeTo: nil) {
                    DispatchQueue.main.async {
                        processSelectedURL(url)
                    }
                }
            }
        }
        return true
    }
    
    private func processSelectedURL(_ url: URL) {
        if url.pathExtension == "app" {
            selectedURL = url
            appName = url.deletingPathExtension().lastPathComponent
            appPath = url.path
        } else {
            let alert = NSAlert()
            alert.messageText = "Неверный файл"
            alert.informativeText = "Пожалуйста, выберите файл приложения (.app)"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
    
    private func addApp() {
        guard let url = selectedURL else { return }
        
        let app = AppItem(
            name: appName,
            path: appPath,
            icon: selectedIcon,
            preset: "Все приложения",
            type: .application
        )
        
        onAppAdded(app)
    }
}

// MARK: - SettingsWindow (исправлен с поиском)

struct SettingsWindow: View {
    @EnvironmentObject var appState: AppStateManager
    @State private var selectedCategory: SettingsCategory = .apps
    @State private var isHoveringMainMenu = false
    @State private var hoveredCategory: SettingsCategory?
    @State private var searchText = ""
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var launcherManager = LauncherManager.shared
    
    // Фильтрованные категории для поиска
    private var filteredCategories: [SettingsCategory] {
        if searchText.isEmpty {
            return SettingsCategory.allCases
        }
        return SettingsCategory.allCases.filter {
            $0.rawValue.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        ZStack {
            if let theme = themeManager.isPreviewMode ? themeManager.previewTheme : themeManager.selectedTheme {
                GradientBackground(theme: theme)
                    .ignoresSafeArea()
            }
            
            HStack(spacing: 0) {
                SettingsSidebar(
                    selectedCategory: $selectedCategory,
                    hoveredCategory: $hoveredCategory,
                    searchText: $searchText,
                    filteredCategories: filteredCategories
                )
                .frame(width: 200)
                
                Divider()
                    .background(Color.white.opacity(0.3))
                
                VStack(spacing: 0) {
                    settingsHeader
                    Divider()
                        .opacity(0.3)
                        .background(Color.white.opacity(0.3))
                    
                    ScrollView {
                        SettingsContent(
                            category: selectedCategory,
                            onSave: {
                                appState.saveAllState()
                                NotificationCenter.default.post(name: .presetsDidChange, object: nil)
                            }
                        )
                        .padding(24)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(width: 900, height: 650)
        }
    }
    
    private var settingsHeader: some View {
        HStack {
            Text(selectedCategory.rawValue)
                .font(.title2.bold())
                .adaptiveTextColor()
            Spacer()
            Button {
                BarXWindowManager.shared.showMainMenu()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.left")
                        .adaptiveTextColor()
                    Text("Главное меню")
                        .adaptiveTextColor()
                }
                .font(.system(size: 13, weight: .medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            isHoveringMainMenu ? Color.white.opacity(0.2) : Color.white.opacity(0.1)
                        )
                )
                .scaleEffect(isHoveringMainMenu ? 1.05 : 1.0)
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isHoveringMainMenu = hovering
                }
                if hovering {
                    NSCursor.pointingHand.set()
                }
            }
            .help("Показать главное меню")
            
            Button {
                BarXWindowManager.shared.closeWindow(id: "settings")
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .adaptiveTextColor()
                    .opacity(0.7)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 16)
    }
}

// MARK: - SettingsSidebar (с поиском)

struct SettingsSidebar: View {
    @Binding var selectedCategory: SettingsCategory
    @Binding var hoveredCategory: SettingsCategory?
    @Binding var searchText: String
    let filteredCategories: [SettingsCategory]
    @StateObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            searchField
            ScrollView {
                VStack(spacing: 2) {
                    ForEach(filteredCategories, id: \.self) { category in
                        categoryRow(for: category)
                    }
                    
                    if filteredCategories.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 20))
                                .adaptiveTextColor()
                                .opacity(0.4)
                            Text("Ничего не найдено")
                                .font(.caption)
                                .adaptiveTextColor()
                                .opacity(0.5)
                        }
                        .padding(.vertical, 20)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
            }
        }
        .background(Color.white.opacity(0.05))
    }
    
    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .adaptiveTextColor()
                .opacity(0.7)
            TextField("Поиск категорий...", text: $searchText)
                .textFieldStyle(.plain)
                .adaptiveTextColor()
                .font(.system(size: 13))
            
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .adaptiveTextColor()
                        .opacity(0.5)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white.opacity(0.1))
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }
    
    private func categoryRow(for category: SettingsCategory) -> some View {
        HStack {
            Image(systemName: category.icon)
                .frame(width: 20)
                .adaptiveTextColor()
            Text(category.rawValue)
                .adaptiveTextColor()
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(
                    selectedCategory == category
                        ? Color.white.opacity(0.15)
                        : (hoveredCategory == category ? Color.white.opacity(0.08) : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(
                            selectedCategory == category
                                ? Color.white.opacity(0.3)
                                : Color.clear,
                            lineWidth: 1.5
                        )
                )
        )
        .onTapGesture {
            selectedCategory = category
        }
        .onHover { hovering in
            hoveredCategory = hovering ? category : nil
            if hovering {
                NSCursor.pointingHand.set()
            }
        }
        .animation(.easeInOut(duration: 0.15), value: selectedCategory)
    }
}

// MARK: - SettingsContent (обновлён)

struct SettingsContent: View {
    let category: SettingsCategory
    let onSave: () -> Void
    @EnvironmentObject var appState: AppStateManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            switch category {
            case .general:
                GeneralSettingsView()
            case .appearance:
                AppearanceSettingsView()
            case .apps:
                AppsSettingsView()
            case .bar:
                BarSettingsView()
            case .presets:
                PresetsSettingsView(onSave: onSave)
            case .launcher:
                LauncherSettingsView()
            case .about:
                AboutView()
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

// MARK: - GeneralSettingsView

struct GeneralSettingsView: View {
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("showPresetCount") private var showPresetCount = true
    @AppStorage("animationSpeed") private var animationSpeed: Double = 0.3
    @AppStorage("showNotifications") private var showNotifications = true
    @AppStorage("showAppIcons") private var showAppIcons = true
    @AppStorage("autoRefreshApps") private var autoRefreshApps = true
    @StateObject private var launcherManager = LauncherManager.shared
    @StateObject private var themeManager = ThemeManager.shared
    @State private var showingResetAlert = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Основные настройки")
                .font(.headline)
                .adaptiveTextColor()
            
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Запускать BarX вместе с macOS", isOn: $launchAtLogin)
                    .toggleStyle(SwitchToggleStyle(tint: .white))
                    .adaptiveTextColor()
                
                Toggle("Показывать количество элементов в папках", isOn: $showPresetCount)
                    .toggleStyle(SwitchToggleStyle(tint: .white))
                    .adaptiveTextColor()
                
                Toggle("Показывать уведомления", isOn: $showNotifications)
                    .toggleStyle(SwitchToggleStyle(tint: .white))
                    .adaptiveTextColor()
                
                Toggle("Показывать значки приложений", isOn: $showAppIcons)
                    .toggleStyle(SwitchToggleStyle(tint: .white))
                    .adaptiveTextColor()
                
                Toggle("Автоматически обновлять список приложений", isOn: $autoRefreshApps)
                    .toggleStyle(SwitchToggleStyle(tint: .white))
                    .adaptiveTextColor()
                    .onChange(of: autoRefreshApps) { newValue in
                        if newValue {
                            AppStateManager.shared.refreshApps()
                        }
                    }
            }
            
            Divider()
                .background(Color.white.opacity(0.3))
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Скорость анимации")
                    .adaptiveTextColor()
                    .opacity(0.7)
                
                VStack(spacing: 4) {
                    Slider(value: $animationSpeed, in: 0.1...0.8, step: 0.05)
                        .tint(.white)
                    
                    HStack {
                        Text("Медленно")
                            .font(.caption)
                            .adaptiveTextColor()
                            .opacity(0.5)
                        Spacer()
                        Text(String(format: "%.2fс", animationSpeed))
                            .font(.caption)
                            .adaptiveTextColor()
                            .opacity(0.7)
                        Spacer()
                        Text("Быстро")
                            .font(.caption)
                            .adaptiveTextColor()
                            .opacity(0.5)
                    }
                }
            }
            
            Divider()
                .background(Color.white.opacity(0.3))
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Launcher")
                    .font(.subheadline)
                    .adaptiveTextColor()
                    .opacity(0.7)
                
                Toggle("Включить Launcher", isOn: $launcherManager.launcherEnabled)
                    .toggleStyle(SwitchToggleStyle(tint: .white))
                    .adaptiveTextColor()
                    .onChange(of: launcherManager.launcherEnabled) { newValue in
                        if newValue {
                            launcherManager.setupHotkeys()
                        } else {
                            launcherManager.hideLauncher()
                            launcherManager.cleanup()
                        }
                    }
                
                if launcherManager.launcherEnabled {
                    HStack {
                        Text("Горячая клавиша")
                            .adaptiveTextColor()
                            .opacity(0.7)
                        
                        Spacer()
                        
                        HotkeyRecorder(hotkey: $launcherManager.launcherHotkeyKey) { newHotkey in
                            launcherManager.launcherHotkeyKey = newHotkey
                            launcherManager.setupHotkeys()
                        }
                    }
                }
            }
            
            Divider()
                .background(Color.white.opacity(0.3))
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Сброс")
                    .font(.subheadline)
                    .adaptiveTextColor()
                    .opacity(0.7)
                
                Button("Сбросить все настройки") {
                    showingResetAlert = true
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .alert("Сброс настроек", isPresented: $showingResetAlert) {
                    Button("Отмена", role: .cancel) { }
                    Button("Сбросить", role: .destructive) {
                        resetAllSettings()
                    }
                } message: {
                    Text("Все настройки будут сброшены к значениям по умолчанию. Это действие нельзя отменить.")
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func resetAllSettings() {
        // Очищаем все UserDefaults
        let defaults = UserDefaults.standard
        let dictionary = defaults.dictionaryRepresentation()
        for key in dictionary.keys {
            defaults.removeObject(forKey: key)
        }
        defaults.synchronize()
        
        // Перезагружаем состояние приложений
        AppStateManager.shared.loadAllState()
        AppStateManager.shared.scanInstalledApps()
        
        // Сбрасываем Launcher
        LauncherManager.shared.launcherEnabled = true
        LauncherManager.shared.launcherHotkeyKey = "⌘⇧B"
        LauncherManager.shared.setupHotkeys()
        
        // Сбрасываем тему - используем существующие публичные методы
        // Перезагружаем дефолтные темы через публичный метод reloadThemes
        ThemeManager.shared.reloadThemes()
        
        // Выбираем первую тему
        if let firstTheme = ThemeManager.shared.themes.first {
            ThemeManager.shared.selectTheme(firstTheme, applyImmediately: true)
        }
    }
}
// MARK: - AppearanceSettingsView (без прозрачности)

struct AppearanceSettingsView: View {
    @StateObject private var themeManager = ThemeManager.shared
    @State private var customColor1 = Color.blue
    @State private var customColor2 = Color.purple
    @State private var customColor3 = Color.pink
    @State private var customColor4 = Color.orange
    @State private var selectedDirection: GradientDirection = .horizontal
    @State private var showOnlyCustom = false
    @State private var selectedTextColor: Theme.TextColor = .auto
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Toggle("Показать только свои темы", isOn: $showOnlyCustom)
                    .toggleStyle(SwitchToggleStyle(tint: .white))
                    .adaptiveTextColor()
                    .onChange(of: showOnlyCustom) {
                        themeManager.objectWillChange.send()
                    }
            }
            .padding(.bottom, 4)
            
            Text("Внешний вид")
                .font(.headline)
                .adaptiveTextColor()
            
            previewView
            
            Divider()
                .background(Color.white.opacity(0.3))
            
            gradientsSection
            
            Divider()
                .background(Color.white.opacity(0.3))
            
            customThemeSection
        }
        .padding()
    }
    
    private var previewView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Предпросмотр")
                .font(.subheadline)
                .adaptiveTextColor()
                .opacity(0.7)
            
            let previewTheme = themeManager.isPreviewMode ? themeManager.previewTheme : themeManager.selectedTheme
            
            ZStack {
                if let theme = previewTheme {
                    GradientBackground(theme: theme)
                        .cornerRadius(12)
                    HStack(spacing: 12) {
                        Image(systemName: "sparkles")
                            .adaptiveTextColor()
                        Text("BarX Preview")
                            .adaptiveTextColor()
                        Spacer()
                        Image(systemName: "gearshape")
                            .adaptiveTextColor()
                            .opacity(0.8)
                    }
                    .padding()
                } else {
                    Color.gray.opacity(0.2)
                        .cornerRadius(12)
                }
            }
            .frame(height: 60)
            
            if themeManager.isPreviewMode {
                HStack {
                    Button("Применить тему") {
                        themeManager.applyPreviewTheme()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    
                    Button("Отменить") {
                        themeManager.cancelPreview()
                    }
                    .buttonStyle(.bordered)
                    .tint(.white)
                }
            }
        }
    }
    
    private var gradientsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Градиенты")
                .font(.subheadline)
                .adaptiveTextColor()
                .opacity(0.7)
            
            let gradientThemes = (showOnlyCustom ? themeManager.getCustomThemes() : themeManager.getDefaultThemes())
                .filter { $0.isGradient }
            
            if !gradientThemes.isEmpty {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(gradientThemes) { theme in
                        ThemeButton(theme: theme, isCustom: theme.isCustom) {
                            themeManager.selectTheme(theme, applyImmediately: false)
                        } onDelete: {
                            themeManager.deleteCustomTheme(theme)
                        }
                    }
                }
            }
        }
    }
    
    private var customThemeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Создать свою тему")
                .font(.subheadline)
                .adaptiveTextColor()
                .opacity(0.7)
            
            Text("Выберите до 4 цветов")
                .font(.caption)
                .adaptiveTextColor()
                .opacity(0.6)
            
            HStack(spacing: 15) {
                ColorPicker("Цвет 1", selection: $customColor1)
                    .labelsHidden()
                    .frame(width: 40, height: 40)
                ColorPicker("Цвет 2", selection: $customColor2)
                    .labelsHidden()
                    .frame(width: 40, height: 40)
                ColorPicker("Цвет 3", selection: $customColor3)
                    .labelsHidden()
                    .frame(width: 40, height: 40)
                ColorPicker("Цвет 4", selection: $customColor4)
                    .labelsHidden()
                    .frame(width: 40, height: 40)
            }
            
            Picker("Направление градиента", selection: $selectedDirection) {
                ForEach(GradientDirection.allCases, id: \.self) { direction in
                    Text(direction.rawValue).tag(direction)
                }
            }
            .pickerStyle(.segmented)
            .colorMultiply(.white)
            
            Picker("Цвет текста", selection: $selectedTextColor) {
                ForEach(Theme.TextColor.allCases, id: \.self) { color in
                    Text(color.rawValue).tag(color)
                }
            }
            .pickerStyle(.segmented)
            .colorMultiply(.white)
            
            Button {
                applyCustomTheme()
            } label: {
                HStack {
                    Image(systemName: "sparkles")
                        .adaptiveTextColor()
                    Text("Добавить свою тему")
                        .adaptiveTextColor()
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.white)
        }
    }
    
    private func applyCustomTheme() {
        let colors = [customColor1, customColor2, customColor3, customColor4]
            .map { $0.toHex() }
            .filter { !$0.isEmpty }
        
        let theme = Theme(
            name: "Моя тема \(themeManager.getCustomThemes().count + 1)",
            colors: colors,
            isGradient: colors.count >= 2,
            gradientDirection: selectedDirection.rawValue,
            isCustom: true,
            textColor: selectedTextColor
        )
        
        themeManager.addCustomTheme(theme)
        themeManager.selectTheme(theme, applyImmediately: false)
    }
}

// MARK: - ThemeButton (без изменений)

struct ThemeButton: View {
    let theme: Theme
    let isCustom: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void
    @StateObject private var themeManager = ThemeManager.shared
    @State private var isHovered = false
    
    var isSelected: Bool {
        let currentTheme = themeManager.isPreviewMode ? themeManager.previewTheme : themeManager.selectedTheme
        return currentTheme?.id == theme.id
    }
    
    var body: some View {
        VStack(spacing: 6) {
            Button {
                onSelect()
            } label: {
                ZStack {
                    GradientBackground(theme: theme)
                        .cornerRadius(8)
                        .frame(height: 40)
                    
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.white)
                            .font(.title2)
                    }
                    
                    if isCustom {
                        VStack {
                            HStack {
                                Spacer()
                                Image(systemName: "pencil.circle.fill")
                                    .foregroundStyle(.white.opacity(0.8))
                                    .font(.system(size: 14))
                                    .padding(4)
                            }
                            Spacer()
                        }
                    }
                }
                .selectionBorder(
                    isSelected: isSelected,
                    isHovered: isHovered
                )
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovered = hovering
                }
                if hovering {
                    NSCursor.pointingHand.set()
                }
            }
            .contextMenu {
                if isCustom {
                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Label("Удалить тему", systemImage: "trash")
                    }
                }
            }
            
            HStack {
                Text(theme.name)
                    .font(.caption)
                    .adaptiveTextColor()
                    .lineLimit(1)
                
                if isCustom {
                    Button {
                        onDelete()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.red.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    .help("Удалить тему")
                }
            }
        }
    }
}

// MARK: - AppsSettingsView (исправлен)

struct AppsSettingsView: View {
    @EnvironmentObject var appState: AppStateManager
    @State private var searchText = ""
    @State private var selectedFilter: AppFilter = .all
    @State private var hoveredAppId: UUID?
    @State private var isDragging = false
    @State private var selectedApps: Set<UUID> = []
    @State private var isEditMode = false
    
    enum AppFilter: String, CaseIterable {
        case all = "Все"
        case favorites = "Избранные"
        case bar = "В панели"
        case recent = "Недавние"
    }
    
    var filteredApps: [AppItem] {
        var apps: [AppItem] = []
        
        switch selectedFilter {
        case .all:
            apps = appState.installedApps
        case .favorites:
            apps = appState.favoriteApps
        case .bar:
            apps = appState.barApps
        case .recent:
            apps = appState.recentApps
        }
        
        if !searchText.isEmpty {
            apps = apps.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        
        return apps
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerView
            filterView
            appsListView
        }
    }
    
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Управление приложениями")
                        .font(.title2.bold())
                        .adaptiveTextColor()
                    
                    Text("Управляйте приложениями в BarX. Добавляйте в избранное или в панель.")
                        .font(.caption)
                        .adaptiveTextColor()
                        .opacity(0.7)
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    Button {
                        if isEditMode {
                            for id in selectedApps {
                                if let app = filteredApps.first(where: { $0.id == id }) {
                                    appState.removeFromFavorites(app)
                                    appState.removeFromBar(app)
                                }
                            }
                            selectedApps.removeAll()
                            isEditMode = false
                        } else {
                            isEditMode = true
                        }
                    } label: {
                        Text(isEditMode ? "Удалить" : "Выбрать")
                            .font(.system(size: 13, weight: .medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(isEditMode ? Color.red.opacity(0.2) : Color.white.opacity(0.1))
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(filteredApps.isEmpty)
                    
                    Button {
                        appState.refreshApps()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.clockwise")
                            Text("Обновить")
                        }
                        .font(.system(size: 13, weight: .medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.white.opacity(0.1))
                        )
                    }
                    .buttonStyle(.plain)
                    .help("Обновить список приложений")
                    
                    Button {
                        showAddAppWindow()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                            Text("Добавить")
                        }
                        .font(.system(size: 13, weight: .medium))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white.opacity(0.15))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .help("Добавить приложение из Finder")
                }
            }
        }
    }
    
    private func showAddAppWindow() {
        BarXWindowManager.shared.showWindow(
            id: "addApp",
            title: "Добавить приложение",
            size: CGSize(width: 500, height: 600),
            content: AddAppFromFinderView(
                onAppAdded: { app in
                    appState.addToFavorites(app)
                    appState.addToBar(app)
                    BarXWindowManager.shared.closeWindow(id: "addApp")
                },
                onCancel: {
                    BarXWindowManager.shared.closeWindow(id: "addApp")
                }
            )
            .environmentObject(appState)
        )
    }
    
    private var filterView: some View {
        HStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .adaptiveTextColor()
                    .opacity(0.5)
                TextField("Поиск приложений...", text: $searchText)
                    .textFieldStyle(.plain)
                    .adaptiveTextColor()
                
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
            
            Spacer()
            
            Picker("Фильтр", selection: $selectedFilter) {
                ForEach(AppFilter.allCases, id: \.self) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 300)
        }
    }
    
    private var appsListView: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                if appState.isLoading {
                    loadingView
                } else if filteredApps.isEmpty {
                    emptyStateView
                } else {
                    ForEach(filteredApps) { app in
                        AppCardView(
                            app: app,
                            isFavorite: appState.isInFavorites(app),
                            isInBar: appState.isInBar(app),
                            isRecent: appState.recentApps.contains(where: { $0.id == app.id }),
                            isSelected: selectedApps.contains(app.id),
                            isEditMode: isEditMode,
                            onToggleSelect: {
                                if selectedApps.contains(app.id) {
                                    selectedApps.remove(app.id)
                                } else {
                                    selectedApps.insert(app.id)
                                }
                            },
                            onToggleFavorite: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    appState.toggleFavorite(app)
                                }
                            },
                            onToggleBar: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    if appState.isInBar(app) {
                                        appState.removeFromBar(app)
                                    } else {
                                        appState.addToBar(app)
                                    }
                                }
                            },
                            onLaunch: {
                                LauncherManager.shared.openApp(app)
                                appState.addRecentApp(app)
                            },
                            onRemove: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    appState.removeFromFavorites(app)
                                    appState.removeFromBar(app)
                                }
                            }
                        )
                        .onHover { hovering in
                            hoveredAppId = hovering ? app.id : nil
                            if hovering {
                                NSCursor.pointingHand.set()
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .frame(minHeight: 300)
        .onDrop(of: [.fileURL], isTargeted: $isDragging) { providers in
            handleDrop(providers: providers)
            return true
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(1.5)
                .adaptiveTextColor()
            Text("Загрузка приложений...")
                .font(.caption)
                .adaptiveTextColor()
                .opacity(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "app.dashed")
                .font(.system(size: 48))
                .adaptiveTextColor()
                .opacity(0.5)
            
            Text("Нет приложений")
                .font(.headline)
                .adaptiveTextColor()
                .opacity(0.7)
            
            Text(searchText.isEmpty ? "Нажмите «Добавить» чтобы добавить приложение" : "Попробуйте изменить поисковый запрос")
                .font(.caption)
                .adaptiveTextColor()
                .opacity(0.5)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { (item, error) in
                if let data = item as? Data,
                   let url = URL(dataRepresentation: data, relativeTo: nil) {
                    DispatchQueue.main.async {
                        addAppFromURL(url)
                    }
                }
            }
        }
        return true
    }
    
    private func addAppFromURL(_ url: URL) {
        if url.pathExtension == "app" {
            let name = url.deletingPathExtension().lastPathComponent
            let icon = getIconForApplication(name)
            let app = AppItem(
                name: name,
                path: url.path,
                icon: icon,
                preset: "Все приложения",
                type: .application
            )
            
            if !appState.isInFavorites(app) {
                appState.addToFavorites(app)
                appState.addToBar(app)
            }
        }
    }
    
    private func getIconForApplication(_ name: String) -> String {
        let iconMap: [String: String] = [
            "Safari": "safari",
            "Finder": "finder",
            "Messages": "message",
            "Mail": "envelope",
            "Calendar": "calendar",
            "Photos": "photo",
            "Music": "music.note",
            "FaceTime": "video",
            "Maps": "map",
            "Notes": "note.text",
            "Reminders": "checklist",
            "Podcasts": "mic",
            "TV": "tv",
            "Books": "book",
            "App Store": "appstore",
            "System Settings": "gear"
        ]
        return iconMap[name] ?? "app.fill"
    }
}

// MARK: - AppCardView (без изменений)

struct AppCardView: View {
    let app: AppItem
    let isFavorite: Bool
    let isInBar: Bool
    let isRecent: Bool
    let isSelected: Bool
    let isEditMode: Bool
    let onToggleSelect: () -> Void
    let onToggleFavorite: () -> Void
    let onToggleBar: () -> Void
    let onLaunch: () -> Void
    let onRemove: () -> Void
    
    @State private var isHovered = false
    @State private var isRemoving = false
    @State private var appIcon: NSImage?
    @State private var isLoadingIcon = false
    
    var body: some View {
        HStack(spacing: 12) {
            if isEditMode {
                Button {
                    onToggleSelect()
                } label: {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20))
                        .foregroundStyle(isSelected ? .green : .white.opacity(0.4))
                }
                .buttonStyle(.plain)
            }
            
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 40, height: 40)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                
                if let icon = appIcon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 28, height: 28)
                } else {
                    Image(systemName: app.icon)
                        .font(.system(size: 18))
                        .adaptiveTextColor()
                }
            }
            .onAppear {
                loadAppIcon()
            }
            
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(app.name)
                        .font(.headline)
                        .adaptiveTextColor()
                    
                    if isFavorite {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.yellow)
                    }
                    
                    if isInBar {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.blue)
                    }
                    
                    if isRecent {
                        Text("Недавнее")
                            .font(.system(size: 9, weight: .medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(
                                Capsule()
                                    .fill(Color.blue.opacity(0.3))
                            )
                            .adaptiveTextColor()
                    }
                }
                
                Text(app.path)
                    .font(.caption)
                    .adaptiveTextColor()
                    .opacity(0.5)
                    .lineLimit(1)
            }
            
            Spacer()
            
            HStack(spacing: 6) {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        onToggleFavorite()
                    }
                } label: {
                    Image(systemName: isFavorite ? "star.fill" : "star")
                        .font(.system(size: 14))
                        .foregroundStyle(isFavorite ? .yellow : .white.opacity(0.5))
                }
                .buttonStyle(.plain)
                .help(isFavorite ? "Убрать из избранного" : "Добавить в избранное")
                
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        onToggleBar()
                    }
                } label: {
                    Image(systemName: isInBar ? "pin.fill" : "pin")
                        .font(.system(size: 14))
                        .foregroundStyle(isInBar ? .blue : .white.opacity(0.5))
                }
                .buttonStyle(.plain)
                .help(isInBar ? "Убрать из панели" : "Добавить в панель")
                
                if !isEditMode {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            isRemoving = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                onRemove()
                                isRemoving = false
                            }
                        }
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 14))
                            .foregroundStyle(.red.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                    .help("Удалить из BarX")
                }
                
                Button {
                    onLaunch()
                } label: {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.green, .blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .buttonStyle(.plain)
                .help("Запустить")
            }
            .opacity(isHovered || isEditMode ? 1 : 0.4)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    isRemoving ? Color.red.opacity(0.1) :
                    isSelected ? Color.blue.opacity(0.15) :
                    isHovered ? Color.white.opacity(0.08) : Color.clear
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(
                            isSelected ? Color.blue.opacity(0.5) :
                            isHovered ? Color.white.opacity(0.15) : Color.clear,
                            lineWidth: isSelected ? 2 : 1
                        )
                )
        )
        .scaleEffect(isRemoving ? 0.95 : 1.0)
        .opacity(isRemoving ? 0.5 : 1.0)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
    
    private func loadAppIcon() {
        guard !isLoadingIcon else { return }
        isLoadingIcon = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let url = URL(fileURLWithPath: app.path)
            let icon = NSWorkspace.shared.icon(forFile: url.path)
            
            if icon.size.width > 0 {
                let resized = icon.resized(to: NSSize(width: 28, height: 28))
                DispatchQueue.main.async {
                    self.appIcon = resized
                    self.isLoadingIcon = false
                }
            } else {
                DispatchQueue.main.async {
                    self.isLoadingIcon = false
                }
            }
        }
    }
}

// MARK: - BarSettingsView (без изменений)

struct BarSettingsView: View {
    @EnvironmentObject var appState: AppStateManager
    @State private var searchText = ""
    @State private var hoveredAppId: UUID?
    
    var filteredBarApps: [AppItem] {
        if searchText.isEmpty {
            return appState.barApps
        }
        return appState.barApps.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Панель Bar")
                .font(.headline)
                .adaptiveTextColor()
            
            Text("Приложения, добавленные в панель, отображаются в главном меню BarX.")
                .font(.caption)
                .adaptiveTextColor()
                .opacity(0.7)
            
            HStack {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .adaptiveTextColor()
                        .opacity(0.5)
                    TextField("Поиск в панели...", text: $searchText)
                        .textFieldStyle(.plain)
                        .adaptiveTextColor()
                    
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                )
                
                Spacer()
                
                Text("\(appState.barApps.count) приложений")
                    .font(.caption)
                    .adaptiveTextColor()
                    .opacity(0.5)
            }
            
            if appState.barApps.isEmpty {
                emptyStateView
            } else if filteredBarApps.isEmpty {
                noResultsView
            } else {
                barAppsListView
            }
        }
        .padding(.vertical, 4)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "menubar.rectangle")
                .font(.system(size: 32))
                .adaptiveTextColor()
                .opacity(0.5)
            Text("Нет приложений в панели")
                .adaptiveTextColor()
                .opacity(0.7)
            Text("Добавьте приложения в панель через раздел «Приложения»")
                .font(.caption)
                .adaptiveTextColor()
                .opacity(0.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    private var noResultsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 28))
                .adaptiveTextColor()
                .opacity(0.4)
            Text("Ничего не найдено")
                .adaptiveTextColor()
                .opacity(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }
    
    private var barAppsListView: some View {
        ScrollView {
            VStack(spacing: 4) {
                ForEach(filteredBarApps) { app in
                    BarAppRow(
                        app: app,
                        isHovered: hoveredAppId == app.id,
                        onRemove: {
                            appState.removeFromBar(app)
                        },
                        onLaunch: {
                            LauncherManager.shared.openApp(app)
                            appState.addRecentApp(app)
                        }
                    )
                    .onHover { hovering in
                        hoveredAppId = hovering ? app.id : nil
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .frame(minHeight: 150)
    }
}

// MARK: - BarAppRow (без изменений)

struct BarAppRow: View {
    let app: AppItem
    let isHovered: Bool
    let onRemove: () -> Void
    let onLaunch: () -> Void
    @EnvironmentObject var appState: AppStateManager
    @State private var appIcon: NSImage?
    @State private var isLoadingIcon = false
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 32, height: 32)
                
                if let icon = appIcon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 22, height: 22)
                } else {
                    Image(systemName: app.icon)
                        .font(.system(size: 14))
                        .adaptiveTextColor()
                }
            }
            .onAppear {
                loadAppIcon()
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(app.name)
                    .font(.body)
                    .adaptiveTextColor()
                Text(app.path)
                    .font(.caption)
                    .adaptiveTextColor()
                    .opacity(0.5)
                    .lineLimit(1)
            }
            
            Spacer()
            
            if appState.isInFavorites(app) {
                Image(systemName: "star.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.yellow.opacity(0.7))
            }
            
            Button {
                onLaunch()
            } label: {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.green)
            }
            .buttonStyle(.plain)
            .help("Запустить")
            
            Button {
                onRemove()
            } label: {
                Image(systemName: "pin.slash.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.red.opacity(isHovered ? 0.8 : 0.3))
            }
            .buttonStyle(.plain)
            .help("Убрать из панели")
            .opacity(isHovered ? 1 : 0.5)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered ? Color.white.opacity(0.06) : Color.clear)
        )
        .animation(.easeInOut(duration: 0.15), value: isHovered)
    }
    
    private func loadAppIcon() {
        guard !isLoadingIcon else { return }
        isLoadingIcon = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let url = URL(fileURLWithPath: app.path)
            let icon = NSWorkspace.shared.icon(forFile: url.path)
            
            if icon.size.width > 0 {
                let resized = icon.resized(to: NSSize(width: 22, height: 22))
                DispatchQueue.main.async {
                    self.appIcon = resized
                    self.isLoadingIcon = false
                }
            } else {
                DispatchQueue.main.async {
                    self.isLoadingIcon = false
                }
            }
        }
    }
}

// MARK: - PresetsSettingsView (без изменений)

struct PresetsSettingsView: View {
    let onSave: () -> Void
    @EnvironmentObject var appState: AppStateManager
    @State private var selectedPresetId: UUID?
    @State private var hoveredPresetId: UUID?
    @State private var hoveredItemId: UUID?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerView
            Text("Наборы элементов BarX, между которыми можно быстро переключаться.")
                .font(.caption)
                .adaptiveTextColor()
                .opacity(0.7)
            
            if appState.presets.isEmpty {
                emptyStateView
            } else {
                HStack(alignment: .top, spacing: 20) {
                    presetsListView
                    
                    Divider()
                        .background(Color.white.opacity(0.3))
                    
                    itemsListView
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private var headerView: some View {
        HStack {
            Text("Папки")
                .font(.headline)
                .adaptiveTextColor()
            Spacer()
            Button("＋ Добавить") {
                BarXWindowManager.shared.showWindow(
                    id: "addPreset",
                    title: "Новая папка",
                    size: CGSize(width: 380, height: 420),
                    content: AddPresetView(
                        onAdded: {
                            onSave()
                        }
                    )
                    .environmentObject(appState)
                )
            }
            .buttonStyle(.borderedProminent)
            .tint(.white)
            .controlSize(.small)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "folder")
                .font(.system(size: 32))
                .adaptiveTextColor()
                .opacity(0.6)
            Text("Нет папок")
                .adaptiveTextColor()
                .opacity(0.7)
            Text("Нажмите «Добавить» чтобы создать папку")
                .font(.caption)
                .adaptiveTextColor()
                .opacity(0.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    private var presetsListView: some View {
        ScrollView {
            VStack(spacing: 4) {
                ForEach(appState.presets) { preset in
                    presetRow(for: preset)
                }
                .onMove { source, destination in
                    appState.presets.move(fromOffsets: source, toOffset: destination)
                    appState.savePresets()
                    onSave()
                }
            }
            .padding(.vertical, 4)
        }
        .frame(minHeight: 200, maxHeight: 400)
        .frame(width: 250)
    }
    
    private func presetRow(for preset: Preset) -> some View {
        HStack {
            Image(systemName: preset.icon)
                .adaptiveTextColor()
                .frame(width: 24)
            Text(preset.name)
                .adaptiveTextColor()
            Spacer()
            Text("\(preset.items.count)")
                .font(.caption)
                .adaptiveTextColor()
                .opacity(0.7)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.white.opacity(0.1))
                .clipShape(Capsule())
            
            if selectedPresetId == preset.id {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
            
            Button {
                if let index = appState.presets.firstIndex(where: { $0.id == preset.id }) {
                    appState.presets.remove(at: index)
                    if selectedPresetId == preset.id {
                        selectedPresetId = appState.presets.first?.id
                    }
                    appState.savePresets()
                    onSave()
                }
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    selectedPresetId == preset.id
                        ? Color.white.opacity(0.12)
                        : (hoveredPresetId == preset.id ? Color.white.opacity(0.06) : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            selectedPresetId == preset.id
                                ? Color.white.opacity(0.3)
                                : Color.clear,
                            lineWidth: 1.5
                        )
                )
        )
        .onTapGesture {
            selectedPresetId = preset.id
        }
        .onHover { hovering in
            hoveredPresetId = hovering ? preset.id : nil
            if hovering {
                NSCursor.pointingHand.set()
            }
        }
        .animation(.easeInOut(duration: 0.15), value: selectedPresetId)
    }
    
    private var itemsListView: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let preset = appState.presets.first(where: { $0.id == selectedPresetId }) {
                HStack {
                    Text("Элементы в \(preset.name)")
                        .font(.subheadline)
                        .adaptiveTextColor()
                    Spacer()
                    Button("＋ Добавить") {
                        BarXWindowManager.shared.showWindow(
                            id: "addItem",
                            title: "Добавить элемент",
                            size: CGSize(width: 480, height: 520),
                            content: AddItemView(
                                presetId: preset.id,
                                onAdded: {
                                    appState.savePresets()
                                    onSave()
                                }
                            )
                            .environmentObject(appState)
                        )
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.white)
                    .controlSize(.small)
                }
                
                if preset.items.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "folder")
                            .font(.system(size: 24))
                            .adaptiveTextColor()
                            .opacity(0.4)
                        Text("Нет элементов")
                            .font(.caption)
                            .adaptiveTextColor()
                            .opacity(0.6)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                } else {
                    ScrollView {
                        VStack(spacing: 4) {
                            ForEach(preset.items) { item in
                                itemRow(for: item, in: preset)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .frame(maxHeight: 350)
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "folder")
                        .font(.system(size: 32))
                        .adaptiveTextColor()
                        .opacity(0.5)
                    Text("Выберите папку")
                        .adaptiveTextColor()
                        .opacity(0.7)
                    Text("Слева выберите папку для просмотра элементов")
                        .font(.caption)
                        .adaptiveTextColor()
                        .opacity(0.5)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.vertical, 40)
            }
        }
        .padding(.horizontal, 4)
    }
    
    private func itemRow(for item: AppItem, in preset: Preset) -> some View {
        HStack {
            Image(systemName: item.icon)
                .adaptiveTextColor()
                .frame(width: 20)
            VStack(alignment: .leading) {
                Text(item.name)
                    .adaptiveTextColor()
                Text(item.path)
                    .font(.caption)
                    .adaptiveTextColor()
                    .opacity(0.7)
                    .lineLimit(1)
            }
            Spacer()
            Button("Открыть") {
                openItem(item)
            }
            .buttonStyle(.bordered)
            .tint(.white)
            .controlSize(.small)
            
            Button {
                if let presetIndex = appState.presets.firstIndex(where: { $0.id == preset.id }),
                   let itemIndex = appState.presets[presetIndex].items.firstIndex(where: { $0.id == item.id }) {
                    appState.presets[presetIndex].items.remove(at: itemIndex)
                    appState.savePresets()
                    onSave()
                }
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.red.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(hoveredItemId == item.id ? Color.white.opacity(0.06) : Color.clear)
        )
        .onHover { hovering in
            hoveredItemId = hovering ? item.id : nil
            if hovering {
                NSCursor.pointingHand.set()
            }
        }
    }
    
    private func openItem(_ item: AppItem) {
        switch item.type {
        case .url:
            if let url = URL(string: item.path) {
                NSWorkspace.shared.open(url)
            }
        case .application:
            let url = URL(fileURLWithPath: item.path)
            if FileManager.default.fileExists(atPath: item.path) {
                let configuration = NSWorkspace.OpenConfiguration()
                NSWorkspace.shared.openApplication(
                    at: url,
                    configuration: configuration
                ) { _, error in
                    if let error {
                        print("Ошибка запуска: \(error)")
                    }
                }
            }
        case .folder:
            let url = URL(fileURLWithPath: item.path)
            if let bookmarkedURL = FileAccessHelper.shared.getBookmarkedURL(for: item.path) {
                NSWorkspace.shared.open(bookmarkedURL)
            } else {
                FileAccessHelper.shared.requestAccessAndOpen(path: item.path) { _ in }
            }
        case .action:
            print("Action: \(item.name)")
        }
    }
}

// MARK: - AddPresetView (без изменений)

struct AddPresetView: View {
    let onAdded: () -> Void
    @EnvironmentObject var appState: AppStateManager
    @State private var presetName = ""
    @State private var selectedIcon = "folder"
    @FocusState private var isNameFieldFocused: Bool
    @State private var currentPage = 0
    @StateObject private var themeManager = ThemeManager.shared
    
    let icons = [
        "folder", "folder.fill", "folder.circle", "folder.circle.fill",
        "gamecontroller.fill", "briefcase.fill", "book.fill", "star.fill",
        "heart.fill", "music.note", "photo", "video", "pencil", "gear",
        "doc", "doc.fill", "link", "hammer", "wrench", "laptopcomputer",
        "iphone", "ipad", "applewatch", "airpods", "keyboard", "mouse",
        "display", "printer", "scanner", "camera", "camera.fill",
        "message", "mail", "phone", "calendar", "clock", "location",
        "map", "cloud", "sun.max", "moon", "paperplane", "paintbrush"
    ]
    
    var displayedIcons: [String] {
        let start = currentPage * 20
        let end = min(start + 20, icons.count)
        return Array(icons[start..<end])
    }
    
    var totalPages: Int {
        Int(ceil(Double(icons.count) / 20.0))
    }
    
    var body: some View {
        ZStack {
            if let theme = themeManager.isPreviewMode ? themeManager.previewTheme : themeManager.selectedTheme {
                GradientBackground(theme: theme)
                    .ignoresSafeArea()
            }
            
            VStack(alignment: .leading, spacing: 16) {
                Text("Новая папка")
                    .font(.title2.bold())
                    .adaptiveTextColor()
                
                Divider()
                    .background(Color.white.opacity(0.3))
                
                nameField
                iconSelector
                Spacer()
                actionButtons
            }
            .padding(24)
            .frame(width: 380, height: 420)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    isNameFieldFocused = true
                }
            }
        }
    }
    
    private var nameField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Название")
                .font(.headline)
                .adaptiveTextColor()
            TextField("Введите название", text: $presetName)
                .textFieldStyle(.roundedBorder)
                .focused($isNameFieldFocused)
                .onSubmit {
                    createFolder()
                }
        }
    }
    
    private var iconSelector: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Иконка")
                .font(.headline)
                .adaptiveTextColor()
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHGrid(rows: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(displayedIcons, id: \.self) { icon in
                        Button {
                            selectedIcon = icon
                        } label: {
                            Image(systemName: icon)
                                .font(.system(size: 22))
                                .frame(width: 44, height: 44)
                                .background(
                                    selectedIcon == icon
                                    ? Color.white.opacity(0.3)
                                    : Color.white.opacity(0.1)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(
                                            selectedIcon == icon
                                            ? Color.white
                                            : Color.clear,
                                            lineWidth: 2
                                        )
                                )
                                .adaptiveTextColor()
                        }
                        .buttonStyle(.plain)
                        .onHover { hovering in
                            if hovering {
                                NSCursor.pointingHand.set()
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(height: 110)
            
            if totalPages > 1 {
                paginationView
            }
        }
    }
    
    private var paginationView: some View {
        HStack {
            Button {
                if currentPage > 0 {
                    currentPage -= 1
                }
            } label: {
                Image(systemName: "chevron.left")
                    .adaptiveTextColor()
                    .opacity(currentPage > 0 ? 1 : 0.3)
            }
            .buttonStyle(.plain)
            .disabled(currentPage == 0)
            
            Spacer()
            
            Text("\(currentPage + 1) / \(totalPages)")
                .font(.caption)
                .adaptiveTextColor()
                .opacity(0.7)
            
            Spacer()
            
            Button {
                if currentPage < totalPages - 1 {
                    currentPage += 1
                }
            } label: {
                Image(systemName: "chevron.right")
                    .adaptiveTextColor()
                    .opacity(currentPage < totalPages - 1 ? 1 : 0.3)
            }
            .buttonStyle(.plain)
            .disabled(currentPage >= totalPages - 1)
        }
        .padding(.top, 4)
    }
    
    private var actionButtons: some View {
        HStack {
            Button("Отмена") {
                BarXWindowManager.shared.closeWindow(id: "addPreset")
            }
            .buttonStyle(.bordered)
            .tint(.white)
            
            Spacer()
            
            Button("Создать") {
                createFolder()
            }
            .buttonStyle(.borderedProminent)
            .tint(.white)
            .disabled(
                presetName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            )
        }
    }
    
    private func createFolder() {
        let name = presetName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        appState.addPreset(Preset(name: name, icon: selectedIcon))
        onAdded()
        BarXWindowManager.shared.closeWindow(id: "addPreset")
    }
}

// MARK: - AddItemView (без изменений)

struct AddItemView: View {
    let presetId: UUID
    let onAdded: () -> Void
    @EnvironmentObject var appState: AppStateManager
    @State private var itemName = ""
    @State private var itemPath = ""
    @State private var selectedIcon = "app.fill"
    @State private var itemType: AppItem.ItemType = .application
    @State private var showingFilePicker = false
    @FocusState private var isNameFieldFocused: Bool
    @State private var currentPage = 0
    @StateObject private var themeManager = ThemeManager.shared
    
    let icons = [
        "app.fill", "app", "folder", "folder.fill", "link", "link.circle",
        "doc", "doc.fill", "gear", "gearshape", "gear.circle", "hammer",
        "wrench", "pencil", "pencil.circle", "music.note", "music.note.list",
        "photo", "photo.fill", "video", "video.fill", "star.fill",
        "heart.fill", "safari", "network", "globe", "cloud", "cloud.fill",
        "envelope", "envelope.fill", "message", "message.fill", "phone",
        "phone.fill", "calendar", "calendar.circle", "clock", "clock.fill",
        "map", "map.fill", "location", "location.fill", "camera", "camera.fill",
        "printer", "printer.fill", "display", "iphone", "ipad", "applewatch",
        "airpods", "keyboard", "mouse", "gamecontroller", "gamecontroller.fill"
    ]
    
    var displayedIcons: [String] {
        let start = currentPage * 20
        let end = min(start + 20, icons.count)
        return Array(icons[start..<end])
    }
    
    var totalPages: Int {
        Int(ceil(Double(icons.count) / 20.0))
    }
    
    var body: some View {
        ZStack {
            if let theme = themeManager.isPreviewMode ? themeManager.previewTheme : themeManager.selectedTheme {
                GradientBackground(theme: theme)
                    .ignoresSafeArea()
            }
            
            VStack(alignment: .leading, spacing: 16) {
                Text("Добавить элемент")
                    .font(.title2.bold())
                    .adaptiveTextColor()
                
                Divider()
                    .background(Color.white.opacity(0.3))
                
                typePicker
                nameField
                pathField
                iconSelector
                Spacer()
                actionButtons
            }
            .padding(24)
            .frame(width: 480, height: 550)
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: [.application, .folder]
            ) { result in
                switch result {
                case .success(let url):
                    itemPath = url.path
                    if itemName.isEmpty {
                        itemName = url.lastPathComponent
                    }
                case .failure(let error):
                    print("Ошибка выбора файла: \(error)")
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    isNameFieldFocused = true
                }
            }
        }
    }
    
    private var typePicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Тип элемента")
                .font(.headline)
                .adaptiveTextColor()
            Picker("Тип", selection: $itemType) {
                Text("Приложение").tag(AppItem.ItemType.application)
                Text("Папка").tag(AppItem.ItemType.folder)
                Text("URL").tag(AppItem.ItemType.url)
            }
            .pickerStyle(.segmented)
        }
    }
    
    private var nameField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Название")
                .font(.headline)
                .adaptiveTextColor()
            TextField("Введите название", text: $itemName)
                .textFieldStyle(.roundedBorder)
                .focused($isNameFieldFocused)
        }
    }
    
    private var pathField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(itemType == .url ? "URL" : "Путь")
                .font(.headline)
                .adaptiveTextColor()
            HStack {
                TextField(
                    itemType == .url ? "https://example.com" : "/Applications/...",
                    text: $itemPath
                )
                .textFieldStyle(.roundedBorder)
                
                if itemType != .url {
                    Button("Выбрать") {
                        showingFilePicker = true
                    }
                    .buttonStyle(.bordered)
                    .tint(.white)
                    .controlSize(.small)
                }
            }
        }
    }
    
    private var iconSelector: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Иконка")
                .font(.headline)
                .adaptiveTextColor()
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHGrid(rows: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(displayedIcons, id: \.self) { icon in
                        Button {
                            selectedIcon = icon
                        } label: {
                            Image(systemName: icon)
                                .font(.system(size: 22))
                                .frame(width: 44, height: 44)
                                .background(
                                    selectedIcon == icon
                                    ? Color.white.opacity(0.3)
                                    : Color.white.opacity(0.1)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(
                                            selectedIcon == icon
                                            ? Color.white
                                            : Color.clear,
                                            lineWidth: 2
                                        )
                                )
                                .adaptiveTextColor()
                        }
                        .buttonStyle(.plain)
                        .onHover { hovering in
                            if hovering {
                                NSCursor.pointingHand.set()
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(height: 110)
            
            if totalPages > 1 {
                paginationView
            }
        }
    }
    
    private var paginationView: some View {
        HStack {
            Button {
                if currentPage > 0 {
                    currentPage -= 1
                }
            } label: {
                Image(systemName: "chevron.left")
                    .adaptiveTextColor()
                    .opacity(currentPage > 0 ? 1 : 0.3)
            }
            .buttonStyle(.plain)
            .disabled(currentPage == 0)
            
            Spacer()
            
            Text("\(currentPage + 1) / \(totalPages)")
                .font(.caption)
                .adaptiveTextColor()
                .opacity(0.7)
            
            Spacer()
            
            Button {
                if currentPage < totalPages - 1 {
                    currentPage += 1
                }
            } label: {
                Image(systemName: "chevron.right")
                    .adaptiveTextColor()
                    .opacity(currentPage < totalPages - 1 ? 1 : 0.3)
            }
            .buttonStyle(.plain)
            .disabled(currentPage >= totalPages - 1)
        }
        .padding(.top, 4)
    }
    
    private var actionButtons: some View {
        HStack {
            Button("Отмена") {
                BarXWindowManager.shared.closeWindow(id: "addItem")
            }
            .buttonStyle(.bordered)
            .tint(.white)
            
            Spacer()
            
            Button("Добавить") {
                addItem()
            }
            .buttonStyle(.borderedProminent)
            .tint(.white)
            .disabled(
                itemName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || itemPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            )
        }
    }
    
    private func addItem() {
        guard let index = appState.presets.firstIndex(where: { $0.id == presetId }) else {
            return
        }
        
        let item = AppItem(
            name: itemName.trimmingCharacters(in: .whitespacesAndNewlines),
            path: itemPath.trimmingCharacters(in: .whitespacesAndNewlines),
            icon: selectedIcon,
            preset: appState.presets[index].name,
            type: itemType
        )
        
        appState.presets[index].items.append(item)
        appState.savePresets()
        onAdded()
        BarXWindowManager.shared.closeWindow(id: "addItem")
    }
}

// MARK: - LauncherSettingsView (без изменений)

struct LauncherSettingsView: View {
    @StateObject private var launcherManager = LauncherManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Launcher")
                .font(.headline)
                .adaptiveTextColor()
            
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Включить Launcher", isOn: $launcherManager.launcherEnabled)
                    .toggleStyle(SwitchToggleStyle(tint: .white))
                    .adaptiveTextColor()
                    .onChange(of: launcherManager.launcherEnabled) { newValue in
                        if newValue {
                            launcherManager.setupHotkeys()
                        } else {
                            launcherManager.hideLauncher()
                            launcherManager.cleanup()
                        }
                    }
                
                if launcherManager.launcherEnabled {
                    HStack {
                        Text("Горячая клавиша")
                            .adaptiveTextColor()
                            .opacity(0.7)
                        
                        Spacer()
                        
                        HotkeyRecorder(hotkey: $launcherManager.launcherHotkeyKey) { newHotkey in
                            launcherManager.launcherHotkeyKey = newHotkey
                            launcherManager.setupHotkeys()
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Используйте Launcher для быстрого поиска и запуска приложений")
                            .font(.caption)
                            .adaptiveTextColor()
                            .opacity(0.5)
                        Text("Нажмите горячую клавишу чтобы открыть Launcher, введите название приложения и нажмите Enter")
                            .font(.caption)
                            .adaptiveTextColor()
                            .opacity(0.4)
                    }
                    .padding(.top, 4)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - AboutView (без изменений)

struct AboutView: View {
    @StateObject private var themeManager = ThemeManager.shared
    @State private var version = "1.0.0"
    @State private var buildNumber = "1"
    @State private var isCheckingUpdate = false
    @State private var updateAvailable = false
    @State private var updateMessage = ""
    @State private var showUpdateSheet = false
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "sparkles")
                .font(.system(size: 64))
                .adaptiveTextColor()
            
            Text("BarX")
                .font(.largeTitle.bold())
                .adaptiveTextColor()
            
            Text("Версия \(version) (Build \(buildNumber))")
                .adaptiveTextColor()
                .opacity(0.7)
            
            Text("Бесплатный аналог ExtraBar")
                .adaptiveTextColor()
                .opacity(0.5)
            
            Divider()
                .background(Color.white.opacity(0.3))
                .padding(.horizontal, 40)
            
            Button {
                checkForUpdates()
            } label: {
                if isCheckingUpdate {
                    HStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(0.8)
                        Text("Проверяем...")
                            .adaptiveTextColor()
                    }
                } else {
                    Label("Проверить обновления", systemImage: "arrow.clockwise")
                        .adaptiveTextColor()
                }
            }
            .buttonStyle(.bordered)
            .tint(.white)
            .disabled(isCheckingUpdate)
            
            if updateAvailable {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                    Text(updateMessage)
                        .adaptiveTextColor()
                        .opacity(0.8)
                }
                .font(.caption)
            } else if !updateMessage.isEmpty && !isCheckingUpdate {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(updateMessage)
                        .adaptiveTextColor()
                        .opacity(0.8)
                }
                .font(.caption)
            }
            
            Divider()
                .background(Color.white.opacity(0.3))
                .padding(.horizontal, 40)
            
            VStack(spacing: 8) {
                Text("Разработано с ❤️")
                    .adaptiveTextColor()
                    .opacity(0.5)
                
                HStack(spacing: 16) {
                    Link(destination: URL(string: "https://github.com")!) {
                        Label("GitHub", systemImage: "square.and.arrow.up")
                            .adaptiveTextColor()
                            .opacity(0.6)
                    }
                    
                    Link(destination: URL(string: "mailto:support@barx.app")!) {
                        Label("Поддержка", systemImage: "envelope")
                            .adaptiveTextColor()
                            .opacity(0.6)
                    }
                }
                .font(.caption)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .sheet(isPresented: $showUpdateSheet) {
            UpdateSheetView(
                version: "1.1.0",
                changes: [
                    "• Улучшен Launcher",
                    "• Исправлены горячие клавиши",
                    "• Добавлена система приложений",
                    "• Улучшена производительность"
                ],
                onUpdate: {
                    showUpdateSheet = false
                }
            )
        }
    }
    
    private func checkForUpdates() {
        isCheckingUpdate = true
        updateAvailable = false
        updateMessage = ""
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            isCheckingUpdate = false
            
            let hasUpdate = false
            
            if hasUpdate {
                updateAvailable = true
                updateMessage = "🚀 Доступно обновление BarX 1.1.0"
                showUpdateSheet = true
            } else {
                updateAvailable = false
                updateMessage = "✓ У вас последняя версия \(version)"
            }
        }
    }
}

// MARK: - UpdateSheetView (без изменений)

struct UpdateSheetView: View {
    @Environment(\.dismiss) var dismiss
    let version: String
    let changes: [String]
    let onUpdate: () -> Void
    @State private var isDownloading = false
    @State private var downloadProgress = 0.0
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Text("Доступно обновление")
                    .font(.title2.bold())
                    .adaptiveTextColor()
                
                Text("BarX \(version)")
                    .font(.headline)
                    .adaptiveTextColor()
                    .opacity(0.8)
                
                Divider()
                    .background(Color.white.opacity(0.3))
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Что нового:")
                        .font(.subheadline)
                        .adaptiveTextColor()
                        .opacity(0.7)
                    
                    ForEach(changes, id: \.self) { change in
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.green)
                            Text(change)
                                .font(.caption)
                                .adaptiveTextColor()
                                .opacity(0.8)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                
                if isDownloading {
                    VStack(spacing: 8) {
                        ProgressView(value: downloadProgress, total: 1.0)
                            .progressViewStyle(LinearProgressViewStyle())
                            .tint(.blue)
                            .frame(width: 200)
                        
                        Text("Загрузка... \(Int(downloadProgress * 100))%")
                            .font(.caption)
                            .adaptiveTextColor()
                            .opacity(0.6)
                    }
                }
                
                HStack(spacing: 12) {
                    Button("Позже") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    .tint(.white)
                    
                    Button("Обновить") {
                        if !isDownloading {
                            startDownload()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .disabled(isDownloading)
                }
            }
            .padding(32)
            .frame(width: 400)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.gray.opacity(0.15))
                    .background(.ultraThinMaterial)
            )
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
    }
    
    private func startDownload() {
        isDownloading = true
        downloadProgress = 0
        
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            downloadProgress += 0.02
            if downloadProgress >= 1.0 {
                timer.invalidate()
                isDownloading = false
                onUpdate()
                dismiss()
            }
        }
    }
}
