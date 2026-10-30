//
//  BarPanelView.swift
//  BarX
//
//  Панель Bar в главном меню: два стиля отображения, размеры и анимации.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers
import Combine

// MARK: - BarPanelView

struct BarPanelView: View {
    @EnvironmentObject var appState: AppStateManager

    /// Поисковый запрос из главного меню — фильтрует приложения панели.
    var query: String = ""

    @AppStorage("barAppsPerPage") private var appsPerPage = 5
    @AppStorage("barIconSize") private var iconSize: Double = 36
    @AppStorage("barShowNames") private var showNames = false
    @AppStorage("barShowCounter") private var showCounter = true
    @AppStorage("barPanelStyle") private var panelStyle = "icons"
    @AppStorage("showAppIcons") private var showAppIcons = true
    @AppStorage("hideMenuAfterLaunch") private var hideMenuAfterLaunch = true

    @State private var page = 0
    @State private var hoveredId: UUID?
    @State private var launchingId: UUID?
    @State private var removingId: UUID?

    private let launcherManager = LauncherManager.shared
    @StateObject private var animations = AnimationCenter.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header

            if appState.barApps.isEmpty {
                emptyState
            } else if visibleApps.isEmpty {
                noResultsState
            } else if isListStyle {
                listBody
            } else {
                iconsBody
            }
        }
        .padding(.vertical, 8)
        .onReceive(NotificationCenter.default.publisher(for: .barItemsDidChange)) { _ in
            clampPage()
        }
        .onChange(of: appsPerPage) { _, _ in
            page = 0
        }
        .onChange(of: query) { _, _ in
            page = 0
        }
        .onAppear { installKeyMonitor() }
        .onDisappear { removeKeyMonitor() }
    }

    // MARK: Клавиатурная навигация цифрами

    @State private var keyMonitor: Any?

    /// Цифры 1…N на видимой странице панели запускают соответствующий элемент.
    /// Монитор ставим, пока панель на экране (главное меню открыто), и снимаем
    /// при исчезновении — иначе он живёт всю сессию и ловит клавиши впустую.
    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Фокус в текстовом поле (поиск, переименование) — цифры печатаются туда.
            if NSApp.keyWindow?.firstResponder is NSTextView {
                return event
            }
            // Только чистая цифра, без модификаторов (иначе это Command+1 и т.п.).
            guard event.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty,
                  let chars = event.charactersIgnoringModifiers,
                  chars.count == 1,
                  let digit = Int(chars),
                  digit >= 1 else {
                return event
            }
            // 1-based номер в пределах текущей страницы.
            guard pageApps.indices.contains(digit - 1) else { return event }
            let app = pageApps[digit - 1]
            launch(app)
            return nil
        }
    }

    private func removeKeyMonitor() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }

    /// Приложения панели с учётом поиска.
    private var visibleApps: [AppItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return appState.barApps }
        return appState.barApps.filter { $0.name.localizedCaseInsensitiveContains(trimmed) }
    }

    private var noResultsState: some View {
        VStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 20))
                .adaptiveTextColor()
                .opacity(0.4)
            Text("В панели ничего не найдено")
                .font(.caption)
                .adaptiveTextColor()
                .opacity(0.55)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .animatedAppear()
    }

    // MARK: Заголовок

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "pin.fill")
                .font(.system(size: 9, weight: .bold))
                .adaptiveTextColor()
                .opacity(0.45)

            Text("ПАНЕЛЬ BAR")
                .font(.system(size: 10, weight: .semibold))
                .adaptiveTextColor()
                .opacity(0.5)

            if showCounter {
                Text("\(appState.barApps.count)")
                    .font(.system(size: 9, weight: .semibold))
                    .adaptiveTextColor()
                    .opacity(0.75)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(Color.white.opacity(0.12)))
                    .transition(.scale.combined(with: .opacity))
            }

            Spacer()

            // Переключатель стиля прямо из меню
            Button {
                withAnimation(animations.spring) {
                    panelStyle = isListStyle ? "icons" : "list"
                }
            } label: {
                Image(systemName: isListStyle ? "square.grid.2x2" : "list.bullet")
                    .font(.system(size: 11, weight: .semibold))
                    .adaptiveTextColor()
                    .opacity(0.6)
            }
            .buttonStyle(.plain)
            .help(isListStyle ? "Показать значками" : "Показать списком")

            Button {
                openAddToBar()
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 12))
                    .adaptiveTextColor()
                    .opacity(0.65)
            }
            .buttonStyle(.plain)
            .help("Добавить приложение в панель")
        }
        .padding(.horizontal, 12)
        .animation(animations.hover, value: appState.barApps.count)
    }

    // MARK: Стиль «значки»

    private var iconsBody: some View {
        VStack(spacing: 6) {
            HStack(spacing: 2) {
                if needsPagination {
                    pageButton(systemName: "chevron.left", enabled: page > 0) {
                        withAnimation(animations.spring) { page -= 1 }
                    }
                }

                iconsContent

                if needsPagination {
                    pageButton(systemName: "chevron.right", enabled: page < totalPages - 1) {
                        withAnimation(animations.spring) { page += 1 }
                    }
                }
            }
            .padding(.horizontal, 8)

            if needsPagination {
                HStack(spacing: 4) {
                    ForEach(0..<totalPages, id: \.self) { index in
                        Capsule()
                            .fill(index == page ? Color.white.opacity(0.85) : Color.white.opacity(0.2))
                            .frame(width: index == page ? 12 : 5, height: 5)
                            .onTapGesture {
                                withAnimation(animations.spring) { page = index }
                            }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 2)
                .animation(animations.spring, value: page)
            }
        }
    }

    /// Ряд значков: сколько бы их ни было, он всегда по центру свободного места.
    /// Если ряд всё-таки не помещается — включается горизонтальное листание.
    private var iconsContent: some View {
        GeometryReader { geo in
            if iconsContentWidth <= geo.size.width {
                iconsRow
                    .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    iconsRow
                }
            }
        }
        .frame(height: iconRowHeight)
    }

    private var iconsRow: some View {
        HStack(spacing: 8) {
            ForEach(Array(pageApps.enumerated()), id: \.element.id) { index, app in
                BarPanelIcon(
                    app: app,
                    size: effectiveIconSize,
                    showName: showNames,
                    showIcon: showAppIcons,
                    keyNumber: index + 1,
                    isHovered: hoveredId == app.id,
                    isLaunching: launchingId == app.id,
                    isRemoving: removingId == app.id,
                    onLaunch: { launch(app) },
                    onRemove: { remove(app) },
                    onReveal: { reveal(app) }
                )
                .onHover { hovering in
                    hoveredId = hovering ? app.id : nil
                }
                .animatedAppear(delay: Double(index) * 0.02)
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
    }

    // MARK: Стиль «список»

    private var listBody: some View {
        VStack(spacing: 2) {
            ForEach(Array(pageApps.enumerated()), id: \.element.id) { index, app in
                BarPanelRow(
                    app: app,
                    showIcon: showAppIcons,
                    keyNumber: index + 1,
                    isHovered: hoveredId == app.id,
                    isLaunching: launchingId == app.id,
                    onLaunch: { launch(app) },
                    onRemove: { remove(app) },
                    onReveal: { reveal(app) }
                )
                .onHover { hovering in
                    hoveredId = hovering ? app.id : nil
                }
                .animatedAppear(delay: Double(index) * 0.02)
            }

            if needsPagination {
                paginationFooter
            }
        }
        .padding(.horizontal, 8)
    }

    private var paginationFooter: some View {
        HStack(spacing: 10) {
            pageButton(systemName: "chevron.left", enabled: page > 0) {
                withAnimation(animations.spring) { page -= 1 }
            }
            Text("\(page + 1) / \(totalPages)")
                .font(.system(size: 10, weight: .medium))
                .adaptiveTextColor()
                .opacity(0.6)
            pageButton(systemName: "chevron.right", enabled: page < totalPages - 1) {
                withAnimation(animations.spring) { page += 1 }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    private func pageButton(systemName: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 22, height: 34)
                .adaptiveTextColor()
                .opacity(enabled ? 0.85 : 0.2)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .hoverLift(enabled)
    }

    // MARK: Пустое состояние

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "pin.slash")
                .font(.system(size: 22))
                .adaptiveTextColor()
                .opacity(0.35)
            Text("Нет приложений в панели")
                .font(.caption)
                .adaptiveTextColor()
                .opacity(0.55)
            Button("Добавить приложение") {
                openAddToBar()
            }
            .buttonStyle(.plain)
            .font(.caption)
            .adaptiveTextColor()
            .opacity(0.8)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.white.opacity(0.12)))
            .hoverLift()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .animatedAppear()
    }

    // MARK: Логика

    private var isListStyle: Bool { panelStyle == "list" }

    /// Приложений в строке (на страницу): не больше максимума строки панели
    /// (старые значения тоже обрезаем).
    private var pageLimit: Int {
        max(1, min(appsPerPage, BarXSettings.maxBarAppsPerPage))
    }

    /// Размер значка с учётом предела, при котором ряд помещается по центру.
    private var effectiveIconSize: Double {
        min(iconSize, BarXSettings.maxBarIconSize(perPage: pageLimit, showNames: showNames))
    }

    /// Ширина одного элемента ряда (см. `BarPanelIcon`).
    private var iconItemWidth: CGFloat {
        let size = CGFloat(effectiveIconSize)
        return showNames ? max(size + 14, 44) : size + 8
    }

    /// Ширина ряда текущей страницы вместе с внутренними отступами.
    private var iconsContentWidth: CGFloat {
        guard !pageApps.isEmpty else { return 0 }
        return CGFloat(pageApps.count) * iconItemWidth
            + CGFloat(pageApps.count - 1) * 8
            + 8
    }

    private var pageApps: [AppItem] {
        let start = page * pageLimit
        let end = min(start + pageLimit, visibleApps.count)
        guard start < end else { return [] }
        return Array(visibleApps[start..<end])
    }

    private var totalPages: Int {
        let count = visibleApps.count
        guard count > 0 else { return 1 }
        return Int(ceil(Double(count) / Double(pageLimit)))
    }

    private var needsPagination: Bool { visibleApps.count > pageLimit }

    private var iconRowHeight: CGFloat {
        CGFloat(effectiveIconSize) + (showNames ? 26 : 12)
    }

    private func clampPage() {
        if page >= totalPages { page = max(0, totalPages - 1) }
    }

    private func openAddToBar() {
        BarXWindowManager.shared.showWindow(
            id: "addToBar",
            title: "Добавить в панель Bar",
            size: CGSize(width: 500, height: 600),
            content: AddToBarView().environmentObject(appState)
        )
    }

    private func launch(_ app: AppItem) {
        launchingId = app.id
        launcherManager.launchApp(app)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(animations.quick) { launchingId = nil }
        }
        if hideMenuAfterLaunch {
            BarXWindowManager.shared.dismissMenuPresentations()
        }
    }

    private func remove(_ app: AppItem) {
        // Убираем сразу, анимация только подсвечивает исчезновение
        removingId = app.id
        withAnimation(animations.quick) {
            appState.removeFromBar(app)
            removingId = nil
        }
    }

    private func reveal(_ app: AppItem) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: app.path)])
    }
}

