//
//  BarSettingsView.swift
//  BarX
//
//  Раздел «Панель Bar»: оформление панели, порядок приложений,
//  массовые действия и быстрый запуск.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers
import Combine

// MARK: - BarSettingsView

struct BarSettingsView: View {
    @EnvironmentObject var appState: AppStateManager

    @AppStorage("barIconSize") private var iconSize: Double = 36
    @AppStorage("barShowNames") private var showNames = false
    @AppStorage("barShowCounter") private var showCounter = true
    @AppStorage("barPanelStyle") private var panelStyle = "icons"
    @AppStorage("barAppsPerPage") private var appsPerPage = 5
    @AppStorage("showAppIcons") private var showAppIcons = true

    @State private var searchText = ""
    @State private var hoveredAppId: UUID?
    @State private var toast: String?

    @StateObject private var animations = AnimationCenter.shared
    private let launcherManager = LauncherManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerView
            appearanceSection
            listSection
            if let toast {
                SettingsHint(text: toast, color: .green)
                    .transition(.opacity)
            }
        }
        .padding(.vertical, 4)
        .onAppear { normalizeBarSettings() }
        .onChange(of: appsPerPage) { _, _ in clampIconSize() }
        .onChange(of: showNames) { _, _ in clampIconSize() }
        .animation(animations.spring, value: toast)
    }

    // MARK: - Шапка

    private var headerView: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Панель Bar")
                    .font(.headline)
                    .adaptiveTextColor()
                Text("Приложения панели показываются в главном меню BarX.")
                    .font(.caption)
                    .adaptiveTextColor()
                    .opacity(0.65)
            }

            Spacer()

            HStack(spacing: 10) {
                BarStatPill(value: appState.barApps.count, title: "в панели", icon: "pin")
                BarStatPill(value: appState.recentApps.count, title: "недавних", icon: "clock")
            }
        }
    }

    // MARK: - Оформление панели

    /// Значение ступеньки, обрезанное до максимума строки панели.
    private var clampedAppsPerPage: Int {
        max(1, min(appsPerPage, BarXSettings.maxBarAppsPerPage))
    }

    /// Верхняя граница размера значка: столько влезает по центру панели.
    private var maxAllowedIconSize: Double {
        BarXSettings.maxBarIconSize(perPage: clampedAppsPerPage, showNames: showNames)
    }

    private var appearanceSection: some View {
        SettingsCard(title: "Оформление панели", icon: "slider.horizontal.3") {
            Picker("Вид", selection: $panelStyle) {
                Text("Значки").tag("icons")
                Text("Список").tag("list")
            }
            .pickerStyle(.segmented)
            .colorMultiply(.white)

            SettingsInfoRow(label: "Размер значков", value: String(format: "%.0f pt", iconSize))
            Slider(value: $iconSize, in: BarXSettings.barIconSizeRange.lowerBound...maxAllowedIconSize, step: 2)
                .tint(.white)
            SettingsHint(
                text: "Максимум \(Int(maxAllowedIconSize)) pt — столько значков помещается по центру панели при \(clampedAppsPerPage) на странице."
            )

            Toggle("Подписывать приложения", isOn: $showNames)
                .toggleStyle(SwitchToggleStyle(tint: .white))
                .adaptiveTextColor()
                .help("Показывать названия под значками (только для вида «Значки»)")

            Toggle("Показывать счётчик приложений", isOn: $showCounter)
                .toggleStyle(SwitchToggleStyle(tint: .white))
                .adaptiveTextColor()

            // Диапазон на единицу шире максимума строки: при попытке поставить
            // больше значение остаётся прежним, а пользователь видит сообщение.
            Stepper(value: Binding(
                get: { clampedAppsPerPage },
                set: { newValue in
                    if newValue > BarXSettings.maxBarAppsPerPage {
                        showToast("В одну строку не помещается больше \(BarXSettings.maxBarAppsPerPage) приложений — можно только уменьшить.")
                    } else {
                        appsPerPage = newValue
                    }
                }
            ), in: 3...(BarXSettings.maxBarAppsPerPage + 1)) {
                SettingsInfoRow(label: "Приложений в строке", value: "\(clampedAppsPerPage)")
            }
            .adaptiveTextColor()

            Toggle("Показывать настоящие значки приложений", isOn: $showAppIcons)
                .toggleStyle(SwitchToggleStyle(tint: .white))
                .adaptiveTextColor()

            // Мини-предпросмотр панели (одна строка значков)
            BarPanelPreview(
                apps: Array(appState.barApps.prefix(BarXSettings.maxBarAppsPerPage)),
                iconSize: min(iconSize, maxAllowedIconSize),
                showNames: showNames,
                showIcons: showAppIcons,
                isList: panelStyle == "list",
                accent: Color(hex: BarXSettings.appearanceAccent)
            )
            .frame(height: panelStyle == "list" ? 130 : 76)
        }
    }

    // MARK: - Список приложений панели

    private var listSection: some View {
        SettingsCard(title: "Приложения панели", icon: "list.number") {
            HStack(spacing: 8) {
                searchField
                Spacer()
                Button {
                    showAddAppWindow()
                } label: {
                    Label("Добавить", systemImage: "plus.circle.fill")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.bordered)
                .tint(.white)
                .controlSize(.small)

                Menu {
                    Button("Сортировать по имени") { sortBarApps() }
                    Button("Обратный порядок") { reverseBarApps() }
                    Divider()
                    Button("Очистить панель", role: .destructive) { clearBar() }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 14))
                        .adaptiveTextColor()
                        .opacity(0.8)
                }
                .menuStyle(.borderlessButton)
                .frame(width: 28)
                .help("Действия со списком")
            }

            if appState.barApps.isEmpty {
                emptyState
            } else if filteredBarApps.isEmpty {
                SettingsHint(text: "В панели нет приложений по запросу «\(searchText)».")
            } else {
                VStack(spacing: 4) {
                    ForEach(Array(filteredBarApps.enumerated()), id: \.element.id) { index, app in
                        BarAppRow(
                            app: app,
                            showIcon: showAppIcons,
                            position: index,
                            total: filteredBarApps.count,
                            canReorder: searchText.isEmpty,
                            isHovered: hoveredAppId == app.id,
                            onLaunch: { launcherManager.launchApp(app) },
                            onRemove: { remove(app) },
                            onReveal: { reveal(app) },
                            onMoveUp: { move(app, by: -1) },
                            onMoveDown: { move(app, by: 1) },
                            onPin: {
                                appState.togglePinApp(app)
                                showToast(appState.isPinned(app) ? "Закреплено в Launcher" : "Снято закрепление")
                            }
                        )
                        .onHover { hovering in
                            hoveredAppId = hovering ? app.id : nil
                        }
                        .animatedAppear(delay: Double(index) * 0.015)
                    }
                }
            }

            SettingsHint(text: searchText.isEmpty
                ? "Порядок в панели меняется стрелками ↑ ↓ и влияет на главное меню."
                : "Очистите поиск, чтобы менять порядок приложений.")
        }
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .adaptiveTextColor()
                .opacity(0.5)
            TextField("Поиск в панели…", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .adaptiveTextColor()
            if !searchText.isEmpty {
                Button {
                    searchText = ""
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
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(Color.white.opacity(0.08))
        )
        .frame(maxWidth: 240)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "pin.slash")
                .font(.system(size: 30))
                .adaptiveTextColor()
                .opacity(0.4)
            Text("Панель пуста")
                .font(.headline)
                .adaptiveTextColor()
                .opacity(0.7)
            Text("Добавьте приложения, которые нужны под рукой")
                .font(.caption)
                .adaptiveTextColor()
                .opacity(0.5)
            Button("Добавить приложение") { showAddAppWindow() }
                .buttonStyle(.bordered)
                .tint(.white)
                .controlSize(.small)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .animatedAppear()
    }

    // MARK: - Данные

    private var filteredBarApps: [AppItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return appState.barApps }
        return appState.barApps.filter {
            $0.name.localizedCaseInsensitiveContains(query) ||
            $0.path.localizedCaseInsensitiveContains(query)
        }
    }

    // MARK: - Операции

    /// Приводит старые значения к лимиту строки (`maxBarAppsPerPage`
    /// приложений в строке) и размеру значка.
    private func normalizeBarSettings() {
        if appsPerPage > BarXSettings.maxBarAppsPerPage {
            appsPerPage = BarXSettings.maxBarAppsPerPage
        }
        clampIconSize()
    }

    /// Удерживает размер значка в пределах, при котором ряд помещается по центру.
    private func clampIconSize() {
        if iconSize > maxAllowedIconSize {
            iconSize = maxAllowedIconSize
        }
        if iconSize < BarXSettings.barIconSizeRange.lowerBound {
            iconSize = BarXSettings.barIconSizeRange.lowerBound
        }
    }

    private func move(_ app: AppItem, by offset: Int) {
        guard let index = appState.barApps.firstIndex(where: { AppStateManager.isSameApp($0, app) }) else { return }
        let target = index + offset
        guard appState.barApps.indices.contains(target) else { return }
        withAnimation(animations.spring) {
            appState.barApps.swapAt(index, target)
        }
        appState.saveBarApps()
        appState.objectWillChange.send()
    }

    private func sortBarApps() {
        withAnimation(animations.spring) {
            appState.barApps.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        }
        appState.saveBarApps()
        appState.objectWillChange.send()
        showToast("Отсортировано по имени")
    }

    private func reverseBarApps() {
        withAnimation(animations.spring) {
            appState.barApps.reverse()
        }
        appState.saveBarApps()
        appState.objectWillChange.send()
        showToast("Порядок изменён")
    }

    private func clearBar() {
        let alert = NSAlert()
        alert.messageText = "Очистить панель Bar?"
        alert.informativeText = "Все приложения будут убраны из панели. Сами программы останутся на месте."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Очистить")
        alert.addButton(withTitle: "Отмена")
        NSApp.activate()
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        withAnimation(animations.spring) {
            appState.barApps.removeAll()
        }
        appState.saveBarApps()
        appState.objectWillChange.send()
        showToast("Панель очищена")
    }

    private func remove(_ app: AppItem) {
        withAnimation(animations.spring) {
            appState.removeFromBar(app)
        }
        showToast("Убрано: \(app.name)")
    }

    private func reveal(_ app: AppItem) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: app.path)])
    }

    private func showAddAppWindow() {
        BarXWindowManager.shared.showWindow(
            id: "addToBar",
            title: "Добавить в панель Bar",
            size: CGSize(width: 500, height: 600),
            content: AddToBarView().environmentObject(appState)
        )
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

// MARK: - BarStatPill

struct BarStatPill: View {
    let value: Int
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10))
            VStack(alignment: .leading, spacing: 0) {
                Text("\(value)")
                    .font(.system(size: 12, weight: .semibold))
                Text(title)
                    .font(.system(size: 8))
                    .opacity(0.6)
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.08))
        )
        .adaptiveTextColor()
    }
}

