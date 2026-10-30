//
//  LauncherWindowView.swift
//  BarX
//
//  Окно Launcher: поиск, список результатов, панель сведений и подсказки.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers
import Combine

// MARK: - LauncherWindowView

struct LauncherWindowView: View {
    @EnvironmentObject var launcherManager: LauncherManager
    @EnvironmentObject var appState: AppStateManager
    @EnvironmentObject var themeManager: ThemeManager

    @AppStorage("launcherShowDetails") private var showDetails = true
    @AppStorage("launcherMaxResults") private var maxResults = 40
    @AppStorage("appearanceCardRadius") private var cardRadius: Double = 10

    @FocusState private var isFocused: Bool
    @State private var windowHeight: CGFloat = 80
    @State private var hoveredId: UUID?

    @StateObject private var animations = AnimationCenter.shared

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                searchBar
                Divider()
                    .opacity(0.25)
                    .background(Color.white.opacity(0.3))

                if launcherManager.filteredApps.isEmpty {
                    emptyState
                } else {
                    HStack(spacing: 0) {
                        resultsList
                        if showDetails, let selected = selectedApp {
                            Divider()
                                .opacity(0.25)
                                .background(Color.white.opacity(0.3))
                            LauncherDetailsPanel(app: selected) { app in
                                LauncherManager.shared.launchApp(app)
                                launcherManager.hideLauncher()
                            }
                            .frame(width: 190)
                            .transition(animations.slideTransition)
                        }
                    }
                }

                Divider()
                    .opacity(0.25)
                    .background(Color.white.opacity(0.3))
                footerHints
            }
        }
        .frame(width: max(320, launcherManager.windowWidth), height: windowHeight)
        .animation(animations.spring, value: launcherManager.filteredApps.count)
        .animation(animations.spring, value: launcherManager.selectedIndex)
        .animation(animations.spring, value: showDetails)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isFocused = true
            }
            updateWindowHeight()
        }
    }

    // MARK: - Фон

    private var background: some View {
        ZStack {
            if let theme = themeManager.effectiveTheme {
                GradientBackground(theme: theme)
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.35), radius: 22, x: 0, y: 12)
            }
        }
    }

    // MARK: - Поиск

    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16))
                .adaptiveTextColor()
                .opacity(0.6)

            TextField("Поиск приложений…", text: $launcherManager.searchText)
                .textFieldStyle(.plain)
                .adaptiveTextColor()
                .font(.system(size: 17))
                .focused($isFocused)
                .onChange(of: launcherManager.searchText) { _, _ in
                    launcherManager.updateFilteredApps()
                    updateWindowHeight()
                }

            if !launcherManager.searchText.isEmpty {
                Button {
                    withAnimation(animations.spring) { launcherManager.searchText = "" }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .adaptiveTextColor()
                        .opacity(0.5)
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }

            Text(KeyCodeHelper.normalizeHotkey(launcherManager.launcherHotkeyKey))
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .adaptiveTextColor()
                .opacity(0.45)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(RoundedRectangle(cornerRadius: 5).fill(Color.white.opacity(0.08)))

            Button {
                launcherManager.closeLauncher()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 15))
                    .adaptiveTextColor()
                    .opacity(0.5)
            }
            .buttonStyle(.plain)
            .help("Закрыть Launcher")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Результаты

    private var resultsList: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 2) {
                    ForEach(Array(launcherManager.filteredApps.enumerated()), id: \.element.id) { index, app in
                        LauncherAppRow(
                            app: app,
                            isSelected: index == launcherManager.selectedIndex,
                            showsDetails: showDetails,
                            onTap: {
                                launcherManager.selectedIndex = index
                                launcherManager.executeSelected()
                            },
                            onPin: {
                                appState.togglePinApp(app)
                            }
                        )
                        .id(app.id)
                        .onHover { hovering in
                            if hovering {
                                launcherManager.selectedIndex = index
                                hoveredId = app.id
                            } else if hoveredId == app.id {
                                hoveredId = nil
                            }
                        }
                    }
                }
                .padding(.vertical, 5)
                .padding(.horizontal, 5)
            }
            .onChange(of: launcherManager.selectedIndex) { _, newValue in
                guard launcherManager.filteredApps.indices.contains(newValue) else { return }
                withAnimation(animations.hover) {
                    proxy.scrollTo(launcherManager.filteredApps[newValue].id, anchor: .center)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: launcherManager.searchText.isEmpty ? "sparkles" : "magnifyingglass")
                .font(.system(size: 26))
                .adaptiveTextColor()
                .opacity(0.4)
            Text(launcherManager.searchText.isEmpty
                 ? "Начните вводить название приложения"
                 : "Ничего не найдено")
                .font(.system(size: 13))
                .adaptiveTextColor()
                .opacity(0.65)
            if launcherManager.searchText.isEmpty {
                Text("Показаны закреплённые, панель Bar и недавние")
                    .font(.system(size: 10))
                    .adaptiveTextColor()
                    .opacity(0.4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
        .animatedAppear()
    }

    private var footerHints: some View {
        HStack(spacing: 12) {
            hint(icon: "arrow.up.arrow.down", text: "выбор")
            hint(icon: "return", text: "запустить")
            hint(icon: "escape", text: "закрыть")
            Spacer()
            Text("\(launcherManager.filteredApps.count) из \(min(appState.installedApps.count, maxResults))")
                .font(.system(size: 9))
                .adaptiveTextColor()
                .opacity(0.35)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
    }

    private func hint(icon: String, text: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 9))
            Text(text)
                .font(.system(size: 9))
        }
        .adaptiveTextColor()
        .opacity(0.4)
    }

    // MARK: - Служебное

    private var selectedApp: AppItem? {
        guard launcherManager.filteredApps.indices.contains(launcherManager.selectedIndex) else { return nil }
        return launcherManager.filteredApps[launcherManager.selectedIndex]
    }

    private static let rowHeight: CGFloat = 46
    private static let headerHeight: CGFloat = 58
    private static let footerHeight: CGFloat = 26
    private static let listMaxHeight: CGFloat = 300

    private func updateWindowHeight() {
        let count = launcherManager.filteredApps.count
        guard count > 0 else {
            windowHeight = Self.headerHeight + Self.footerHeight + 90
            return
        }
        let listHeight = min(CGFloat(count) * Self.rowHeight + 10, Self.listMaxHeight)
        windowHeight = Self.headerHeight + listHeight + Self.footerHeight
    }
}

