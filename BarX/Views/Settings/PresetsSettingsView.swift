//
//  PresetsSettingsView.swift
//  BarX
//
//  Раздел «Папки»: карточки папок с поиском, переименованием и
//  дублированием, панель элементов с быстрыми действиями.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers
import Combine

// MARK: - PresetsSettingsView

struct PresetsSettingsView: View {
    let onSave: () -> Void

    @EnvironmentObject var appState: AppStateManager
    @AppStorage("appearanceCardRadius") private var cardRadius: Double = 10

    @State private var selectedPresetId: UUID?
    @State private var hoveredPresetId: UUID?
    @State private var hoveredItemId: UUID?
    @State private var searchText = ""
    @State private var renamingId: UUID?
    @State private var renameText = ""
    @State private var toast: String?

    private let animations = AnimationCenter.shared

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            if appState.presets.isEmpty {
                emptyState
            } else {
                HStack(alignment: .top, spacing: 14) {
                    foldersPane
                    Divider().background(Color.white.opacity(0.2))
                    itemsPane
                }
                .frame(maxHeight: .infinity)
            }
            if let toast {
                SettingsHint(text: toast, color: .green)
                    .transition(.opacity)
            }
        }
        .padding(.vertical, 4)
        .animation(animations.quick, value: toast)
        .animation(animations.layout, value: appState.presets.count)
        .onAppear {
            if selectedPresetId == nil {
                selectedPresetId = appState.presets.first?.id
            }
        }
    }

    // MARK: - Шапка

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Папки")
                    .font(.headline)
                    .adaptiveTextColor()
                Text("Наборы приложений, файлов и ссылок внутри меню BarX")
                    .font(.caption)
                    .adaptiveTextColor()
                    .opacity(0.6)
            }

            Spacer()

            HStack(spacing: 10) {
                statPill(value: appState.presets.count, title: "папок", icon: "folder")
                statPill(value: totalItems, title: "элементов", icon: "square.stack.3d.up")
            }

            Button {
                openAddFolder()
            } label: {
                Label("Новая папка", systemImage: "folder.badge.plus")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.borderedProminent)
            .tint(.white)
            .controlSize(.small)
        }
    }

    private func statPill(value: Int, title: String, icon: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text("\(value)")
                .font(.system(size: 12, weight: .semibold))
            Text(title)
                .font(.system(size: 9))
                .opacity(0.6)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.08)))
        .adaptiveTextColor()
    }

    private var totalItems: Int {
        appState.presets.reduce(0) { $0 + $1.items.count }
    }

    // MARK: - Левая панель: папки

    private var foldersPane: some View {
        VStack(alignment: .leading, spacing: 8) {
            searchField

            if filteredPresets.isEmpty {
                SettingsHint(text: "Папок по запросу не найдено.")
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(filteredPresets) { preset in
                            folderCard(preset)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .frame(width: 250)
            }
        }
        .frame(width: 250)
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .adaptiveTextColor()
                .opacity(0.5)
            TextField("Поиск папок…", text: $searchText)
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
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 7).fill(Color.white.opacity(0.08)))
    }

    private func folderCard(_ preset: Preset) -> some View {
        let isSelected = selectedPresetId == preset.id
        let isHovered = hoveredPresetId == preset.id
        let accent = Color(hex: BarXSettings.appearanceAccent)

        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 9) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9)
                        .fill(
                            LinearGradient(
                                colors: [accent.opacity(0.55), accent.opacity(0.25)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 36, height: 36)
                    Image(systemName: preset.icon)
                        .font(.system(size: 16))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 1) {
                    if renamingId == preset.id {
                        TextField("Название", text: $renameText)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13, weight: .semibold))
                            .adaptiveTextColor()
                            .onSubmit { commitRename(preset) }
                    } else {
                        Text(preset.name)
                            .font(.system(size: 13, weight: .semibold))
                            .adaptiveTextColor()
                            .lineLimit(1)
                    }
                    Text("\(preset.items.count) элем.")
                        .font(.system(size: 10))
                        .adaptiveTextColor()
                        .opacity(0.55)
                }

                Spacer(minLength: 0)

                if renamingId == preset.id {
                    Button {
                        commitRename(preset)
                    } label: {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.green)
                    }
                    .buttonStyle(.plain)
                }
            }

            if isSelected || isHovered {
                HStack(spacing: 10) {
                    cardAction("pencil", "Переименовать") { startRename(preset) }
                    cardAction("plus.square.on.square", "Дублировать") { duplicate(preset) }
                    cardAction("chevron.up", "Выше") { move(preset, by: -1) }
                    cardAction("chevron.down", "Ниже") { move(preset, by: 1) }
                    Spacer()
                    cardAction("trash", "Удалить", tint: .red) { delete(preset) }
                }
                .transition(.opacity)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: cardRadius)
                .fill(isSelected ? Color.white.opacity(0.16) : Color.white.opacity(isHovered ? 0.1 : 0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: cardRadius)
                        .stroke(
                            isSelected ? accent.opacity(0.7) : Color.white.opacity(0.08),
                            lineWidth: isSelected ? 1.5 : 1
                        )
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(animations.quick) { selectedPresetId = preset.id }
        }
        .onHover { hovering in
            withAnimation(animations.quick) { hoveredPresetId = hovering ? preset.id : nil }
        }
        .contextMenu {
            Button("Переименовать") { startRename(preset) }
            Button("Дублировать") { duplicate(preset) }
            Divider()
            Button("Удалить папку", role: .destructive) { delete(preset) }
        }
    }

    private func cardAction(_ icon: String, _ help: String, tint: Color = .white, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(tint)
                .opacity(tint == .red ? 0.85 : 0.75)
        }
        .buttonStyle(.plain)
        .help(help)
    }

    // MARK: - Правая панель: элементы

    private var itemsPane: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let preset = selectedPreset {
                HStack(spacing: 8) {
                    Image(systemName: preset.icon)
                        .font(.system(size: 12))
                        .adaptiveTextColor()
                    Text(preset.name)
                        .font(.system(size: 13, weight: .semibold))
                        .adaptiveTextColor()
                        .lineLimit(1)

                    Spacer()

                    Button {
                        openAddItem(to: preset)
                    } label: {
                        Label("Элемент", systemImage: "plus.circle.fill")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    .tint(.white)
                    .controlSize(.small)
                }

                if preset.items.isEmpty {
                    emptyItems
                } else {
                    ScrollView {
                        LazyVStack(spacing: 4) {
                            ForEach(Array(preset.items.enumerated()), id: \.element.id) { index, item in
                                itemRow(item, in: preset, index: index)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "hand.point.left")
                        .font(.system(size: 26))
                        .adaptiveTextColor()
                        .opacity(0.4)
                    Text("Выберите папку слева")
                        .font(.caption)
                        .adaptiveTextColor()
                        .opacity(0.6)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.vertical, 50)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 4)
    }

    private var emptyItems: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray")
                .font(.system(size: 28))
                .adaptiveTextColor()
                .opacity(0.4)
            Text("В папке пока нет элементов")
                .font(.caption)
                .adaptiveTextColor()
                .opacity(0.6)
            Text("Добавьте приложение, файл или ссылку")
                .font(.system(size: 10))
                .adaptiveTextColor()
                .opacity(0.4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .animatedAppear()
    }

    private func itemRow(_ item: AppItem, in preset: Preset, index: Int) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 7)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 30, height: 30)
                ItemIconView(item: item, size: 18)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(item.name)
                    .font(.system(size: 12, weight: .medium))
                    .adaptiveTextColor()
                    .lineLimit(1)
                Text(item.path)
                    .font(.system(size: 10))
                    .adaptiveTextColor()
                    .opacity(0.45)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 4)

            HStack(spacing: 7) {
                Button {
                    open(item)
                } label: {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(.green)
                }
                .buttonStyle(.plain)
                .help("Открыть")

                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: item.path)])
                } label: {
                    Image(systemName: "folder")
                        .font(.system(size: 12))
                        .adaptiveTextColor()
                        .opacity(0.7)
                }
                .buttonStyle(.plain)
                .help("Показать в Finder")

                Button {
                    moveItem(item, in: preset, by: -1)
                } label: {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 9, weight: .bold))
                        .adaptiveTextColor()
                        .opacity(index > 0 ? 0.7 : 0.2)
                }
                .buttonStyle(.plain)
                .disabled(index == 0)

                Button {
                    moveItem(item, in: preset, by: 1)
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                        .adaptiveTextColor()
                        .opacity(index < preset.items.count - 1 ? 0.7 : 0.2)
                }
                .buttonStyle(.plain)
                .disabled(index >= preset.items.count - 1)

                Button {
                    removeItem(item, from: preset)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundStyle(.red.opacity(0.75))
                }
                .buttonStyle(.plain)
                .help("Удалить из папки")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(hoveredItemId == item.id ? Color.white.opacity(0.08) : Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(animations.quick) { hoveredItemId = hovering ? item.id : nil }
        }
        .contextMenu {
            Button("Открыть") { open(item) }
            Button("Показать в Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: item.path)])
            }
            Divider()
            Button("Удалить из папки", role: .destructive) { removeItem(item, from: preset) }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 40))
                .adaptiveTextColor()
                .opacity(0.45)
            Text("Папок пока нет")
                .font(.headline)
                .adaptiveTextColor()
                .opacity(0.75)
            Text("Папка — это набор приложений, файлов и ссылок, который открывается из меню BarX")
                .font(.caption)
                .adaptiveTextColor()
                .opacity(0.5)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)
            Button {
                openAddFolder()
            } label: {
                Label("Создать папку", systemImage: "folder.badge.plus")
            }
            .buttonStyle(.borderedProminent)
            .tint(.white)
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .animatedAppear()
    }

    // MARK: - Данные

    private var filteredPresets: [Preset] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return appState.presets }
        return appState.presets.filter {
            $0.name.localizedCaseInsensitiveContains(query) ||
            $0.items.contains { $0.name.localizedCaseInsensitiveContains(query) }
        }
    }

    private var selectedPreset: Preset? {
        guard let id = selectedPresetId else { return appState.presets.first }
        return appState.presets.first { $0.id == id } ?? appState.presets.first
    }

    // MARK: - Операции с папками

    private func startRename(_ preset: Preset) {
        renameText = preset.name
        renamingId = preset.id
    }

    private func commitRename(_ preset: Preset) {
        let name = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        renamingId = nil
        guard !name.isEmpty,
              let index = appState.presets.firstIndex(where: { $0.id == preset.id }),
              appState.presets[index].name != name else { return }
        appState.presets[index].name = name
        appState.savePresets()
        onSave()
        showToast("Переименовано: \(name)")
    }

    private func duplicate(_ preset: Preset) {
        guard let index = appState.presets.firstIndex(where: { $0.id == preset.id }) else { return }
        var copy = preset
        copy.id = UUID()
        copy.name = uniqueName(basedOn: preset.name)
        copy.items = preset.items.map { item in
            var newItem = item
            newItem.id = UUID()
            return newItem
        }
        appState.presets.insert(copy, at: index + 1)
        appState.savePresets()
        onSave()
        withAnimation(animations.layout) { selectedPresetId = copy.id }
        showToast("Создана копия: \(copy.name)")
    }

    private func uniqueName(basedOn name: String) -> String {
        let existing = Set(appState.presets.map { $0.name })
        var candidate = "\(name) (копия)"
        var counter = 2
        while existing.contains(candidate) {
            candidate = "\(name) (копия \(counter))"
            counter += 1
        }
        return candidate
    }

    private func move(_ preset: Preset, by offset: Int) {
        guard let index = appState.presets.firstIndex(where: { $0.id == preset.id }) else { return }
        let target = index + offset
        guard appState.presets.indices.contains(target) else { return }
        withAnimation(animations.layout) {
            appState.presets.swapAt(index, target)
        }
        appState.savePresets()
        onSave()
    }

    private func delete(_ preset: Preset) {
        let alert = NSAlert()
        alert.messageText = "Удалить папку «\(preset.name)»?"
        alert.informativeText = "Все \(preset.items.count) элементов внутри будут удалены."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Удалить")
        alert.addButton(withTitle: "Отмена")
        NSApp.activate()
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        BarXWindowManager.shared.closeWindow(id: "items-\(preset.id.uuidString)")
        withAnimation(animations.layout) {
            appState.removePreset(preset)
            if selectedPresetId == preset.id {
                selectedPresetId = appState.presets.first?.id
            }
        }
        onSave()
        showToast("Папка удалена")
    }

    // MARK: - Операции с элементами

    private func moveItem(_ item: AppItem, in preset: Preset, by offset: Int) {
        guard let presetIndex = appState.presets.firstIndex(where: { $0.id == preset.id }),
              let itemIndex = appState.presets[presetIndex].items.firstIndex(where: { $0.id == item.id }) else { return }
        let target = itemIndex + offset
        guard appState.presets[presetIndex].items.indices.contains(target) else { return }
        withAnimation(animations.layout) {
            appState.presets[presetIndex].items.swapAt(itemIndex, target)
        }
        appState.savePresets()
        onSave()
    }

    private func removeItem(_ item: AppItem, from preset: Preset) {
        guard let presetIndex = appState.presets.firstIndex(where: { $0.id == preset.id }),
              let itemIndex = appState.presets[presetIndex].items.firstIndex(where: { $0.id == item.id }) else { return }
        withAnimation(animations.layout) {
            _ = appState.presets[presetIndex].items.remove(at: itemIndex)
        }
        appState.savePresets()
        onSave()
        showToast("Элемент удалён")
    }

    private func open(_ item: AppItem) {
        // Единая точка исполнения — все типы, включая действия.
        let outcome = ActionExecutor.execute(item)
        if case .failure(let reason) = outcome {
            DispatchQueue.main.async {
                ActionExecutor.presentError(reason, item: item)
            }
        }
    }

    // MARK: - Окна

    private func openAddFolder() {
        BarXWindowManager.shared.showWindow(
            id: "addFolder",
            title: "Новая папка",
            size: CGSize(width: 600, height: 600),
            content: AddFolderView(
                onAdded: {
                    appState.savePresets()
                    onSave()
                    selectedPresetId = appState.presets.last?.id
                }
            )
            .environmentObject(appState)
        )
    }

    private func openAddItem(to preset: Preset) {
        BarXWindowManager.shared.showWindow(
            id: "addItem",
            title: "Добавить элемент",
            // Размер берём из самого вида — иначе окно и кадр разъезжаются
            // и по краям остаются щели (было окно 540×660 при кадре 500×620).
            size: AddItemView.windowSize,
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

    private func showToast(_ message: String) {
        withAnimation(animations.quick) { toast = message }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(animations.quick) {
                if toast == message { toast = nil }
            }
        }
    }
}
