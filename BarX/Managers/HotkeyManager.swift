//
//  HotkeyManager.swift
//  BarX
//
//  Глобальная горячая клавиша.
//
//  ## Почему переделано
//
//  Раньше «регистрация» сводилась к записи строки в UserDefaults и флагу
//  `isRegistered = true`, а реально работал `NSEvent.addGlobalMonitorForEvents`.
//  У такого подхода три фундаментальных недостатка:
//
//  1. Монитор только НАБЛЮДАЕТ события и не может их перехватить — нажатие
//     комбинации уходило в активное приложение (печать буквы в тексте,
//     срабатывание шорткатов чужого приложения).
//  2. Монитору обязателен доступ «Универсальный доступ»; без него он молча
//     не работает, и пользователь видит «горячая клавиша не нажимается».
//  3. Монитор не видит события, когда системный меню-бар активен иначе
//     ожидается, и хуже работает в полноэкранных приложениях.
//
//  Теперь используется Carbon `RegisterEventHotKey` — тот же механизм,
//  что у Spotlight, Raycast и Alfred. Он перехватывает нажатие у системы,
//  не требует «Универсального доступа» и работает из любого приложения.
//

import SwiftUI
import AppKit
import Combine
import Carbon.HIToolbox

// MARK: - HotkeyManager

final class HotkeyManager: ObservableObject {
    static let shared = HotkeyManager()
    
    @Published var isRegistered = false
    @Published var currentHotkey: String = "⌘ ⇧ B"
    @Published var availableHotkeys: [String] = []
    @Published var conflicts: [String] = []
    
    @AppStorage("launcherHotkeyKey") var launcherHotkeyKey: String = "⌘ ⇧ B"
    
    /// Вызывается при срабатывании комбинации. Назначает LauncherManager.
    var onHotkeyPressed: (() -> Void)?
    
    // Carbon-дескрипторы. Референсы обязаны удерживаться, иначе обработчик
    // будет собран сборщиком мусора и горячая клавиша «отвалится».
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private let hotKeyID = EventHotKeyID(signature: OSType(0x42725842), id: 1) // 'BrXB'
    
    private init() {
        currentHotkey = KeyCodeHelper.normalizeHotkey(launcherHotkeyKey)
    }
    
    deinit {
        unregister()
    }
    
    // MARK: - Регистрация
    
    /// Регистрирует комбинацию в системе. Возвращает `false`, если она
    /// занята системой или непригодна к использованию.
    @discardableResult
    func registerHotkey(_ hotkey: String) -> Bool {
        conflicts.removeAll()
        let normalized = KeyCodeHelper.normalizeHotkey(hotkey)
        
        if checkConflicts(normalized) || isSystemHotkey(normalized) {
            if !conflicts.contains(normalized) { conflicts.append(normalized) }
            return false
        }
        
        let (modifiers, key) = KeyCodeHelper.parseHotkey(normalized)
        guard !key.isEmpty, !modifiers.isEmpty else { return false }
        
        // Приводим к кодам Carbon. Если клавиша неизвестна — отклоняем,
        // иначе зарегистрированная комбинация молча не сработала бы.
        guard let keyCode = Self.carbonKeyCode(for: key) else {
            Log.warning("Неизвестная клавиша в комбинации: \(key)")
            return false
        }
        let carbonModifiers = Self.carbonModifiers(from: modifiers)
        
        // Сначала снимаем предыдущую регистрацию: иначе при смене комбинации
        // в системе осталась бы старая и работали бы обе.
        unregister()
        installHandler()
        
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            keyCode,
            carbonModifiers,
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &ref
        )
        
        guard status == noErr, let ref else {
            // Комбинация уже занята другим приложением
            Log.warning("Комбинация \(normalized) занята другим приложением (status \(status))")
            if !conflicts.contains(normalized) { conflicts.append(normalized) }
            isRegistered = false
            return false
        }
        
