//
//  BarXMenuView.swift
//  BarX
//
//  Главное меню BarX: шапка, поиск, панель Bar, папки и действия.
//  Меню показывается целиком, без внутренней прокрутки.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers
import Combine

// MARK: - BarXMenuView

struct BarXMenuView: View {
    @EnvironmentObject var appState: AppStateManager
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var launcherManager = LauncherManager.shared
    @StateObject private var updateManager = BarXUpdateManager.shared

    @State private var searchText = ""
    @State private var filteredPresets: [Preset] = []
    @State private var hoveredPresetId: UUID?
    @State private var refreshTrigger = UUID()
    @State private var isHoveringClose = false
    @State private var isHoveringSettings = false
    @State private var logoPulse = false
    @State private var showSearchField = false

    @AppStorage("showPresetCount") private var showPresetCount = true

    @StateObject private var animations = AnimationCenter.shared

    // MARK: - Body

    var body: some View {
        ZStack {
            menuBackground

            VStack(spacing: 0) {
                headerView
                sectionDivider

                if showSearchField {
                    searchView
                        .transition(animations.appearTransition)
                    sectionDivider
                }

                BarPanelView(query: searchText)
                    .animatedAppear(delay: 0.03)

                sectionDivider

                foldersView
                    .id(refreshTrigger)
                    .animatedAppear(delay: 0.06)

                sectionDivider

                actionsView
                    .animatedAppear(delay: 0.09)

                statusFooter
                    .animatedAppear(delay: 0.12)
            }
        }
        .frame(width: 340)
        .animation(animations.spring, value: showSearchField)
        .animation(animations.spring, value: appState.barApps.count)
        .animation(animations.spring, value: filteredPresets.count)
        .onAppear {
            loadPresets()
            updateFilteredPresets()
            withAnimation(animations.pulse) { logoPulse = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: .presetsDidChange)) { _ in
            loadPresets()
            updateFilteredPresets()
            withAnimation(animations.spring) { refreshTrigger = UUID() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .barItemsDidChange)) { _ in
            appState.objectWillChange.send()
        }
        .onChange(of: searchText) { _, newValue in
            updateFilteredPresets()
            if !newValue.isEmpty && !showSearchField {
                withAnimation(animations.spring) { showSearchField = true }
            }
        }
    }

    // MARK: - Фон

    private var menuBackground: some View {
        ZStack {
            if let theme = themeManager.effectiveTheme {
                GradientBackground(theme: theme)
                    .ignoresSafeArea()
                    .overlay {
                        if animations.animatedBackground {
                            AnimatedAuraOverlay(accent: Color(hex: BarXSettings.appearanceAccent))
                        }
                    }
            }
        }
    }

    private var sectionDivider: some View {
        Divider()
            .opacity(0.35)
            .background(Color.white.opacity(0.3))
    }

    // MARK: - Шапка

