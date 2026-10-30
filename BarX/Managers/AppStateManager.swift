//
//  AppStateManager.swift
//  BarX
//
//  Состояние приложений, панели и папок
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers
import Combine
import ServiceManagement
import UserNotifications
import ApplicationServices

// MARK: - AppStateManager

class AppStateManager: ObservableObject {
    static let shared = AppStateManager()
    
    @Published var installedApps: [AppItem] = []
    @Published var barApps: [AppItem] = []
    @Published var recentApps: [AppItem] = []
    @Published var pinnedApps: [AppItem] = []
    @Published var presets: [Preset] = []
    @Published var isLoading = false
    @Published var lastScanDate: Date?
    
    @AppStorage("barAppsData") private var barAppsData: Data = Data()
    @AppStorage("recentAppsData") private var recentAppsData: Data = Data()
    @AppStorage("pinnedAppsData") private var pinnedAppsData: Data = Data()
    @AppStorage("presetsData") private var presetsData: Data = Data()
    @AppStorage("installedAppsData") private var installedAppsData: Data = Data()
    
    private init() {
        loadAllState()
        migrateOldFavorites()
        scanInstalledApps()
    }

    /// Короткая сводка для раздела «Основные».
    var statistics: (apps: Int, bar: Int, folders: Int, items: Int) {
        (installedApps.count, barApps.count, presets.count, presets.reduce(0) { $0 + $1.items.count })
    }

    /// Миграция старых избранных в панель Bar
    private func migrateOldFavorites() {
        guard let oldData = UserDefaults.standard.data(forKey: "favoriteAppsData") else { return }
        guard let oldFavorites = try? JSONDecoder().decode([AppItem].self, from: oldData) else { return }
        
        if barApps.isEmpty && !oldFavorites.isEmpty {
            barApps = oldFavorites
            saveBarApps()
            Log.info("Мигрировано \(oldFavorites.count) приложений из избранного в панель Bar")
        }
        
        UserDefaults.standard.removeObject(forKey: "favoriteAppsData")
    }
    
    func loadAllState() {
        loadInstalledApps()
        loadBarApps()
        loadRecentApps()
        loadPinnedApps()
        loadPresets()
    }
    
    func saveAllState() {
        saveInstalledApps()
        saveBarApps()
        saveRecentApps()
        savePinnedApps()
        savePresets()
    }
    
    // MARK: - Installed Apps

    func loadInstalledApps() {
        guard !installedAppsData.isEmpty else {
            // Данные удалены (например, сбросом) — чистим и память
            installedApps = []
            return
        }
        guard let decoded = try? JSONDecoder().decode([AppItem].self, from: installedAppsData) else {
            Log.error("Не удалось декодировать installedAppsData — список приложений сброшен")
            return
        }
        installedApps = decoded
        Log.debug("Загружено \(installedApps.count) установленных приложений")
    }

    func saveInstalledApps() {
        if let encoded = try? JSONEncoder().encode(installedApps) {
            installedAppsData = encoded
        }
    }
    
    // MARK: - Bar Apps
    
    func loadBarApps() {
        guard !barAppsData.isEmpty else {
            barApps = []
            return
        }
        guard let decoded = try? JSONDecoder().decode([AppItem].self, from: barAppsData) else {
            Log.error("Не удалось декодировать barAppsData — панель пуста")
            return
        }
        barApps = decoded
    }
    
    func saveBarApps() {
        if let encoded = try? JSONEncoder().encode(barApps) {
            barAppsData = encoded
        }
        NotificationCenter.default.post(name: .barItemsDidChange, object: nil)
    }
    
    /// Добавляет приложение в панель.
    /// Возвращает `false`, если достигнут лимит `BarXSettings.maxBarApps` —
    /// тогда вызывающая сторона обязана сообщить пользователю,
    /// что больше добавить нельзя.
    @discardableResult
    func addToBar(_ app: AppItem) -> Bool {
        guard !isInBar(app) else { return true }
        guard barApps.count < BarXSettings.maxBarApps else { return false }
        var newApp = app
        newApp.isPinned = true
        barApps.append(newApp)
        saveBarApps()
        objectWillChange.send()
        return true
    }

    func removeFromBar(_ app: AppItem) {
        barApps.removeAll { Self.isSameApp($0, app) }
        saveBarApps()
        objectWillChange.send()
    }
    
    func isInBar(_ app: AppItem) -> Bool {
        barApps.contains { Self.isSameApp($0, app) }
    }
    
    /// Сравнение приложений по устойчивому признаку.
    /// UUID у элементов из сканирования каждый раз новый, поэтому
    /// сравнивать можно только путь (он не меняется между запусками).
    static func isSameApp(_ lhs: AppItem, _ rhs: AppItem) -> Bool {
        if !lhs.path.isEmpty && !rhs.path.isEmpty {
            return lhs.path.compare(rhs.path, options: .caseInsensitive) == .orderedSame
        }
        return lhs.id == rhs.id
    }
    