// MARK: - BarPanelIcon

struct BarPanelIcon: View {
    let app: AppItem
    let size: Double
    let showName: Bool
    let showIcon: Bool
    /// 1-based номер элемента на текущей странице — подсказка для цифровой
    /// навигации (клавиша запускает элемент с этим номером).
    let keyNumber: Int
    let isHovered: Bool
    let isLaunching: Bool
    let isRemoving: Bool
    let onLaunch: () -> Void
    let onRemove: () -> Void
    let onReveal: () -> Void

    @State private var appIcon: NSImage?
    @State private var isLoadingIcon = false

    @StateObject private var animations = AnimationCenter.shared

    var body: some View {
        VStack(spacing: 3) {
            ZStack(alignment: .topTrailing) {
                Button(action: onLaunch) {
                    ZStack {
                        RoundedRectangle(cornerRadius: size * 0.22)
                            .fill(Color.white.opacity(isHovered ? 0.14 : 0.08))
                            .frame(width: size, height: size)
                            .overlay(
                                RoundedRectangle(cornerRadius: size * 0.22)
                                    .stroke(
                                        isLaunching ? Color.green.opacity(0.8) :
                                        (isHovered ? Color.white.opacity(0.35) : Color.white.opacity(0.1)),
                                        lineWidth: isHovered || isLaunching ? 1.5 : 1
                                    )
                            )
                            .shadow(color: .black.opacity(isHovered ? 0.3 : 0.15), radius: isHovered ? 6 : 2, x: 0, y: 2)

                        if showIcon, let icon = appIcon {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: size * 0.62, height: size * 0.62)
                                .scaleEffect(isLaunching ? 1.15 : 1.0)
                        } else {
                            Image(systemName: app.icon)
                                .font(.system(size: size * 0.42))
                                .adaptiveTextColor()
                                .scaleEffect(isLaunching ? 1.15 : 1.0)
                        }
                    }
                }
                .buttonStyle(.plain)
                .help(app.name)
                .overlay(alignment: .topLeading) { keyBadge }
                .onAppear {
                    if showIcon { loadIcon() }
                }

                if isHovered {
                    Button(action: onRemove) {
                        Image(systemName: "xmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 14, height: 14)
                            .background(Circle().fill(Color.red.opacity(0.85)))
                    }
                    .buttonStyle(.plain)
                    .offset(x: 5, y: -5)
                    .transition(.scale.combined(with: .opacity))
                    .help("Убрать из панели")
                }
            }
            .frame(width: size + 8, height: size + 6)

            if showName {
                Text(app.name)
                    .font(.system(size: 9))
                    .adaptiveTextColor()
                    .opacity(isHovered ? 0.95 : 0.6)
                    .lineLimit(1)
                    .frame(width: max(size + 14, 44))
                    .transition(.opacity)
            }
        }
        .scaleEffect(isRemoving ? 0.85 : 1.0)
        .opacity(isRemoving ? 0 : 1)
        .animation(animations.hover, value: isHovered)
        .animation(animations.bouncy, value: isLaunching)
        .animation(animations.spring, value: showName)
        .contextMenu {
            Button("Запустить", action: onLaunch)
            Button("Показать в Finder", action: onReveal)
            Divider()
            Button("Убрать из панели", role: .destructive, action: onRemove)
        }
    }

