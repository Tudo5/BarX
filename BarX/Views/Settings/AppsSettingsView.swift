//
//  AppsSettingsView.swift
//  BarX
//
//  Раздел «Приложения»: список и сетка, фильтры, сортировка,
//  массовые операции и быстрые действия.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers
import Combine

// MARK: - AppsSettingsView

struct AppsSettingsView: View {
    @EnvironmentObject var appState: AppStateManager

    @AppStorage("appsViewMode") private var viewMode = "list"
    @AppStorage("appsShowPath") private var showPath = true
    @AppStorage("appsSortOrder") private var sortOrder = "name"
    @AppStorage("appsConfirmDelete") private var confirmDelete = true

    @State private var searchText = ""
    @State private var selectedFilter: AppFilter = .all
    @State private var isDragging = false
    @State private var selectedApps: Set<String> = []
    @State private var isEditMode = false
    @State private var pendingDelete = false
    @State private var toast: String?
    @State private var sizeCache: [String: Int64] = [:]

    @StateObject private var animations = AnimationCenter.shared

    /// Идентификатор верхнего якоря списка.
    private static let topAnchorID = "apps-list-top"

    enum AppFilter: String, CaseIterable, Identifiable {
        case all = "Все"
        case bar = "В панели"
        case recent = "Недавние"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .all: return "square.grid.2x2"
            case .bar: return "pin"
            case .recent: return "clock"
            }
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            headerView
            controlsView
            appsListView
            if let toast {
                SettingsHint(text: toast, color: .green)
                    .transition(.opacity)
            }
        }
        .animation(animations.quick, value: toast)
        .animation(animations.quick, value: isEditMode)
        // Смена фильтра — без анимации макета: раньше список «дёргался»
        .frame(minHeight: 560, alignment: .top)
        .confirmationDialog(
            "Удалить выбранные приложения из BarX?",
            isPresented: $pendingDelete,
            titleVisibility: .visible
        ) {
            Button("Удалить (\(selectedApps.count))", role: .destructive) { performBulkDelete() }
            Button("Отмена", role: .cancel) { }
        } message: {
            Text("Приложения уберутся из панели, закреплённых и недавних. Сами программы на диске останутся.")
        }
    }

    // MARK: - Шапка

    private var headerView: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Управление приложениями")
                    .font(.title2.bold())
                    .adaptiveTextColor()
                Text("Добавляйте приложения в панель Bar, закрепляйте в Launcher и запускайте в один клик.")
                    .font(.caption)
                    .adaptiveTextColor()
                    .opacity(0.7)
            }

            Spacer()

            HStack(spacing: 14) {
                statBadge(value: appState.installedApps.count, title: "всего", icon: "square.stack.3d.up")
                statBadge(value: appState.barApps.count, title: "в панели", icon: "pin")
                statBadge(value: appState.recentApps.count, title: "недавних", icon: "clock")
            }
        }
    }

    private func statBadge(value: Int, title: String, icon: String) -> some View {
        VStack(spacing: 1) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 9))
                Text("\(value)")
                    .font(.system(size: 13, weight: .semibold))
            }
            .adaptiveTextColor()
            Text(title)
                .font(.system(size: 9))
                .adaptiveTextColor()
                .opacity(0.5)
        }
    }

    // MARK: - Панель управления

    private var controlsView: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                searchField
                Spacer()
                actionButtons
            }

            HStack(spacing: 8) {
                filterPicker
                Spacer()
                sortPicker
                viewModeToggle
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .adaptiveTextColor()
                .opacity(0.5)
            TextField("Поиск по названию или пути…", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .adaptiveTextColor()
            if !searchText.isEmpty {
                Button {
                    withAnimation(animations.spring) { searchText = "" }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 10))
                        .adaptiveTextColor()
                        .opacity(0.5)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
        .frame(maxWidth: 320)
    }

    private var actionButtons: some View {
        HStack(spacing: 8) {
            Button {
                withAnimation(animations.spring) {
                    if isEditMode {
                        if confirmDelete && !selectedApps.isEmpty {
                            pendingDelete = true
                        } else {
                            performBulkDelete()
                        }
                    } else {
                        isEditMode = true
                    }
                }
            } label: {
                smallActionLabel(
                    isEditMode ? (selectedFilter == .bar ? "Убрать" : "Удалить") : "Выбрать",
                    icon: isEditMode ? "trash" : "checkmark.circle",
                    tint: isEditMode ? Color.red.opacity(0.25) : Color.white.opacity(0.1)
                )
            }
            .buttonStyle(.plain)
            .disabled(filteredApps.isEmpty && !isEditMode)
            .help(isEditMode ? "Применить к выбранным" : "Выбрать несколько приложений")

            if isEditMode {
                Button {
                    withAnimation(animations.spring) {
                        if selectedApps.count == filteredApps.count {
                            selectedApps.removeAll()
                        } else {
                            selectedApps = Set(filteredApps.map { selectionKey($0) })
                        }
                    }
                } label: {
                    smallActionLabel(
                        selectedApps.count == filteredApps.count ? "Снять" : "Все",
                        icon: "rectangle.stack",
                        tint: Color.white.opacity(0.1)
                    )
                }
                .buttonStyle(.plain)

                Button {
                    withAnimation(animations.spring) {
                        isEditMode = false
                        selectedApps.removeAll()
                    }
                } label: {
                    smallActionLabel("Готово", icon: "checkmark", tint: Color.white.opacity(0.16))
                }
                .buttonStyle(.plain)
            }

            Button {
                appState.refreshApps()
                showToast("Список приложений обновляется…")
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.clockwise")
                        .rotationEffect(.degrees(appState.isLoading ? 360 : 0))
                        .animation(
                            appState.isLoading
                                ? .linear(duration: 1).repeatForever(autoreverses: false)
                                : animations.hover,
                            value: appState.isLoading
                        )
                    Text("Обновить")
                }
                .font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 7).fill(Color.white.opacity(0.1)))
                .adaptiveTextColor()
            }
            .buttonStyle(.plain)
            .disabled(appState.isLoading)

            Button {
                showAddAppWindow()
            } label: {
                smallActionLabel("Добавить", icon: "plus.circle.fill", tint: Color.white.opacity(0.16))
            }
            .buttonStyle(.plain)
            .help("Добавить приложение из Finder")
        }
    }

    private func smallActionLabel(_ title: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
            Text(title)
        }
        .font(.system(size: 12, weight: .medium))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 7).fill(tint))
        .adaptiveTextColor()
    }

    private var filterPicker: some View {
        HStack(spacing: 4) {
            ForEach(AppFilter.allCases) { filter in
                FilterChip(
                    title: filter.rawValue,
                    icon: filter.icon,
                    count: count(for: filter),
                    isSelected: selectedFilter == filter
                ) {
                    withAnimation(animations.quick) {
                        selectedFilter = filter
                        selectedApps.removeAll()
                    }
                }
            }
        }
    }

    private var sortPicker: some View {
        Picker("", selection: $sortOrder) {
            Text("По имени").tag("name")
            Text("По дате").tag("recent")
            Text("По частоте").tag("launches")
            Text("По размеру").tag("size")
        }
        .pickerStyle(.menu)
        .labelsHidden()
        .frame(width: 118)
        .tint(.white)
        .help("Сортировка списка")
    }

    private var viewModeToggle: some View {
        HStack(spacing: 2) {
            modeButton(icon: "list.bullet", mode: "list", help: "Списком")
            modeButton(icon: "square.grid.2x2", mode: "grid", help: "Сеткой")
        }
        .padding(2)
        .background(RoundedRectangle(cornerRadius: 7).fill(Color.white.opacity(0.08)))
    }

    private func modeButton(icon: String, mode: String, help: String) -> some View {
        Button {
            withAnimation(animations.spring) { viewMode = mode }
        } label: {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .frame(width: 26, height: 22)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(viewMode == mode ? Color.white.opacity(0.22) : Color.clear)
                )
                .adaptiveTextColor()
                .opacity(viewMode == mode ? 1 : 0.6)
        }
        .buttonStyle(.plain)
        .help(help)
    }

    // MARK: - Список

    private var appsListView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                // Якорь для мгновенного возврата наверх при смене фильтра
                Color.clear
                    .frame(height: 1)
                    .id(Self.topAnchorID)

                if appState.isLoading && appState.installedApps.isEmpty {
                    loadingView
                } else if filteredApps.isEmpty {
                    emptyStateView
                } else if viewMode == "grid" {
                    gridView
                } else {
                    listView
                }
            }
            .onChange(of: selectedFilter) { _, _ in scrollToTop(proxy) }
            .onChange(of: sortOrder) { _, _ in scrollToTop(proxy) }
            .onChange(of: searchText) { _, _ in scrollToTop(proxy) }
            .onChange(of: viewMode) { _, _ in scrollToTop(proxy) }
            .onChange(of: appState.installedApps.count) { _, _ in scrollToTop(proxy) }
        }
        // Фиксированная высота: при смене фильтра внешний ScrollView
        // не пересчитывает контент и ничего не подпрыгивает
        .frame(height: 420)
        .onDrop(of: [.fileURL], isTargeted: $isDragging) { providers in
            _ = handleDrop(providers: providers)
            return true
        }
        .overlay {
            if isDragging {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.white.opacity(0.6), style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                    .overlay(
                        VStack(spacing: 6) {
                            Image(systemName: "square.and.arrow.down")
                                .font(.system(size: 24))
                            Text("Отпустите, чтобы добавить приложение")
                                .font(.caption)
                        }
                        .adaptiveTextColor()
                    )
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }
        }
    }

    private var listView: some View {
        LazyVStack(spacing: 6) {
            ForEach(filteredApps) { app in
                appRow(app)
            }
        }
        .padding(.vertical, 6)
    }

    private var gridView: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4),
            spacing: 10
        ) {
            ForEach(filteredApps) { app in
                AppGridCard(
                    app: app,
                    state: appState.getAppState(app),
                    isSelected: selectedApps.contains(selectionKey(app)),
                    isEditMode: isEditMode,
                    onTap: {
                        if isEditMode {
                            toggleSelection(app)
                        } else {
                            LauncherManager.shared.launchApp(app)
                        }
                    }
                )
            }
        }
        .padding(.vertical, 8)
    }

    private func appRow(_ app: AppItem) -> some View {
        AppCardView(
            app: app,
            isInBar: appState.isInBar(app),
            isRecent: appState.isRecent(app),
            isPinned: appState.isPinned(app),
            isSelected: selectedApps.contains(selectionKey(app)),
            isEditMode: isEditMode,
            showPath: showPath,
            onToggleSelect: { toggleSelection(app) },
            onTogglePin: {
                appState.togglePinApp(app)
                showToast(appState.isPinned(app) ? "Закреплено: \(app.name)" : "Снято закрепление: \(app.name)")
            },
            onToggleBar: {
                if appState.isInBar(app) {
                    appState.removeFromBar(app)
                    showToast("Убрано из панели: \(app.name)")
                } else if appState.addToBar(app) {
                    showToast("Добавлено в панель: \(app.name)")
                } else {
                    showToast("Больше \(BarXSettings.maxBarApps) приложений в панель не помещается — можно только убрать")
                }
            },
            onLaunch: { LauncherManager.shared.launchApp(app) },
            onReveal: { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: app.path)]) },
            onCopyPath: { copyPath(app) },
            onRemove: { removeApp(app) }
        )
    }

    private var loadingView: some View {
        VStack(spacing: 14) {
            ProgressView()
                .controlSize(.large)
            Text("Сканируем приложения…")
                .font(.caption)
                .adaptiveTextColor()
                .opacity(0.7)
                .padding(.horizontal, 14)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color.white.opacity(0.08)))
                .shimmer(isActive: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 70)
    }

    private var emptyStateView: some View {
        VStack(spacing: 14) {
            Image(systemName: searchText.isEmpty ? "app.dashed" : "magnifyingglass")
                .font(.system(size: 44))
                .adaptiveTextColor()
                .opacity(0.45)

            Text(searchText.isEmpty ? "Нет приложений в этом списке" : "Ничего не найдено")
                .font(.headline)
                .adaptiveTextColor()
                .opacity(0.75)

            Text(searchText.isEmpty
                 ? "Нажмите «Добавить» или перетащите .app из Finder"
                 : "Измените запрос или сбросьте фильтр")
                .font(.caption)
                .adaptiveTextColor()
                .opacity(0.5)
                .multilineTextAlignment(.center)

            if !searchText.isEmpty || selectedFilter != .all {
                Button("Сбросить фильтры") {
                    withAnimation(animations.spring) {
                        searchText = ""
                        selectedFilter = .all
                    }
                }
                .buttonStyle(.bordered)
                .tint(.white)
                .controlSize(.small)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 70)
        .animatedAppear()
    }

    // MARK: - Данные

    private var filteredApps: [AppItem] {
        var apps: [AppItem]

        switch selectedFilter {
        case .all: apps = appState.installedApps
        case .bar: apps = appState.barApps
        case .recent: apps = appState.recentApps
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty {
            apps = apps.filter {
                $0.name.localizedCaseInsensitiveContains(query) ||
                $0.path.localizedCaseInsensitiveContains(query)
            }
        }

        // Дедупликация по пути: UUID у сканирования и «недавних» различаются
        var seenPaths = Set<String>()
        var seenIds = Set<UUID>()
        apps = apps.filter { app in
            if !app.path.isEmpty {
                return seenPaths.insert(app.path.lowercased()).inserted
            }
            return seenIds.insert(app.id).inserted
        }

        switch sortOrder {
        case "recent":
            apps.sort { ($0.lastLaunched ?? .distantPast) > ($1.lastLaunched ?? .distantPast) }
        case "launches":
            // Чаще запускаемые — наверху; при равенстве — по времени запуска
            apps.sort {
                if $0.launchCount != $1.launchCount { return $0.launchCount > $1.launchCount }
                return ($0.lastLaunched ?? .distantPast) > ($1.lastLaunched ?? .distantPast)
            }
        case "size":
            apps.sort { fileSize($0.path) > fileSize($1.path) }
        default:
            apps.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        }

        return apps
    }

    private func count(for filter: AppFilter) -> Int {
        switch filter {
        case .all: return appState.installedApps.count
        case .bar: return appState.barApps.count
        case .recent: return appState.recentApps.count
        }
    }

    /// Размер приложения считается один раз и кэшируется:
    /// раньше FileManager вызывался прямо в компараторе сортировки.
    private func fileSize(_ path: String) -> Int64 {
        if let cached = sizeCache[path] { return cached }
        let attributes = try? FileManager.default.attributesOfItem(atPath: path)
        let value = (attributes?[.size] as? NSNumber)?.int64Value ?? 0
        DispatchQueue.main.async { sizeCache[path] = value }
        return value
    }

    // MARK: - Операции

    /// Возврат в начало списка без анимации — иначе содержимое «дёргается».
    private func scrollToTop(_ proxy: ScrollViewProxy) {
        proxy.scrollTo(Self.topAnchorID, anchor: .top)
    }

    private func toggleSelection(_ app: AppItem) {
        withAnimation(animations.hover) {
            if selectedApps.contains(selectionKey(app)) {
                selectedApps.remove(selectionKey(app))
            } else {
                selectedApps.insert(selectionKey(app))
            }
        }
    }

    /// Ключ выбора приложения — по пути, а не по UUID: сканирование даёт
    /// приложениям новые UUID, и выбор на их основе слетал при обновлении
    /// списка (правило проекта — идентичность по пути).
    private func selectionKey(_ app: AppItem) -> String {
        app.path.isEmpty ? app.id.uuidString : app.path.lowercased()
    }

    private func performBulkDelete() {
        let targets = filteredApps.filter { selectedApps.contains(selectionKey($0)) }
        for app in targets {
            if selectedFilter == .bar {
                appState.removeFromBar(app)
            } else {
                removeApp(app, silent: true)
            }
        }
        withAnimation(animations.spring) {
            selectedApps.removeAll()
            isEditMode = false
        }
        showToast(targets.isEmpty ? "Ничего не выбрано" : "Удалено из BarX: \(targets.count)")
    }

    /// Убирает приложение из BarX (панель, закреплённые, недавние).
    private func removeApp(_ app: AppItem, silent: Bool = false) {
        appState.removeFromBar(app)
        appState.pinnedApps.removeAll { AppStateManager.isSameApp($0, app) }
        appState.savePinnedApps()
        appState.recentApps.removeAll { AppStateManager.isSameApp($0, app) }
        appState.saveRecentApps()
        appState.objectWillChange.send()
        if !silent { showToast("Удалено из BarX: \(app.name)") }
    }

    private func copyPath(_ app: AppItem) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(app.path, forType: .string)
        showToast("Путь скопирован")
    }

    private func showToast(_ message: String) {
        withAnimation(animations.spring) { toast = message }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            withAnimation(animations.hover) {
                if toast == message { toast = nil }
            }
        }
    }

    // MARK: - Окна

    private func showAddAppWindow() {
        BarXWindowManager.shared.showWindow(
            id: "addApp",
            title: "Добавить приложение",
            size: CGSize(width: 520, height: 620),
            content: AddAppFromFinderView(
                onAppAdded: { app in
                    appState.registerExternalApp(app)
                    let addedToBar = appState.addToBar(app)
                    BarXWindowManager.shared.closeWindow(id: "addApp")
                    showToast(addedToBar
                              ? "Добавлено: \(app.name)"
                              : "Добавлено: \(app.name). В панель не добавлено — максимум \(BarXSettings.maxBarApps)")
                },
                onCancel: {
                    BarXWindowManager.shared.closeWindow(id: "addApp")
                }
            )
            .environmentObject(appState)
        )
    }

    // MARK: - Drag & Drop

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
                DispatchQueue.main.async {
                    if let error {
                        showToast("Не удалось прочитать файл: \(error.localizedDescription)")
                        return
                    }
                    if let data = item as? Data,
                       let url = URL(dataRepresentation: data, relativeTo: nil) {
                        addAppFromURL(url)
                    } else {
                        showToast("Перетащите файл приложения (.app) из Finder")
                    }
                }
            }
        }
        return true
    }

    private func addAppFromURL(_ url: URL) {
        guard url.pathExtension == "app" else {
            showToast("Можно добавлять только файлы приложений (.app)")
            return
        }

        let name = url.deletingPathExtension().lastPathComponent
        let app = AppItem(
            name: name,
            path: url.path,
            icon: AppStateManager.iconName(for: name),
            preset: "Все приложения",
            type: .application
        )

        appState.registerExternalApp(app)
        if appState.addToBar(app) {
            showToast("Добавлено в панель: \(name)")
        } else {
            showToast("Добавлено в список. В панель не добавлено — максимум \(BarXSettings.maxBarApps)")
        }
    }
}

