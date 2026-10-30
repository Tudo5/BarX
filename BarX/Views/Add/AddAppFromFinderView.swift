//
//  AddAppFromFinderView.swift
//  BarX
//
//  Добавление приложения из Finder
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers
import Combine
import ServiceManagement
import UserNotifications
import ApplicationServices

// MARK: - AddAppFromFinderView

struct AddAppFromFinderView: View {
    let onAppAdded: (AppItem) -> Void
    let onCancel: () -> Void
    @EnvironmentObject var appState: AppStateManager
    
    @State private var selectedURL: URL?
    @State private var appName = ""
    @State private var appPath = ""
    @State private var isDragging = false
    @State private var showingFilePicker = false
    @StateObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        ZStack {
            if let theme = themeManager.effectiveTheme {
                GradientBackground(theme: theme)
                    .ignoresSafeArea()
            }
            
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Добавить приложение")
                        .font(.title2.bold())
                        .adaptiveTextColor()
                    
                    Spacer()
                    
                    Button {
                        onCancel()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .adaptiveTextColor()
                            .opacity(0.7)
                    }
                    .buttonStyle(.plain)
                }
                
                Divider()
                    .background(Color.white.opacity(0.3))
                
                VStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isDragging ? Color.white : Color.white.opacity(0.3),
                                style: StrokeStyle(lineWidth: isDragging ? 3 : 2, dash: [6, 4])
                            )
                            .fill(
                                isDragging ? Color.white.opacity(0.08) : Color.clear
                            )
                            .frame(height: 120)
                        
                        VStack(spacing: 12) {
                            Image(systemName: "app.dashed")
                                .font(.system(size: 36))
                                .adaptiveTextColor()
                                .opacity(0.5)
                            
                            Text("Перетащите приложение сюда")
                                .font(.headline)
                                .adaptiveTextColor()
                                .opacity(0.7)
                            
                            Text("или")
                                .font(.caption)
                                .adaptiveTextColor()
                                .opacity(0.5)
                            
                            Button("Выбрать в Finder") {
                                showingFilePicker = true
                            }
                            .buttonStyle(.bordered)
                            .tint(.white)
                            .controlSize(.small)
                        }
                    }
                    .onDrop(of: [.fileURL], isTargeted: $isDragging) { providers in
                        _ = handleDrop(providers: providers)
                        return true
                    }
                }
                
                if selectedURL != nil {
                    VStack(alignment: .leading, spacing: 12) {
                        Divider()
                            .background(Color.white.opacity(0.3))
                        
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Приложение выбрано:")
                                .adaptiveTextColor()
                            Text(appName)
                                .font(.headline)
                                .adaptiveTextColor()
                        }
                    }
                }
                
                Spacer()
                
                HStack {
                    Button("Отмена") {
                        onCancel()
                    }
                    .buttonStyle(.bordered)
                    .tint(.white)
                    
                    Spacer()
                    
                    Button("Добавить") {
                        addApp()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.white)
                    .disabled(selectedURL == nil)
                }
            }
            .padding(24)
            .frame(width: 500, height: 600)
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: [.application]
            ) { result in
                switch result {
                case .success(let url):
                    processSelectedURL(url)
                case .failure(let error):
                    Log.error("Ошибка выбора файла: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { (item, error) in
                if let data = item as? Data,
                   let url = URL(dataRepresentation: data, relativeTo: nil) {
                    DispatchQueue.main.async {
                        processSelectedURL(url)
                    }
                }
            }
        }
        return true
    }
    
    private func processSelectedURL(_ url: URL) {
        if url.pathExtension == "app" {
            selectedURL = url
            appName = url.deletingPathExtension().lastPathComponent
            appPath = url.path
        } else {
            let alert = NSAlert()
            alert.messageText = "Неверный файл"
            alert.informativeText = "Пожалуйста, выберите файл приложения (.app)"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
    
    private func addApp() {
        guard selectedURL != nil else { return }
        
        let app = AppItem(
            name: appName,
            path: appPath,
            icon: "app.fill",
            preset: "Все приложения",
            type: .application
        )
        
        onAppAdded(app)
    }
}