    /// Цифровой бейдж — какая клавиша запускает этот элемент.
    private var keyBadge: some View {
        Text("\(keyNumber)")
            .font(.system(size: 8, weight: .bold))
            .foregroundStyle(.white)
            .frame(minWidth: 13, minHeight: 13)
            .padding(.horizontal, 3)
            .background(Capsule().fill(Color.black.opacity(0.6)))
            .overlay(Capsule().stroke(Color.white.opacity(0.25), lineWidth: 0.5))
            .offset(x: -3, y: -3)
            .opacity(isHovered ? 0 : 0.85)
            .animation(animations.hover, value: isHovered)
    }

    private func loadIcon() {
        guard !isLoadingIcon, appIcon == nil else { return }
        isLoadingIcon = true
        DispatchQueue.global(qos: .userInitiated).async {
            let icon = NSWorkspace.shared.icon(forFile: app.path)
            guard icon.size.width > 0 else {
                DispatchQueue.main.async { isLoadingIcon = false }
                return
            }
            let target = NSSize(width: size * 0.62, height: size * 0.62)
            let resized = icon.resized(to: target)
            DispatchQueue.main.async {
                appIcon = resized
                isLoadingIcon = false
            }
        }
    }
}

// MARK: - BarPanelRow

struct BarPanelRow: View {
    let app: AppItem
    let showIcon: Bool
    /// 1-based номер элемента на текущей странице (подсказка для клавиш 1…N).
    let keyNumber: Int
    let isHovered: Bool
    let isLaunching: Bool
    let onLaunch: () -> Void
    let onRemove: () -> Void
    let onReveal: () -> Void

