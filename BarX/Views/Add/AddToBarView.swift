//
//  AddToBarView.swift
//  BarX
//
//  Добавление приложений в панель Bar: поиск, наглядный выбор
//  (полоса выбранных, счётчик, режим «только выбранные») и массовое добавление.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers
import Combine

// MARK: - AddToBarView

struct AddToBarView: View {
    @EnvironmentObject var appState: AppStateManager
    @StateObject private var themeManager = ThemeManager.shared

    @State private var searchText = ""
    @State private var hoveredAppId: UUID?
    @State private var appIcons: [UUID: NSImage] = [:]
    @State private var selectedApps: Set<UUID> = []
    @State private var onlySelected = false
    @State private var limitMessage: String?

    private let animations = AnimationCenter.shared

    /// Сколько приложений ещё можно добавить в панель.
    private var freeSlots: Int {
        max(0, BarXSettings.maxBarApps - appState.barApps.count)
    }

    var body: some View {
        ZStack {
            if let theme = themeManager.effectiveTheme {
                GradientBackground(theme: theme)
                    .ignoresSafeArea()
            }

            VStack(alignment: .leading, spacing: 12) {
                header
                Divider().background(Color.white.opacity(0.25))
                searchRow
                selectionSummary
                appsList
                Divider().background(Color.white.opacity(0.25))
                limitHint
                footerButtons
            }
            .padding(20)
            .frame(width: 540, height: 640)
        }
        .animation(animations.spring, value: selectedApps.count)
        .animation(animations.spring, value: onlySelected)
        .animation(animations.spring, value: limitMessage)
    }

    // MARK: - Сообщение о лимите

    @ViewBuilder
    private var limitHint: some View {
        if let limitMessage {
            SettingsHint(text: limitMessage, color: .red)
                .transition(.opacity)
        } else if freeSlots == 0 {
            SettingsHint(
                text: "Панель заполнена: максимум \(BarXSettings.maxBarApps) приложений. Уберите лишнее, чтобы добавить новое.",
                color: .orange
            )
        }
    }

