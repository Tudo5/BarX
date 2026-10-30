//
//  HotkeyRecorder.swift
//  BarX
//
//  Поле записи горячей комбинации
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers
import Combine
import ServiceManagement
import UserNotifications
import ApplicationServices

// MARK: - HotkeyRecorder

struct HotkeyRecorder: View {
    @Binding var hotkey: String
    let onChanged: (String) -> Void
    @State private var isRecording = false
    @State private var hasConflict = false
    @State private var conflictMessage = ""
    /// Монитор событий нужно хранить, иначе его невозможно снять и он утекает.
    @State private var keyMonitor: Any?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button {
                if isRecording {
                    stopRecording()
                } else {
                    startRecording()
                }
            } label: {
                HStack(spacing: 8) {
                    if isRecording {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(.red)
                            .opacity(0.8)
                    }
                    
                    Text(isRecording ? "Нажмите новую комбинацию..." : hotkey)
                        .font(.system(.body, design: .monospaced))
                        .adaptiveTextColor()
                        .opacity(isRecording ? 0.7 : 0.9)
                }
                .frame(minWidth: 160)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            isRecording ? Color.white.opacity(0.15) : Color.white.opacity(0.08)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(
                                    isRecording ? Color.white.opacity(0.4) :
                                    hasConflict ? Color.red.opacity(0.5) : Color.white.opacity(0.1),
                                    lineWidth: isRecording ? 2 : 1
                                )
                        )
                )
            }
            .buttonStyle(.plain)
            .onAppear {
                setupKeyMonitor()
            }
            .onDisappear {
                removeKeyMonitor()
            }
            
            if hasConflict {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.yellow)
                    Text(conflictMessage)
                        .font(.caption)
                        .foregroundStyle(.yellow)
                        .opacity(0.8)
                }
                .padding(.leading, 4)
            }
        }
    }
    
    private func setupKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard isRecording else { return event }
            handleKeyEvent(event)
            return nil
        }
    }
    
    private func removeKeyMonitor() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }
    
    private func handleKeyEvent(_ event: NSEvent) {
        // Esc отменяет запись: раньше все клавиши глотались (return nil),
        // и пользователь оказывался запертым в состоянии «Нажмите комбинацию».
        if event.keyCode == 53 {
            hasConflict = false
            conflictMessage = ""
            stopRecording()
            return
        }
        
        let key = KeyCodeHelper.keyString(for: event.keyCode)
        var modifiers: [String] = []
        
        if event.modifierFlags.contains(.command) { modifiers.append("⌘") }
        if event.modifierFlags.contains(.option) { modifiers.append("⌥") }
        if event.modifierFlags.contains(.shift) { modifiers.append("⇧") }
        if event.modifierFlags.contains(.control) { modifiers.append("⌃") }
        
        // Нажата только модификаторная клавиша — ждём основную,
        // но подсказываем, что Esc выходит из режима записи.
        // Проверяем точное совпадение: `contains` на общей строке
        // сломал бы, например, букву "F" (входит в "Fn").
        let modifierKeys: Set<String> = ["⌘", "⌥", "⇧", "⌃", "Fn"]
        if key.isEmpty || modifierKeys.contains(key) {
            if !modifiers.isEmpty {
                hasConflict = false
                conflictMessage = "Esc — отмена"
            }
            return
        }
        
        guard !modifiers.isEmpty else { return }
        
        let hotkeyString = (modifiers + [key]).joined(separator: " ")
        let hotkeyManager = HotkeyManager.shared
        
        if hotkeyManager.checkConflicts(hotkeyString) || hotkeyManager.isSystemHotkey(hotkeyString) {
            hasConflict = true
            conflictMessage = "⚠️ Комбинация занята системой — попробуйте другую (Esc — отмена)"
            return
        }
        
        hasConflict = false
        conflictMessage = ""
        hotkey = hotkeyString
        onChanged(hotkeyString)
        stopRecording()
    }
    
    private func startRecording() {
        isRecording = true
        hasConflict = false
        conflictMessage = ""
        setupKeyMonitor()
    }
    
    private func stopRecording() {
        isRecording = false
        removeKeyMonitor()
        if hotkey.isEmpty {
            hotkey = "⌘⇧B"
            onChanged("⌘⇧B")
        }
    }
}