// MARK: - LauncherAppRow

struct LauncherAppRow: View {
    let app: AppItem
    let isSelected: Bool
    var showsDetails: Bool = true
    let onTap: () -> Void
    var onPin: () -> Void = {}

    @EnvironmentObject var appState: AppStateManager
    @State private var appIcon: NSImage?
    @AppStorage("showAppIcons") private var showAppIcons = true

    @StateObject private var animations = AnimationCenter.shared

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 11) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 30, height: 30)

                    if showAppIcons, let appIcon {
                        Image(nsImage: appIcon)
                            .resizable()
                            .frame(width: 23, height: 23)
                    } else {
                        Image(systemName: app.icon)
                            .font(.system(size: 14))
                            .adaptiveTextColor()
                    }
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(app.name)
                        .font(.system(size: 13, weight: .medium))
                        .adaptiveTextColor()
                        .lineLimit(1)

                    if !showsDetails {
                        Text(app.path)
                            .font(.system(size: 10))
                            .adaptiveTextColor()
                            .opacity(0.45)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }

                Spacer(minLength: 4)

                if appState.isInBar(app) {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.blue.opacity(0.8))
                }

                if appState.isPinned(app) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.yellow.opacity(0.9))
                }

                Image(systemName: "return")
                    .font(.system(size: 10))
                    .adaptiveTextColor()
                    .opacity(isSelected ? 0.7 : 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.white.opacity(0.16) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.white.opacity(0.3) : Color.clear, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(animations.hover, value: isSelected)
        .onAppear {
            guard showAppIcons, appIcon == nil else { return }
            DispatchQueue.global(qos: .userInitiated).async {
                let icon = NSWorkspace.shared.icon(forFile: app.path)
                guard icon.size.width > 0 else { return }
                let resized = icon.resized(to: NSSize(width: 23, height: 23))
                DispatchQueue.main.async { appIcon = resized }
            }
        }
        .contextMenu {
            Button("Запустить", action: onTap)
            Button("Закрепить в Launcher", action: onPin)
            Button("Показать в Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: app.path)])
            }
        }
    }
}

// MARK: - LauncherDetailsPanel

struct LauncherDetailsPanel: View {
    let app: AppItem
    let onLaunch: (AppItem) -> Void

    @EnvironmentObject var appState: AppStateManager
    @State private var appIcon: NSImage?
    @State private var folderSize: String = "…"

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Spacer()
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 54, height: 54)
                    if let appIcon {
                        Image(nsImage: appIcon)
                            .resizable()
                            .frame(width: 42, height: 42)
                    } else {
                        Image(systemName: app.icon)
                            .font(.system(size: 24))
                            .adaptiveTextColor()
                    }
                }
                Spacer()
            }

            Text(app.name)
                .font(.system(size: 12, weight: .semibold))
                .adaptiveTextColor()
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 5) {
                detailRow(icon: "internaldrive", label: folderSize)
                detailRow(icon: "pin", label: appState.isInBar(app) ? "в панели Bar" : "не в панели")
                detailRow(icon: "star", label: appState.isPinned(app) ? "закреплено" : "не закреплено")
                if let last = app.lastLaunched {
                    detailRow(icon: "clock", label: last.formatted(date: .abbreviated, time: .shortened))
                }
            }

            Spacer(minLength: 0)

            Button {
                onLaunch(app)
            } label: {
                Label("Запустить", systemImage: "play.fill")
                    .font(.system(size: 11, weight: .medium))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.white)

            Button {
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: app.path)])
            } label: {
                Label("В Finder", systemImage: "folder")
                    .font(.system(size: 10))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.white)
            .controlSize(.small)
        }
        .padding(12)
        .onAppear {
            loadIcon()
            loadSize()
        }
    }

    private func detailRow(icon: String, label: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .opacity(0.6)
            Text(label)
                .font(.system(size: 10))
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .adaptiveTextColor()
        .opacity(0.75)
    }

    private func loadIcon() {
        guard appIcon == nil else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            let icon = NSWorkspace.shared.icon(forFile: app.path)
            guard icon.size.width > 0 else { return }
            let resized = icon.resized(to: NSSize(width: 42, height: 42))
            DispatchQueue.main.async { appIcon = resized }
        }
    }

    private func loadSize() {
        let path = app.path
        DispatchQueue.global(qos: .utility).async {
            var text = "размер неизвестен"
            if let attributes = try? FileManager.default.attributesOfItem(atPath: path),
               let bytes = (attributes[.size] as? NSNumber)?.int64Value {
                text = ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
            }
            DispatchQueue.main.async { folderSize = text }
        }
    }
}