    // MARK: - Recent Apps
    
    func loadRecentApps() {
        guard !recentAppsData.isEmpty else {
            recentApps = []
            return
        }
        guard let decoded = try? JSONDecoder().decode([AppItem].self, from: recentAppsData) else {
            Log.error("Не удалось декодировать recentAppsData — список недавних пуст")
            return
        }
        // Обрезаем до текущей настройки: список мог быть длиннее
        recentApps = Array(decoded.prefix(max(1, BarXSettings.maxRecentApps)))
    }
    
    func saveRecentApps() {
        if let encoded = try? JSONEncoder().encode(recentApps) {
            recentAppsData = encoded
        }
    }
    
    func addRecentApp(_ app: AppItem) {
        recentApps.removeAll { Self.isSameApp($0, app) }
        recentApps.insert(app, at: 0)
        let limit = max(1, BarXSettings.maxRecentApps)
        if recentApps.count > limit {
            recentApps = Array(recentApps.prefix(limit))
        }
        saveRecentApps()
        objectWillChange.send()
    }
    
    func isRecent(_ app: AppItem) -> Bool {
        recentApps.contains { Self.isSameApp($0, app) }
    }
    
    // MARK: - Статистика запусков
    
    /// Записывает запуск приложения: счётчик и время.
    ///
    /// Поля `launchCount` / `lastLaunched` существовали в модели, но их никто
    /// не обновлял — сортировка «по последнему запуску» в разделе «Приложения»
    /// и панель сведений Launcher были декоративными.
    ///
    /// Ищем по пути (`isSameApp`), а не по `id`: UUID у просканированных
    /// приложений меняется при каждом сканировании.
    func recordLaunch(of app: AppItem) {
        let now = Date()
        
        if let index = installedApps.firstIndex(where: { Self.isSameApp($0, app) }) {
            installedApps[index].launchCount += 1
            installedApps[index].lastLaunched = now
        }
        if let index = barApps.firstIndex(where: { Self.isSameApp($0, app) }) {
            barApps[index].launchCount += 1
            barApps[index].lastLaunched = now
        }
        if let index = pinnedApps.firstIndex(where: { Self.isSameApp($0, app) }) {
            pinnedApps[index].launchCount += 1
            pinnedApps[index].lastLaunched = now
        }
        for presetIndex in presets.indices {
            for itemIndex in presets[presetIndex].items.indices
            where Self.isSameApp(presets[presetIndex].items[itemIndex], app) {
                presets[presetIndex].items[itemIndex].launchCount += 1
                presets[presetIndex].items[itemIndex].lastLaunched = now
            }
        }
        
        saveAllState()
        objectWillChange.send()
    }
    
    /// Самые запускаемые приложения — для сортировки и статистики.
    func sortedByLaunchCount(_ apps: [AppItem]) -> [AppItem] {
        apps.sorted {
            if $0.launchCount != $1.launchCount { return $0.launchCount > $1.launchCount }
            return ($0.lastLaunched ?? .distantPast) > ($1.lastLaunched ?? .distantPast)
        }
    }
    
    /// Приложения, отсортированные по времени последнего запуска.
    func sortedByLastLaunched(_ apps: [AppItem]) -> [AppItem] {
        apps.sorted { ($0.lastLaunched ?? .distantPast) > ($1.lastLaunched ?? .distantPast) }
    }
    
    func clearRecentApps() {
        recentApps.removeAll()
        saveRecentApps()
        objectWillChange.send()
    }
    
    /// Обрезает список недавних до текущего лимита из настроек.
    func trimRecentApps() {
        let limit = max(1, BarXSettings.maxRecentApps)
        guard recentApps.count > limit else { return }
        recentApps = Array(recentApps.prefix(limit))
        saveRecentApps()
        objectWillChange.send()
    }
    
    // MARK: - Pinned Apps
    
    func loadPinnedApps() {
        guard !pinnedAppsData.isEmpty else {
            pinnedApps = []
            return
        }
        guard let decoded = try? JSONDecoder().decode([AppItem].self, from: pinnedAppsData) else {
            Log.error("Не удалось декодировать pinnedAppsData")
            return
        }
        pinnedApps = decoded
    }
    
    func savePinnedApps() {
        if let encoded = try? JSONEncoder().encode(pinnedApps) {
            pinnedAppsData = encoded
        }
    }
    
    func togglePinApp(_ app: AppItem) {
        if let index = pinnedApps.firstIndex(where: { Self.isSameApp($0, app) }) {
            pinnedApps.remove(at: index)
        } else {
            var pinnedApp = app
            pinnedApp.isPinned = true
            pinnedApps.append(pinnedApp)
        }
        savePinnedApps()
        objectWillChange.send()
    }
    