    private var headerView: some View {
        HStack(spacing: 10) {
            HStack(spacing: 9) {
                Image(systemName: "sparkles")
                    .font(.system(size: 15, weight: .semibold))
                    .adaptiveTextColor()
                    .scaleEffect(logoPulse ? 1.06 : 0.98)
                    .glowPulse(Color(hex: BarXSettings.appearanceAccent))
                    .animation(animations.pulse, value: logoPulse)

                VStack(alignment: .leading, spacing: 0) {
                    Text("BarX")
                        .font(.system(size: 16, weight: .semibold))
                        .adaptiveTextColor()
                    Text(statusLine)
                        .font(.system(size: 9))
                        .adaptiveTextColor()
                        .opacity(0.5)
                }
            }

            Spacer()

            if updateManager.updateAvailable {
                Button {
                    updateManager.checkForUpdates()
                } label: {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.green)
                        .glowPulse(.green)
                }
                .buttonStyle(.plain)
                .help("Доступно обновление \(updateManager.updateVersion)")
                .transition(animations.popTransition)
            }

            Button {
                withAnimation(animations.spring) { showSearchField.toggle() }
            } label: {
                Image(systemName: showSearchField ? "magnifyingglass.circle.fill" : "magnifyingglass")
                    .font(.system(size: 14))
                    .adaptiveTextColor()
                    .opacity(showSearchField ? 1 : 0.75)
            }
            .buttonStyle(.plain)
            .hoverLift()
            .help("Поиск по папкам и панели")

            Button {
                openSettingsWindow()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 14))
                    .adaptiveTextColor()
                    .opacity(isHoveringSettings ? 1 : 0.75)
                    .rotationEffect(.degrees(isHoveringSettings ? 25 : 0))
            }
            .buttonStyle(.plain)
            .help("Настройки")
            .keyboardShortcut(",", modifiers: .command)
            .onHover { hovering in
                withAnimation(animations.spring) { isHoveringSettings = hovering }
                if hovering { NSCursor.pointingHand.set() }
            }

            Button {
                closeMainMenu()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .adaptiveTextColor()
                    .opacity(isHoveringClose ? 0.95 : 0.6)
                    .rotationEffect(.degrees(isHoveringClose ? 90 : 0))
            }
            .buttonStyle(.plain)
            .help("Закрыть меню")
            .onHover { hovering in
                withAnimation(animations.spring) { isHoveringClose = hovering }
                if hovering { NSCursor.pointingHand.set() }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 12)
    }

    private var statusLine: String {
        let apps = appState.installedApps.count
        let bar = appState.barApps.count
        let folders = appState.presets.count
        return "\(apps) прил. · \(bar) в панели · \(folders) папок"
    }

    // MARK: - Поиск

    private var searchView: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .adaptiveTextColor()
                .opacity(0.6)

            TextField("Поиск приложений и папок…", text: $searchText)
                .textFieldStyle(.plain)
                .adaptiveTextColor()
                .font(.system(size: 13))

            if !searchText.isEmpty {
                Button {
                    withAnimation(animations.spring) { searchText = "" }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .adaptiveTextColor()
                        .opacity(0.5)
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: BarXSettings.appearanceCardRadius)
                .fill(Color.white.opacity(0.09))
                .overlay(
                    RoundedRectangle(cornerRadius: BarXSettings.appearanceCardRadius)
                        .stroke(
                            searchText.isEmpty ? Color.white.opacity(0.1) : Color(hex: BarXSettings.appearanceAccent).opacity(0.6),
                            lineWidth: 1
                        )
                )
        )
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Папки

    private func folderTooltip(_ preset: Preset) -> String {
        guard !preset.items.isEmpty else { return preset.name }
        let names = preset.items.prefix(10).map { "• \($0.name)" }.joined(separator: "\n")
        let suffix = preset.items.count > 10 ? "\n…и ещё \(preset.items.count - 10)" : ""
        return "\(preset.name)\n\(names)\(suffix)"
    }

    private var foldersView: some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 9, weight: .bold))
                    .adaptiveTextColor()
                    .opacity(0.45)
                Text("МОИ ПАПКИ")
                    .font(.system(size: 10, weight: .semibold))
                    .adaptiveTextColor()
                    .opacity(0.5)
                Spacer()
                if showPresetCount {
                    Text("\(filteredPresets.count)")
                        .font(.system(size: 9, weight: .semibold))
                        .adaptiveTextColor()
                        .opacity(0.75)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Color.white.opacity(0.12)))
                        .transition(.scale.combined(with: .opacity))
                }
                Button {
                    openAddFolderWindow()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 12))
                        .adaptiveTextColor()
                        .opacity(0.65)
                }
                .buttonStyle(.plain)
                .help("Создать новую папку")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)

            if filteredPresets.isEmpty && !hasSearchQuery {
                emptyFoldersView
            } else if filteredPresets.isEmpty {
                noResultsView
            } else {
                ForEach(Array(filteredPresets.enumerated()), id: \.element.id) { index, preset in
                    folderRow(preset, index: index)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
    }

    private var hasSearchQuery: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func folderRow(_ preset: Preset, index: Int) -> some View {
        FolderRow(
            preset: preset,
            isHovered: hoveredPresetId == preset.id,
            showItemCount: showPresetCount,
            onTap: { openItemsWindow(for: preset) },
            onHover: { hovering in
                withAnimation(animations.quick) {
                    hoveredPresetId = hovering ? preset.id : nil
                }
            }
        )
        .help(folderTooltip(preset))
        .contextMenu { folderMenu(for: preset) }
        .animatedAppear(delay: Double(index) * 0.015)
    }

    @ViewBuilder
    private func folderMenu(for preset: Preset) -> some View {
        Button("Открыть") { openItemsWindow(for: preset) }
        Button("Показать в Finder") { revealFolder(preset) }
        Divider()
        Button("Удалить папку", role: .destructive) { deleteFolder(preset) }
    }

    private func revealFolder(_ preset: Preset) {
        let urls = preset.items.map { URL(fileURLWithPath: $0.path) }
        guard !urls.isEmpty else { return }
        NSWorkspace.shared.activateFileViewerSelecting(urls)
    }

    private var emptyFoldersView: some View {
        VStack(spacing: 6) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 26))
                .adaptiveTextColor()
                .opacity(0.45)
            Text("Нет папок")
                .font(.caption)
                .adaptiveTextColor()
                .opacity(0.7)
            Button("Создать папку") { openAddFolderWindow() }
                .buttonStyle(.plain)
                .font(.caption2)
                .adaptiveTextColor()
                .opacity(0.8)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.white.opacity(0.12)))
                .hoverLift()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .animatedAppear()
    }

    private var noResultsView: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 26))
                .adaptiveTextColor()
                .opacity(0.4)
            Text("Ничего не найдено")
                .font(.caption)
                .adaptiveTextColor()
                .opacity(0.6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .animatedAppear()
    }

    // MARK: - Действия

    private var actionsView: some View {
        VStack(spacing: 2) {
            BarXActionButton(
                icon: "magnifyingglass",
                title: "Открыть Launcher",
                shortcut: KeyCodeHelper.normalizeHotkey(launcherManager.launcherHotkeyKey),
                accent: Color(hex: BarXSettings.appearanceAccent)
            ) {
                launcherManager.toggleLauncher()
            }

            BarXActionButton(
                icon: "arrow.clockwise",
                title: updateManager.isChecking ? "Проверка…" : "Проверить обновления",
                isSpinning: updateManager.isChecking
            ) {
                updateManager.checkForUpdates()
            }
            .disabled(updateManager.isChecking)

            Divider()
                .opacity(0.3)
                .background(Color.white.opacity(0.3))
                .padding(.vertical, 4)

            BarXActionButton(
                icon: "power",
                title: "Выйти",
                accent: .red
            ) {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(8)
    }

    // MARK: - Подвал

    private var statusFooter: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.green.opacity(0.8))
                .frame(width: 5, height: 5)
                .glowPulse(.green)
            Text("BarX работает")
                .font(.system(size: 9))
                .adaptiveTextColor()
                .opacity(0.45)
            Spacer()
            if let scan = appState.lastScanDate {
                Text("Обновлено \(scan.formatted(date: .omitted, time: .shortened))")
                    .font(.system(size: 9))
                    .adaptiveTextColor()
                    .opacity(0.35)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 10)
    }

    // MARK: - Действия и окна

    private func openAddFolderWindow() {
        BarXWindowManager.shared.showWindow(
            id: "addFolder",
            title: "Новая папка",
            size: CGSize(width: 600, height: 600),
            content: AddFolderView(
                onAdded: {
                    appState.savePresets()
                    updateFilteredPresets()
                    withAnimation(animations.spring) { refreshTrigger = UUID() }
                }
            )
            .environmentObject(appState)
        )
    }

    private func openSettingsWindow() {
        BarXWindowManager.shared.showWindow(
            id: "settings",
            title: "Настройки BarX",
            size: CGSize(width: 940, height: 680),
            content: SettingsWindow()
                .environmentObject(appState)
        )
    }

    private func closeMainMenu() {
        // Скрываем панель меню (MenuBarExtra) и окно «BarX»,
        // но НЕ прячем приложение целиком — иначе закроется и Настройки.
        BarXWindowManager.shared.dismissMenuPresentations()
    }

    private func deleteFolder(_ preset: Preset) {
        let alert = NSAlert()
        alert.messageText = "Удалить папку «\(preset.name)»?"
        alert.informativeText = "Все элементы внутри папки будут удалены."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Удалить")
        alert.addButton(withTitle: "Отмена")
        NSApp.activate()
        if alert.runModal() == .alertFirstButtonReturn {
            BarXWindowManager.shared.closeWindow(id: "items-\(preset.id.uuidString)")
            withAnimation(animations.spring) {
                appState.removePreset(preset)
            }
            updateFilteredPresets()
            refreshTrigger = UUID()
        }
    }

    private func loadPresets() {
        appState.loadPresets()
    }

    private func updateFilteredPresets() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if query.isEmpty {
            filteredPresets = appState.presets
        } else {
            filteredPresets = appState.presets.filter {
                $0.name.localizedCaseInsensitiveContains(query) ||
                $0.items.contains { $0.name.localizedCaseInsensitiveContains(query) }
            }
        }
    }

    private func openItemsWindow(for preset: Preset) {
        let windowID = "items-\(preset.id.uuidString)"
        // Пересобираем окно, иначе оно показывает устаревший снимок элементов
        BarXWindowManager.shared.closeWindow(id: windowID)

        BarXWindowManager.shared.showWindow(
            id: windowID,
            title: preset.name,
            size: CGSize(width: 440, height: 460),
            content: ItemsListView(
                presetName: preset.name,
                items: preset.items,
                onItemSelected: { item in
                    BarXWindowManager.shared.closeWindow(id: windowID)
                    launcherManager.launchApp(item)
                },
                onClose: {
                    BarXWindowManager.shared.closeWindow(id: windowID)
                }
            )
            .environmentObject(appState)
        )
    }
}

// MARK: - AnimatedAuraOverlay
// Медленно перемещающиеся световые пятна — «живой» фон меню.

struct AnimatedAuraOverlay: View {
    let accent: Color
    @State private var animate = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Circle()
                    .fill(accent.opacity(0.22))
                    .frame(width: geometry.size.width * 0.7)
                    .blur(radius: 60)
                    .offset(
                        x: animate ? geometry.size.width * 0.25 : -geometry.size.width * 0.25,
                        y: animate ? -geometry.size.height * 0.2 : geometry.size.height * 0.25
                    )

                Circle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: geometry.size.width * 0.5)
                    .blur(radius: 50)
                    .offset(
                        x: animate ? -geometry.size.width * 0.2 : geometry.size.width * 0.2,
                        y: animate ? geometry.size.height * 0.25 : -geometry.size.height * 0.15
                    )
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            guard AnimationCenter.shared.isEnabled, !AnimationCenter.shared.systemReduceMotion else { return }
            withAnimation(.easeInOut(duration: 9).repeatForever(autoreverses: true)) {
                animate = true
            }
        }
    }
}