// MARK: - BarPanelPreview

struct BarPanelPreview: View {
    let apps: [AppItem]
    let iconSize: Double
    let showNames: Bool
    let showIcons: Bool
    let isList: Bool
    let accent: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )

            if apps.isEmpty {
                Text("Панель пуста")
                    .font(.caption)
                    .adaptiveTextColor()
                    .opacity(0.4)
            } else if isList {
                VStack(spacing: 3) {
                    ForEach(Array(apps.prefix(4).enumerated()), id: \.element.id) { _, app in
                        HStack(spacing: 8) {
                            Image(systemName: app.icon)
                                .font(.system(size: 11))
                                .frame(width: 16)
                                .foregroundStyle(accent)
                            Text(app.name)
                                .font(.system(size: 11))
                                .adaptiveTextColor()
                                .lineLimit(1)
                            Spacer()
                        }
                        .padding(.horizontal, 10)
                    }
                }
                .padding(.vertical, 6)
            } else {
                HStack(spacing: 8) {
                    ForEach(apps.prefix(BarXSettings.maxBarAppsPerPage), id: \.id) { app in
                        VStack(spacing: 2) {
                            RoundedRectangle(cornerRadius: 7)
                                .fill(Color.white.opacity(0.1))
                                .frame(width: iconSize, height: iconSize)
                                .overlay(
                                    Image(systemName: app.icon)
                                        .font(.system(size: iconSize * 0.42))
                                        .foregroundStyle(showIcons ? .white : accent)
                                )
                            if showNames {
                                Text(app.name)
                                    .font(.system(size: 8))
                                    .adaptiveTextColor()
                                    .opacity(0.6)
                                    .lineLimit(1)
                                    .frame(width: iconSize + 8)
                            }
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, 10)
            }
        }
    }
}