        hotKeyRef = ref
        currentHotkey = normalized
        launcherHotkeyKey = normalized
        isRegistered = true
        Log.info("Горячая клавиша зарегистрирована: \(normalized)")
        return true
    }
    
    /// Снимает регистрацию и удаляет обработчик.
    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }
        isRegistered = false
    }
    
    /// Ставит Carbon-обработчик один раз.
    private func installHandler() {
        guard eventHandlerRef == nil else { return }
        
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        
        // C-回调 не может захватить `self` напрямую, поэтому кладём
        // ссылку на менеджер в User-данные и достаём их в обработчике.
        let userData = Unmanaged.passUnretained(self).toOpaque()
        
        let status = InstallEventHandler(
            GetEventDispatcherTarget(),
            { _, event, userData in
                guard let event, let userData else { return OSStatus(eventNotHandledErr) }
                
                // FourCharCode 'hkid' (typeHotKeyID). Константа из CarbonCore
                // не видна при выборочном импорте Carbon.HIToolbox, поэтому
                // задаём значение явно.
                let typeHotKeyID = OSType(0x686B6964)
                
                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                guard status == noErr else { return OSStatus(eventNotHandledErr) }
                
                // Приём происходит на отдельном потоке Carbon —
                // в UI можно выходить только через главный.
                let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                DispatchQueue.main.async {
                    manager.handleHotKeyPressed()
                }
                return noErr
            },
            1,
            &eventType,
            userData,
            &eventHandlerRef
        )
        
        if status != noErr {
            Log.error("Не удалось установить обработчик горячей клавиши (status \(status))")
        }
    }
    
    private func handleHotKeyPressed() {
        guard isRegistered else { return }
        Log.debug("Нажата горячая клавиша \(currentHotkey)")
        onHotkeyPressed?()
    }
    
    // MARK: - Таблицы клавиш
    
    /// Символ клавиши → виртуальный код Carbon (ANSI-раскладка).
    private static let keyCodeMap: [String: UInt32] = [
        // Буквы
        "A": 0, "S": 1, "D": 2, "F": 3, "H": 4, "G": 5, "Z": 6, "X": 7,
        "C": 8, "V": 9, "B": 11, "Q": 12, "W": 13, "E": 14, "R": 15,
        "Y": 16, "T": 17, "O": 31, "U": 32, "I": 34, "P": 35, "L": 37,
        "J": 38, "K": 40, "N": 45, "M": 46,
        // Цифры
        "1": 18, "2": 19, "3": 20, "4": 21, "5": 23, "6": 22,
        "7": 26, "8": 28, "9": 25, "0": 29,
        // Знаки препинания
        "=": 24, "-": 27, "]": 30, "[": 33, "'": 39, ";": 41,
        "\\": 42, ",": 43, "/": 44, ".": 47, "`": 50,
        // Прочие
        "Space": 49, "Tab": 48, "Return": 36, "Enter": 36,
        // Функциональные
        "F1": 122, "F2": 120, "F3": 99, "F4": 118, "F5": 96, "F6": 97,
        "F7": 98, "F8": 100, "F9": 101, "F10": 109, "F11": 103, "F12": 111,
        "F13": 105, "F14": 107, "F15": 113, "F16": 106, "F17": 64,
        "F18": 79, "F19": 80, "F20": 90,
        // Стрелки
        "←": 123, "→": 124, "↓": 125, "↑": 126
    ]
    
    static func carbonKeyCode(for key: String) -> UInt32? {
        keyCodeMap[key.uppercased().count == 1 ? key.uppercased() : key]
    }
    
    /// Флаги `NSEvent.ModifierFlags` → битовая маска Carbon.
    static func carbonModifiers(from modifiers: NSEvent.ModifierFlags) -> UInt32 {
        var result: UInt32 = 0
        if modifiers.contains(.command) { result |= UInt32(cmdKey) }
        if modifiers.contains(.shift) { result |= UInt32(shiftKey) }
        if modifiers.contains(.option) { result |= UInt32(optionKey) }
        if modifiers.contains(.control) { result |= UInt32(controlKey) }
        return result
    }
    
    // MARK: - Проверки
    
    /// Комбинация непригодна: нет клавиши или нет модификаторов.
    /// Пустой модификатор означал бы, что одна буква открывает Launcher
    /// во всей системе.
    func checkConflicts(_ hotkey: String) -> Bool {
        let normalized = KeyCodeHelper.normalizeHotkey(hotkey)
        let (_, key) = KeyCodeHelper.parseHotkey(normalized)
        return key.isEmpty || KeyCodeHelper.parseHotkey(normalized).0.isEmpty
    }
    
    /// Комбинации, занятые самой macOS. По ним RegisterEventHotKey
    /// вернёт ошибку либо перехват их невозможен.
    func isSystemHotkey(_ hotkey: String) -> Bool {
        let normalized = KeyCodeHelper.normalizeHotkey(hotkey)
        let systemHotkeys: Set<String> = [
            "⌘ Space", "⌃ Space", "⌘ ⇧ Space", "⌘ ⌥ Space", "⌃ ⌥ Space",
            "⌘ Tab", "⌘ ⇧ Tab", "⌘ `", "⌘ ⇧ `",
            "⌘ Q", "⌘ W", "⌘ H", "⌘ M", "⌘ ⇧ 3", "⌘ ⇧ 4", "⌘ ⇧ 5",
            "⌃ ⌘ Q", "⌃ ⇧ ⌘ 3", "⌃ ⇧ ⌘ 4"
        ]
        return systemHotkeys.contains(normalized)
    }
    
    /// Вызывается при выключении Launcher.
    func cleanup() {
        unregister()
        conflicts.removeAll()
    }
}
