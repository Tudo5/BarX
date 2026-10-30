//
//  SettingsWindow.swift
//  BarX
//
//  Окно настроек, сайдбар и контент
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers
import Combine
import ServiceManagement
import UserNotifications
import ApplicationServices

// MARK: - SettingsWindow

struct SettingsWindow: View {
    @EnvironmentObject var appState: AppStateManager
    @State private var selectedCategory: SettingsCategory = .general
    @State private var isHoveringMainMenu = false
    @State private var hoveredCategory: SettingsCategory?
    @State private var searchText = ""
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var launcherManager = LauncherManager.shared
    
    private var filteredCategories: [SettingsCategory] {
        if searchText.isEmpty {
            return SettingsCategory.allCases
        }
        return SettingsCategory.allCases.filter {
            $0.rawValue.localizedCaseInsensitiveContains(searchText) ||
            $0.keywords.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        ZStack {
            if let theme = themeManager.effectiveTheme {
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
                        .id(selectedCategory)
                        .transition(AnimationCenter.shared.sectionTransition)
                    }
                    .animation(AnimationCenter.shared.standard, value: selectedCategory)
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

// MARK: - SettingsSidebar

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
            guard selectedCategory != category else { return }
            withAnimation(AnimationCenter.shared.standard) {
                selectedCategory = category
            }
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

// MARK: - SettingsContent

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
            case .animations:
                AnimationSettingsView()
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