    @State private var appIcon: NSImage?

    @StateObject private var animations = AnimationCenter.shared

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 26, height: 26)

                if showIcon, let icon = appIcon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 18, height: 18)
                } else {
                    Image(systemName: app.icon)
                        .font(.system(size: 12))
                        .adaptiveTextColor()
                }
            }
            .overlay(alignment: .topLeading) {
                Text("\(keyNumber)")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(minWidth: 11, minHeight: 11)
                    .padding(.horizontal, 2)
                    .background(Capsule().fill(Color.black.opacity(0.6)))
                    .offset(x: -3, y: -3)
                    .opacity(isHovered ? 0 : 0.85)
                    .animation(animations.hover, value: isHovered)
            }
            .onAppear {
                guard showIcon, appIcon == nil else { return }
                DispatchQueue.global(qos: .userInitiated).async {
                    let icon = NSWorkspace.shared.icon(forFile: app.path)
                    guard icon.size.width > 0 else { return }
                    let resized = icon.resized(to: NSSize(width: 18, height: 18))
                    DispatchQueue.main.async { appIcon = resized }
                }
            }

            Text(app.name)
                .font(.system(size: 12))
                .adaptiveTextColor()
                .lineLimit(1)

            Spacer(minLength: 4)

            if isHovered {
                Button(action: onLaunch) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.green)
                }
                .buttonStyle(.plain)
                .help("Запустить")

                Button(action: onRemove) {
                    Image(systemName: "pin.slash.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.red.opacity(0.8))
                }
                .buttonStyle(.plain)
                .help("Убрать из панели")
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(isHovered ? Color.white.opacity(0.08) : Color.clear)
        )
        .scaleEffect(isLaunching ? 1.02 : 1.0)
        .contentShape(Rectangle())
        .onTapGesture(perform: onLaunch)
        .animation(animations.hover, value: isHovered)
        .animation(animations.bouncy, value: isLaunching)
        .contextMenu {
            Button("Запустить", action: onLaunch)
            Button("Показать в Finder", action: onReveal)
            Divider()
            Button("Убрать из панели", role: .destructive, action: onRemove)
        }
    }
}