// MARK: - BarAppRow

struct BarAppRow: View {
    let app: AppItem
    var showIcon: Bool = true
    var position: Int = 0
    var total: Int = 1
    /// Порядок меняется только вне поиска: при активном фильтре стрелки
    /// двигали элемент по индексу полного списка, а не по тому, что видит
    /// пользователь, — элемент уезжал не туда. В фильтре отключаем.
    var canReorder: Bool = true
    let isHovered: Bool
    let onLaunch: () -> Void
    let onRemove: () -> Void
    var onReveal: () -> Void = {}
    var onMoveUp: () -> Void = {}
    var onMoveDown: () -> Void = {}
    var onPin: () -> Void = {}

    @State private var appIcon: NSImage?
    @State private var isLaunching = false
    @AppStorage("barShowNames") private var showNames = false

    @StateObject private var animations = AnimationCenter.shared

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 7)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 32, height: 32)

                if showIcon, let appIcon {
                    Image(nsImage: appIcon)
                        .resizable()
                        .frame(width: 22, height: 22)
                } else {
                    Image(systemName: app.icon)
                        .font(.system(size: 14))
                        .adaptiveTextColor()
                }
            }
            .onAppear(perform: loadIcon)

            VStack(alignment: .leading, spacing: 1) {
                Text(app.name)
                    .font(.system(size: 12, weight: .medium))
                    .adaptiveTextColor()
                    .lineLimit(1)
                Text(app.path)
                    .font(.system(size: 10))
                    .adaptiveTextColor()
                    .opacity(0.45)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 4)

            HStack(spacing: 6) {
                Button(action: onMoveUp) {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 10, weight: .bold))
                        .adaptiveTextColor()
                        .opacity(canReorder && position > 0 ? 0.75 : 0.2)
                }
                .buttonStyle(.plain)
                .disabled(!canReorder || position == 0)
                .help("Выше")

                Button(action: onMoveDown) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .adaptiveTextColor()
                        .opacity(canReorder && position < total - 1 ? 0.75 : 0.2)
                }
                .buttonStyle(.plain)
                .disabled(!canReorder || position >= total - 1)
                .help("Ниже")

                if isHovered {
                    Button(action: onLaunch) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.green)
                    }
                    .buttonStyle(.plain)
                    .help("Запустить")

                    Button(action: onRemove) {
                        Image(systemName: "pin.slash.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.red.opacity(0.85))
                    }
                    .buttonStyle(.plain)
                    .help("Убрать из панели")
                    .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered ? Color.white.opacity(0.08) : Color.clear)
        )
        .scaleEffect(isLaunching ? 1.01 : 1.0)
        .contentShape(Rectangle())
        .onTapGesture(perform: onLaunch)
        .animation(animations.hover, value: isHovered)
        .contextMenu {
            Button("Запустить", action: onLaunch)
            Button("Показать в Finder", action: onReveal)
            Button("Закрепить в Launcher", action: onPin)
            Divider()
            Button("Убрать из панели", role: .destructive, action: onRemove)
        }
    }

    private func loadIcon() {
        guard showIcon, appIcon == nil else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            let icon = NSWorkspace.shared.icon(forFile: app.path)
            guard icon.size.width > 0 else { return }
            let resized = icon.resized(to: NSSize(width: 22, height: 22))
            DispatchQueue.main.async { appIcon = resized }
        }
    }
}