// MARK: - FilterChip

struct FilterChip: View {
    let title: String
    let icon: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                Text("\(count)")
                    .font(.system(size: 9, weight: .semibold))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(Color.white.opacity(0.15)))
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(isSelected ? Color.white.opacity(0.22) : Color.white.opacity(isHovered ? 0.12 : 0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(isSelected ? Color.white.opacity(0.45) : Color.clear, lineWidth: 1)
            )
            .adaptiveTextColor()
            .opacity(isSelected ? 1 : 0.8)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(AnimationCenter.shared.hover) { isHovered = hovering }
            if hovering { NSCursor.pointingHand.set() }
        }
    }
}

// MARK: - AppGridCard

struct AppGridCard: View {
    let app: AppItem
    let state: AppStateManager.AppState
    let isSelected: Bool
    let isEditMode: Bool
    let onTap: () -> Void

    @State private var isHovered = false
    @State private var appIcon: NSImage?
    @AppStorage("showAppIcons") private var showAppIcons = true

    @StateObject private var animations = AnimationCenter.shared

    var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(isHovered ? 0.14 : 0.07))
                    .frame(height: 72)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isSelected ? Color.green.opacity(0.7) : Color.white.opacity(0.1),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )

                iconImage
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if state.isInBar {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.blue)
                        .padding(4)
                }
            }

            Text(app.name)
                .font(.system(size: 11, weight: .medium))
                .adaptiveTextColor()
                .lineLimit(1)

            HStack(spacing: 3) {
                if state.isPinned {
                    Image(systemName: "star.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(.yellow)
                }
                if state.isRecent {
                    Image(systemName: "clock")
                        .font(.system(size: 8))
                        .adaptiveTextColor()
                        .opacity(0.5)
                }
            }
            .frame(height: 10)
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Color.green.opacity(0.12) : Color.clear)
        )
        .scaleEffect(isHovered ? 1.03 : 1.0)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .onHover { hovering in
            withAnimation(animations.hover) { isHovered = hovering }
            if hovering { NSCursor.pointingHand.set() }
        }
        .onAppear {
            guard showAppIcons, appIcon == nil else { return }
            DispatchQueue.global(qos: .userInitiated).async {
                let icon = NSWorkspace.shared.icon(forFile: app.path)
                guard icon.size.width > 0 else { return }
                let resized = icon.resized(to: NSSize(width: 38, height: 38))
                DispatchQueue.main.async { appIcon = resized }
            }
        }
        .help(app.name)
    }

    @ViewBuilder
    private var iconImage: some View {
        if showAppIcons, let appIcon {
            Image(nsImage: appIcon)
                .resizable()
                .frame(width: 38, height: 38)
        } else {
            Image(systemName: app.icon)
                .font(.system(size: 26))
                .adaptiveTextColor()
        }
    }
}

