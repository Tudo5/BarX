//
//  FoldersAndItems.swift
//  BarX
//
//  Папки и список их элементов
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers
import Combine
import ServiceManagement
import UserNotifications
import ApplicationServices

// MARK: - FolderRow

struct FolderRow: View {
    let preset: Preset
    let isHovered: Bool
    var showItemCount: Bool = true
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
                if showItemCount && !preset.items.isEmpty {
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

// MARK: - ItemsListView

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
            if let theme = themeManager.effectiveTheme {
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
                    if item.type.isSection {
                        // Заголовок-разделитель: группирует элементы, не запускается.
                        sectionHeader(item)
                    } else {
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
            }
            .padding(8)
        }
    }

    /// Заголовок раздела: подпись + тонкая линия справа.
    private func sectionHeader(_ item: AppItem) -> some View {
        HStack(spacing: 8) {
            Text(item.name)
                .font(.system(size: 11, weight: .semibold))
                .adaptiveTextColor()
                .opacity(0.7)
                .lineLimit(1)
            Rectangle()
                .fill(Color.white.opacity(0.18))
                .frame(height: 1)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
    }
    
    private func openItem(_ item: AppItem) {
        // Единая точка исполнения — все типы, включая действия.
        let outcome = ActionExecutor.execute(item)
        if case .failure(let reason) = outcome {
            DispatchQueue.main.async {
                ActionExecutor.presentError(reason, item: item)
            }
        }
    }
}

// MARK: - ItemRow

struct ItemRow: View {
    let item: AppItem
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ItemIconView(item: item, size: 20)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.body)
                        .adaptiveTextColor()
                    
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