    func isPinned(_ app: AppItem) -> Bool {
        pinnedApps.contains { Self.isSameApp($0, app) }
    }
    
    // MARK: - Presets
    
    func loadPresets() {
        // Папки должны восстанавливаться между запусками приложения.
        guard !presetsData.isEmpty else {
            presets = []
            return
        }
        guard let decoded = try? JSONDecoder().decode([Preset].self, from: presetsData) else {
            Log.error("Не удалось декодировать presetsData — папки не восстановлены")
            return
        }
        presets = decoded
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
        objectWillChange.send()
    }
    
    func removePreset(_ preset: Preset) {
        presets.removeAll { $0.id == preset.id }
        savePresets()
        objectWillChange.send()
    }
    
    func addItem(_ item: AppItem, toPreset presetId: UUID) -> Bool {
        guard let index = presets.firstIndex(where: { $0.id == presetId }) else { return false }
        presets[index].items.append(item)
        savePresets()
        objectWillChange.send()
        return true
    }
    
    func removeItem(_ item: AppItem, fromPreset presetId: UUID) -> Bool {
        guard let presetIndex = presets.firstIndex(where: { $0.id == presetId }),
              let itemIndex = presets[presetIndex].items.firstIndex(where: { $0.id == item.id }) else {
            return false
        }
        presets[presetIndex].items.remove(at: itemIndex)
        savePresets()
        objectWillChange.send()
        return true
    }
    
    // MARK: - Scanning
    
    func scanInstalledApps() {
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let apps = self.performScan()
            DispatchQueue.main.async {
                self.installedApps = apps
                self.isLoading = false
                self.lastScanDate = Date()
                self.restoreAppStates()
                self.saveInstalledApps()
                NotificationCenter.default.post(name: .appListDidChange, object: nil)
                Log.success("Найдено \(apps.count) приложений")
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
        var seenPaths = Set<String>()
        var seenNames = Set<String>()
        
        for applicationsURL in applicationsURLs {
            // Сканируем саму папку и один уровень вложенности
            // (например /Applications/Utilities, /System/Applications/Utilities)
            scanDirectory(applicationsURL, depth: 0, apps: &apps, seenPaths: &seenPaths, seenNames: &seenNames)
        }
        
        return apps.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }
    
    private func scanDirectory(
        _ directory: URL,
        depth: Int,
        apps: inout [AppItem],
        seenPaths: inout Set<String>,
        seenNames: inout Set<String>
    ) {
        guard depth <= 1 else { return }
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: .skipsHiddenFiles
        ) else { return }
        
        for fileURL in contents {
            let path = fileURL.path
            if fileURL.pathExtension == "app" {
                guard !seenPaths.contains(path) else { continue }
                let name = fileURL.deletingPathExtension().lastPathComponent
                // Одноимённые приложения (например, разные версии) не дублируем
                guard !seenNames.contains(name) else { continue }
                seenPaths.insert(path)
                seenNames.insert(name)
                apps.append(
                    AppItem(
                        name: name,
                        path: path,
                        icon: AppStateManager.iconName(for: name),
                        preset: "Все приложения",
                        type: .application
                    )
                )
            } else if depth == 0, isDirectory(fileURL) {
                scanDirectory(fileURL, depth: depth + 1, apps: &apps, seenPaths: &seenPaths, seenNames: &seenNames)
            }
        }
    }
    
    private func isDirectory(_ url: URL) -> Bool {
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
    }
    
    private func restoreAppStates() {
        for i in 0..<installedApps.count {
            let app = installedApps[i]
            if barApps.contains(where: { Self.isSameApp($0, app) }) {
                installedApps[i].isPinned = true
            }
        }
    }
    
    /// SF-иконка по имени приложения (для приложений без своей иконки).
    static func iconName(for name: String) -> String {
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
    
    /// Добавляет приложение в общий список (используется при добавлении из Finder).
    @discardableResult
    func registerExternalApp(_ app: AppItem) -> Bool {
        if !installedApps.contains(where: { Self.isSameApp($0, app) }) {
            installedApps.append(app)
            installedApps.sort {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
            saveInstalledApps()
            objectWillChange.send()
            return true
        }
        return false
    }
    
    func getAppState(_ app: AppItem) -> AppState {
        return AppState(
            isInstalled: installedApps.contains(where: { Self.isSameApp($0, app) }),
            isInBar: isInBar(app),
            isRecent: isRecent(app),
            isPinned: isPinned(app)
        )
    }
    struct AppState {
        let isInstalled: Bool
        let isInBar: Bool
        let isRecent: Bool
        let isPinned: Bool
    }
}
