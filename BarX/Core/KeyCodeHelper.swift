//
//  KeyCodeHelper.swift
//  BarX
//
//  Таблица клавиш и разбор горячих комбинаций
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers
import Combine
import ServiceManagement
import UserNotifications
import ApplicationServices

// MARK: - KeyCodeHelper

struct KeyCodeHelper {
    static func keyString(for keyCode: UInt16) -> String {
        switch keyCode {
        case 0: return "A"
        case 1: return "S"
        case 2: return "D"
        case 3: return "F"
        case 4: return "H"
        case 5: return "G"
        case 6: return "Z"
        case 7: return "X"
        case 8: return "C"
        case 9: return "V"
        case 11: return "B"
        case 12: return "Q"
        case 13: return "W"
        case 14: return "E"
        case 15: return "R"
        case 16: return "Y"
        case 17: return "T"
        case 18: return "1"
        case 19: return "2"
        case 20: return "3"
        case 21: return "4"
        case 22: return "6"
        case 23: return "5"
        case 24: return "="
        case 25: return "9"
        case 26: return "7"
        case 27: return "-"
        case 28: return "8"
        case 29: return "0"
        case 30: return "]"
        case 31: return "O"
        case 32: return "U"
        case 33: return "["
        case 34: return "I"
        case 35: return "P"
        case 37: return "L"
        case 38: return "J"
        case 39: return "'"
        case 40: return "K"
        case 41: return ";"
        case 42: return "\\"
        case 43: return ","
        case 44: return "/"
        case 45: return "N"
        case 46: return "M"
        case 47: return "."
        case 48: return "Tab"
        case 49: return "Space"
        case 50: return "`"
        case 51: return "Delete"
        case 36: return "Return"
        case 52: return "Enter"
        case 76: return "Enter"          // keypad Enter
        case 53: return "Escape"
        // Модификаторы. Каждому физическому keycode соответствует СВОЯ клавиша:
        // раньше 61 (Right ⌥) и 62 (Right ⌃) ошибочно возвращали "⇧",
        // а 54 (Right ⌘) отсутствовал вовсе — из-за этого комбинации
        // с правым модификатором не записывались и не срабатывали.
        case 54: return "⌘"          // Right Command
        case 55: return "⌘"          // Left Command
        case 56: return "⇧"          // Left Shift
        case 57: return "Caps"
        case 58: return "⌥"          // Left Option
        case 59: return "⌃"          // Left Control
        case 60: return "⇧"          // Right Shift
        case 61: return "⌥"          // Right Option
        case 62: return "⌃"          // Right Control
        case 63: return "Fn"
        // Функциональные клавиши macOS имеют «нечисловые» коды
        case 122: return "F1"
        case 120: return "F2"
        case 99: return "F3"
        case 118: return "F4"
        case 96: return "F5"
        case 97: return "F6"
        case 98: return "F7"
        case 100: return "F8"
        case 101: return "F9"
        case 109: return "F10"
        case 103: return "F11"
        case 111: return "F12"
        case 105: return "F13"
        case 107: return "F14"
        case 113: return "F15"
        case 106: return "F16"
        case 64: return "F17"
        case 79: return "F18"
        case 80: return "F19"
        case 90: return "F20"
        case 115: return "Home"
        case 116: return "PageUp"
        case 117: return "Delete"
        case 119: return "End"
        case 121: return "PageDown"
        case 114: return "Help"
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        default: return ""
        }
    }
    
    /// Разбирает комбинацию в любом формате: и "⌘⇧B", и "⌘ ⇧ B".
    static func parseHotkey(_ hotkey: String) -> (NSEvent.ModifierFlags, String) {
        var modifiers: NSEvent.ModifierFlags = []
        var key = ""
        
        for character in hotkey {
            switch character {
            case "⌘": modifiers.insert(.command)
            case "⌥": modifiers.insert(.option)
            case "⇧": modifiers.insert(.shift)
            case "⌃": modifiers.insert(.control)
            case " ": continue
            default: key.append(character)
            }
        }
        
        return (modifiers, key)
    }
    
    /// Комбинация пригодна к использованию: есть и модификатор, и клавиша.
    /// Иначе нажатие одной буквы открывало бы Launcher во всей системе.
    static func isUsableHotkey(_ hotkey: String) -> Bool {
        let (modifiers, key) = parseHotkey(hotkey)
        return !key.isEmpty && !modifiers.isEmpty
    }
    
    /// Приводит комбинацию к каноническому виду "⌘ ⇧ B".
    ///
    /// Однобуквенные клавиши приводятся к верхнему регистру: каноническая
    /// форма обязана быть единственной, иначе "⌘ b" и "⌘ B" — разные строки
    /// при полностью одинаковом поведении, и сравнение комбинаций ломается.
    /// Многосимвольные (Space, Return, F1) регистр сохраняют.
    static func normalizeHotkey(_ hotkey: String) -> String {
        let (modifiers, key) = parseHotkey(hotkey)
        guard !key.isEmpty else { return hotkey }
        
        let canonicalKey = key.count == 1 ? key.uppercased() : key
        
        var parts: [String] = []
        if modifiers.contains(.command) { parts.append("⌘") }
        if modifiers.contains(.option) { parts.append("⌥") }
        if modifiers.contains(.shift) { parts.append("⇧") }
        if modifiers.contains(.control) { parts.append("⌃") }
        parts.append(canonicalKey)
        return parts.joined(separator: " ")
    }
}
