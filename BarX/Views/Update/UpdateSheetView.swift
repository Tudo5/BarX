//
//  UpdateSheetView.swift
//  BarX
//
//  Окно обновления
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers
import Combine
import ServiceManagement
import UserNotifications
import ApplicationServices

// MARK: - UpdateSheetView

struct UpdateSheetView: View {
    @Environment(\.dismiss) var dismiss
    let version: String
    let changes: [String]
    let onUpdate: () -> Void
    @State private var isDownloading = false
    @State private var downloadProgress = 0.0
    @State private var downloadTimer: Timer?
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Text("Доступно обновление")
                    .font(.title2.bold())
                    .adaptiveTextColor()
                
                Text("BarX \(version)")
                    .font(.headline)
                    .adaptiveTextColor()
                    .opacity(0.8)
                
                Divider()
                    .background(Color.white.opacity(0.3))
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Что нового:")
                        .font(.subheadline)
                        .adaptiveTextColor()
                        .opacity(0.7)
                    
                    ForEach(changes, id: \.self) { change in
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.green)
                            Text(change)
                                .font(.caption)
                                .adaptiveTextColor()
                                .opacity(0.8)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                
                if isDownloading {
                    VStack(spacing: 8) {
                        ProgressView(value: downloadProgress, total: 1.0)
                            .progressViewStyle(LinearProgressViewStyle())
                            .tint(.blue)
                            .frame(width: 200)
                        
                        Text("Загрузка... \(Int(downloadProgress * 100))%")
                            .font(.caption)
                            .adaptiveTextColor()
                            .opacity(0.6)
                    }
                }
                
                HStack(spacing: 12) {
                    Button("Позже") {
                        downloadTimer?.invalidate()
                        downloadTimer = nil
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    .tint(.white)
                    .disabled(isDownloading)
                    
                    Button("Обновить") {
                        if !isDownloading {
                            startDownload()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .disabled(isDownloading)
                }
            }
            .padding(32)
            .frame(width: 400)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.gray.opacity(0.15))
                    .background(.ultraThinMaterial)
            )
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        .onDisappear {
            downloadTimer?.invalidate()
            downloadTimer = nil
        }
    }
    
    private func startDownload() {
        isDownloading = true
        downloadProgress = 0
        
        downloadTimer?.invalidate()
        downloadTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            downloadProgress += 0.02
            if downloadProgress >= 1.0 {
                timer.invalidate()
                downloadTimer = nil
                isDownloading = false
                onUpdate()
                dismiss()
            }
        }
    }
}


        