    private func showLimitMessage() {
        limitMessage = "Больше \(BarXSettings.maxBarApps) приложений в панель не помещается — сначала уберите лишние."
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation(animations.hover) { limitMessage = nil }
        }
    }

    // MARK: - Заголовок

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Добавить в панель Bar")
                    .font(.title2.bold())
                    .adaptiveTextColor()
                Text("Отметьте приложения — они появятся в панели меню")
                    .font(.caption)
                    .adaptiveTextColor()
                    .opacity(0.6)
            }

            Spacer()

            Button {
                BarXWindowManager.shared.closeWindow(id: "addToBar")
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .adaptiveTextColor()
                    .opacity(0.7)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Поиск и режимы

    private var searchRow: some View {
        HStack(spacing: 8) {
            searchField
            selectAllButton
            onlySelectedButton
        }
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .adaptiveTextColor()
                .opacity(0.5)
            TextField("Поиск приложений…", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .adaptiveTextColor()
            if !searchText.isEmpty {
                Button {
                    withAnimation(animations.quick) { searchText = "" }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
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
    }

    private var selectAllButton: some View {
        Button {
            withAnimation(animations.quick) {
                let visible = availableApps
                if visible.allSatisfy({ selectedApps.contains($0.id) }) {
                    for app in visible { selectedApps.remove(app.id) }
                } else {
                    for app in visible where !selectedApps.contains(app.id) {
                        guard selectedApps.count < freeSlots else {
                            showLimitMessage()
                            break
                        }
                        selectedApps.insert(app.id)
                    }
                }
            }
        } label: {
            Text(allVisibleSelected ? "Снять видимые" : "Выбрать видимые")
                .font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 7).fill(Color.white.opacity(0.12)))
                .adaptiveTextColor()
        }
        .buttonStyle(.plain)
        .disabled(availableApps.isEmpty)
    }

    private var onlySelectedButton: some View {
        Button {
            withAnimation(animations.spring) { onlySelected.toggle() }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: onlySelected ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                Text("Выбранные")
            }
            .font(.system(size: 11, weight: .medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(onlySelected ? Color.green.opacity(0.3) : Color.white.opacity(0.12))
            )
            .adaptiveTextColor()
        }
        .buttonStyle(.plain)
        .disabled(selectedApps.isEmpty && !onlySelected)
        .help("Показать только отмеченные приложения")
    }

    // MARK: - Сводка по выбору

    private var selectionSummary: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: selectedApps.isEmpty ? "circle.dashed" : "checkmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(selectedApps.isEmpty ? Color.white.opacity(0.4) : .green)

                Text(selectedApps.isEmpty ? "Ничего не выбрано" : "Выбрано: \(selectedApps.count)")
                    .font(.system(size: 12, weight: .semibold))
                    .adaptiveTextColor()
                    .opacity(selectedApps.isEmpty ? 0.55 : 0.95)

                Spacer()

                if !selectedApps.isEmpty {
                    Button("Снять все") {
                        withAnimation(animations.spring) { selectedApps.removeAll() }
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundStyle(.red.opacity(0.8))
                }
            }

            if !selectedApps.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(selectedAppItems) { app in
                            SelectedAppChip(app: app, icon: appIcons[app.id]) {
                                withAnimation(animations.spring) {
                                    _ = selectedApps.remove(app.id)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
                .frame(height: 34)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 9)
                .fill(summaryFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 9)
                        .stroke(summaryStroke, lineWidth: 1)
                )
        )
    }

    private var summaryFill: Color {
        selectedApps.isEmpty ? Color.white.opacity(0.05) : Color.green.opacity(0.12)
    }

    private var summaryStroke: Color {
        selectedApps.isEmpty ? Color.white.opacity(0.08) : Color.green.opacity(0.35)
    }

    // MARK: - Список

    private var appsList: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                if availableApps.isEmpty {
                    emptyList
                } else {
                    ForEach(availableApps) { app in
                        row(for: app)
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .frame(maxHeight: .infinity)
    }

    private func row(for app: AppItem) -> some View {
        let isAlready = appState.isInBar(app)
        return AddToBarRow(
            app: app,
            isAlreadyAdded: isAlready,
            isSelected: selectedApps.contains(app.id),
            isHovered: hoveredAppId == app.id,
            icon: appIcons[app.id],
            onToggle: { toggleSelection(app) }
        )
        .onHover { hovering in
            hoveredAppId = hovering ? app.id : nil
            if hovering { NSCursor.pointingHand.set() }
        }
        .onAppear { loadIcon(for: app) }
    }

    /// Отметка приложения с учётом лимита панели.
    private func toggleSelection(_ app: AppItem) {
        guard !appState.isInBar(app) else { return }
        if selectedApps.contains(app.id) {
            withAnimation(animations.quick) { _ = selectedApps.remove(app.id) }
            return
        }
        guard selectedApps.count < freeSlots else {
            showLimitMessage()
            return
        }
        withAnimation(animations.quick) { _ = selectedApps.insert(app.id) }
    }

    private var emptyList: some View {
        VStack(spacing: 8) {
            Image(systemName: onlySelected ? "checkmark.circle" : "magnifyingglass")
                .font(.system(size: 26))
                .adaptiveTextColor()
                .opacity(0.4)
            Text(onlySelected ? "Выбранных приложений нет" : "Ничего не найдено")
                .font(.caption)
                .adaptiveTextColor()
                .opacity(0.6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .animatedAppear()
    }

    // MARK: - Кнопки

    private var footerButtons: some View {
        HStack {
            Button("Отмена") {
                BarXWindowManager.shared.closeWindow(id: "addToBar")
            }
            .buttonStyle(.bordered)
            .tint(.white)

            Spacer()

            Button {
                addSelected()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                    Text(selectedApps.isEmpty ? "Добавить" : "Добавить (\(selectedApps.count))")
                }
                .frame(minWidth: 130)
            }
            .buttonStyle(.borderedProminent)
            .tint(selectedApps.isEmpty ? Color.white.opacity(0.25) : .green)
            .disabled(selectedApps.isEmpty)
        }
    }

    // MARK: - Данные

    private var availableApps: [AppItem] {
        var apps = appState.installedApps
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty {
            apps = apps.filter {
                $0.name.localizedCaseInsensitiveContains(query) ||
                $0.path.localizedCaseInsensitiveContains(query)
            }
        }
        if onlySelected {
            apps = apps.filter { selectedApps.contains($0.id) }
        }
        return apps
    }

    private var selectedAppItems: [AppItem] {
        appState.installedApps.filter { selectedApps.contains($0.id) }
    }

    private var allVisibleSelected: Bool {
        let visible = availableApps
        return !visible.isEmpty && visible.allSatisfy { selectedApps.contains($0.id) }
    }

    private func addSelected() {
        var blocked = 0
        for id in selectedApps {
            guard let app = appState.installedApps.first(where: { $0.id == id }) else { continue }
            if !appState.addToBar(app) { blocked += 1 }
        }
        selectedApps.removeAll()

        if blocked > 0 {
            showLimitMessage()
        } else {
            BarXWindowManager.shared.closeWindow(id: "addToBar")
        }
    }

    private func loadIcon(for app: AppItem) {
        guard appIcons[app.id] == nil else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            let icon = NSWorkspace.shared.icon(forFile: app.path)
            guard icon.size.width > 0 else { return }
            let resized = icon.resized(to: NSSize(width: 26, height: 26))
            DispatchQueue.main.async { appIcons[app.id] = resized }
        }
    }
}

// MARK: - SelectedAppChip

struct SelectedAppChip: View {
    let app: AppItem
    let icon: NSImage?
    let onRemove: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 5) {
            if let icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 16, height: 16)
            } else {
                Image(systemName: app.icon)
                    .font(.system(size: 11))
                    .adaptiveTextColor()
            }

            Text(app.name)
                .font(.system(size: 11))
                .adaptiveTextColor()
                .lineLimit(1)
                .frame(maxWidth: 110)

            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 10))
                .adaptiveTextColor()
                .opacity(isHovered ? 0.9 : 0.45)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color.white.opacity(isHovered ? 0.22 : 0.14))
        )
        .overlay(
            Capsule()
                .stroke(Color.green.opacity(0.5), lineWidth: 1)
        )
        .onHover { hovering in
            withAnimation(AnimationCenter.shared.quick) { isHovered = hovering }
            if hovering { NSCursor.pointingHand.set() }
        }
        .onTapGesture(perform: onRemove)
        .help("Убрать из выбранных: \(app.name)")
    }
}

