//
//  AddFolderView.swift
//  BarX
//
//  Создание папки с выбором иконки
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers
import Combine
import ServiceManagement
import UserNotifications
import ApplicationServices

// MARK: - AddFolderView

struct AddFolderView: View {
    let onAdded: () -> Void
    @EnvironmentObject var appState: AppStateManager
    @FocusState private var isNameFieldFocused: Bool
    @State private var folderName = ""
    @State private var selectedIcon = "folder"
    @StateObject private var themeManager = ThemeManager.shared
    
    
    
    
    var body: some View {
        ZStack {
            if let theme = themeManager.effectiveTheme {
                GradientBackground(theme: theme)
                    .ignoresSafeArea()
            }
            
            VStack(alignment: .leading, spacing: 16) {
                Text("Новая папка")
                    .font(.title2.bold())
                    .adaptiveTextColor()
                
                Divider()
                    .background(Color.white.opacity(0.3))
                
                // Название
                VStack(alignment: .leading, spacing: 6) {
                    Text("Название")
                        .font(.headline)
                        .adaptiveTextColor()
                    TextField("Введите название", text: $folderName)
                        .textFieldStyle(.roundedBorder)
                        .focused($isNameFieldFocused)
                        .onSubmit {
                            createFolder()
                        }
                }
                
                // Выбор значка: категории, поиск и одна вертикальная сетка
                VStack(alignment: .leading, spacing: 6) {
                    Text("Значок папки")
                        .font(.headline)
                        .adaptiveTextColor()

                    IconPickerView(
                        categories: IconCatalog.categories,
                        selectedIcon: $selectedIcon,
                        gridHeight: 200
                    )
                }

                
                Spacer()
                
                HStack {
                    Button("Отмена") {
                        BarXWindowManager.shared.closeWindow(id: "addFolder")
                    }
                    .buttonStyle(.bordered)
                    .tint(.white)
                    
                    Spacer()
                    
                    Button("Создать") {
                        createFolder()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.white)
                    .disabled(
                        folderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )
                }
            }
            .padding(24)
            .frame(width: 560, height: 560)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    isNameFieldFocused = true
                }
            }
        }
    }
    
    private func createFolder() {
        let name = folderName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let newPreset = Preset(name: name, icon: selectedIcon)
        appState.addPreset(newPreset)
        onAdded()
        BarXWindowManager.shared.closeWindow(id: "addFolder")
    }
}