// MARK: - AppCardView

struct AppCardView: View {
    let app: AppItem
    let isInBar: Bool
    let isRecent: Bool
    var isPinned: Bool = false
    let isSelected: Bool
    let isEditMode: Bool
    var showPath: Bool = true
    let onToggleSelect: () -> Void
    var onTogglePin: () -> Void = {}
    let onToggleBar: () -> Void
    let onLaunch: () -> Void
    var onReveal: () -> Void = {}
    var onCopyPath: () -> Void = {}
    let onRemove: () -> Void

    @State private var isHovered = false
    @State private var isRemoving = false
    @State private var appIcon: NSImage?
    @AppStorage("showAppIcons") private var showAppIcons = true

    @StateObject private var animations = AnimationCenter.shared

    var body: some View {
        HStack(spacing: 12) {
            if isEditMode {
                Button(action: onToggleSelect) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 19))
                        .foregroundStyle(isSelected ? .green : .white.opacity(0.4))
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }

            iconView

            VStack(alignment: .leading, spacing: 3) {
                titleRow
                if showPath {
                    Text(app.path)
                        .font(.caption2)
                        .adaptiveTextColor()
                        .opacity(0.45)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Spacer(minLength: 6)

            HStack(spacing: 8) {
                Button(action: onTogglePin) {
                    Image(systemName: isPinned ? "star.fill" : "star")
                        .font(.system(size: 13))
                        .foregroundStyle(isPinned ? .yellow : .white.opacity(0.5))
                }
                .buttonStyle(.plain)
                .help(isPinned ? "Снять закрепление" : "Закрепить в Launcher")

                Button(action: onToggleBar) {
                    Image(systemName: isInBar ? "pin.fill" : "pin")
                        .font(.system(size: 13))
                        .foregroundStyle(isInBar ? .blue : .white.opacity(0.5))
                }
                .buttonStyle(.plain)
                .help(isInBar ? "Убрать из панели" : "Добавить в панель")

                if !isEditMode {
                    Button(action: onRemove) {
                        Image(systemName: "trash")
                            .font(.system(size: 13))
                            .foregroundStyle(.red.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    .help("Удалить из BarX")
                }

                Button(action: onLaunch) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 19))
                        .foregroundStyle(
                            LinearGradient(colors: [.green, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                }
                .buttonStyle(.plain)
                .help("Запустить")
            }
            .opacity(isHovered || isEditMode ? 1 : 0.4)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(rowBackground)
        .scaleEffect(isRemoving ? 0.96 : 1.0)
        .opacity(isRemoving ? 0.5 : 1.0)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(animations.hover) { isHovered = hovering }
        }
        .contextMenu { contextMenu }
    }

    private var iconView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9)
                .fill(Color.white.opacity(0.08))
                .frame(width: 40, height: 40)
                .overlay(
                    RoundedRectangle(cornerRadius: 9)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )

            if showAppIcons, let appIcon {
                Image(nsImage: appIcon)
                    .resizable()
                    .frame(width: 28, height: 28)
            } else {
                Image(systemName: app.icon)
                    .font(.system(size: 18))
                    .adaptiveTextColor()
            }
        }
        .onAppear {
            guard showAppIcons, appIcon == nil else { return }
            DispatchQueue.global(qos: .userInitiated).async {
                let icon = NSWorkspace.shared.icon(forFile: app.path)
                guard icon.size.width > 0 else { return }
                let resized = icon.resized(to: NSSize(width: 28, height: 28))
                DispatchQueue.main.async { appIcon = resized }
            }
        }
    }

    private var titleRow: some View {
        HStack(spacing: 6) {
            Text(app.name)
                .font(.system(size: 13, weight: .semibold))
                .adaptiveTextColor()
                .lineLimit(1)

            if isInBar {
                Image(systemName: "pin.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(.blue)
            }

            if isPinned {
                Image(systemName: "star.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(.yellow)
            }

            if isRecent {
                Text("недавнее")
                    .font(.system(size: 8, weight: .medium))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(Color.blue.opacity(0.3)))
                    .adaptiveTextColor()
            }
        }
    }

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(
                isRemoving ? Color.red.opacity(0.12) :
                isSelected ? Color.green.opacity(0.12) :
                isHovered ? Color.white.opacity(0.08) : Color.clear
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        isSelected ? Color.green.opacity(0.5) :
                        isHovered ? Color.white.opacity(0.15) : Color.clear,
                        lineWidth: isSelected ? 2 : 1
                    )
            )
    }

    @ViewBuilder
    private var contextMenu: some View {
        Button("Запустить", action: onLaunch)
        Button(isInBar ? "Убрать из панели" : "Добавить в панель", action: onToggleBar)
        Button(isPinned ? "Снять закрепление" : "Закрепить в Launcher", action: onTogglePin)
        Divider()
        Button("Показать в Finder", action: onReveal)
        Button("Скопировать путь", action: onCopyPath)
        Divider()
        Button("Удалить из BarX", role: .destructive) {
            // Удаляем сразу: задержка делала клик «вязким»
            isRemoving = true
            onRemove()
            withAnimation(animations.quick) { isRemoving = false }
        }
    }
}