// MARK: - AddToBarRow

struct AddToBarRow: View {
    let app: AppItem
    let isAlreadyAdded: Bool
    let isSelected: Bool
    let isHovered: Bool
    let icon: NSImage?
    let onToggle: () -> Void

    private let animations = AnimationCenter.shared

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 11) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 34, height: 34)
                    if let icon {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 25, height: 25)
                    } else {
                        Image(systemName: app.icon)
                            .font(.system(size: 15))
                            .adaptiveTextColor()
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(app.name)
                            .font(.system(size: 13, weight: .medium))
                            .adaptiveTextColor()
                            .lineLimit(1)
                        if isAlreadyAdded {
                            Text("уже в панели")
                                .font(.system(size: 9, weight: .medium))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Capsule().fill(Color.blue.opacity(0.35)))
                                .adaptiveTextColor()
                        }
                    }
                    Text(app.path)
                        .font(.system(size: 10))
                        .adaptiveTextColor()
                        .opacity(0.4)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer(minLength: 6)

                if isAlreadyAdded {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(.blue.opacity(0.8))
                } else {
                    Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                        .font(.system(size: 16))
                        .foregroundStyle(isSelected ? .green : .white.opacity(isHovered ? 0.7 : 0.35))
                        .scaleEffect(isSelected ? 1.08 : 1.0)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        isSelected ? Color.green.opacity(0.16) :
                        (isHovered && !isAlreadyAdded ? Color.white.opacity(0.07) : Color.clear)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.green.opacity(0.45) : Color.clear, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isAlreadyAdded)
        .animation(animations.quick, value: isSelected)
        .animation(animations.quick, value: isHovered)
    }
}
