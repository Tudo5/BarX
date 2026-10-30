//
//  WindowManager.swift
//  BarX
//
//  Менеджер окон и делегат
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers
import Combine
import ServiceManagement
import UserNotifications
import ApplicationServices

// MARK: - BarXWindowManager

@MainActor
final class BarXWindowManager: NSObject {
    static let shared = BarXWindowManager()
    private var windows: [String: NSWindow] = [:]
    private var delegates: [NSObject] = []
    private var mainMenuWindow: NSWindow?
    
    private override init() {
        super.init()
    }
    
    func showWindow<Content: View>(
        id: String,
        title: String,
        size: CGSize,
        content: Content,
        isMainMenu: Bool = false
    ) {
        // Повторно открытое окно пересобираем, а не переиспользуем: иначе в нём
        // остаётся старый контент (устаревший presetId/настройки), и элементы
        // уходили не в ту папку. Правило проекта — окно при повторном открытии
        // пересобирать (см. AGENTS.md).
        if windows[id] != nil {
            closeWindow(id: id)
        }

        let hostingController = NSHostingController(
            rootView: content
        )
        
        let window = NSWindow(
            contentViewController: hostingController
        )
        window.title = title
        window.setContentSize(size)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.isReleasedWhenClosed = false
        window.center()
        
        let delegate = BarXWindowDelegate { [weak self, weak window] in
            guard let self else { return }
            if let window {
                self.removeWindow(window)
            }
        }
        window.delegate = delegate
        delegates.append(delegate)
        windows[id] = window
        
        if isMainMenu {
            mainMenuWindow = window
        }
        
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }
    
    func closeWindow(id: String) {
        guard let window = windows[id] else { return }
        // Снимаем делегата из удерживаемого массива — иначе каждый цикл
        // открытия/закрытия оставлял бы в `delegates` утечку объекта.
        let delegate = window.delegate
        window.delegate = nil
        window.close()
        windows.removeValue(forKey: id)
        if let delegate {
            delegates.removeAll { $0 === delegate }
        }
        if mainMenuWindow === window { mainMenuWindow = nil }
    }

    /// Меняет размер уже открытого окна (например, диалог «Добавить элемент»
    /// расширяется при выборе типа с многострочным редактором действия).
    ///
    /// ВАЖНО: используем немодальную анимацию через `animator()`, а НЕ
    /// `setFrame(_:display:animate: true)`. Последний крутит run-loop прямо
    /// внутри SwiftUI-обновления (`onChange`) и при быстрых повторных кликах
    /// приводил к пере-entrant обновлению вида и падению приложения.
    func resizeWindow(id: String, size: CGSize) {
        guard let window = windows[id], window.isVisible else { return }
        let frame = window.frame
        let newOrigin = NSPoint(
            x: frame.origin.x,
            // Держим верхнюю кромку на месте — окно растёт вниз.
            y: frame.origin.y + (frame.height - size.height)
        )
        let newFrame = NSRect(origin: newOrigin, size: size)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            context.allowsImplicitAnimation = true
            window.animator().setFrame(newFrame, display: true)
        }
    }
    
    func removeWindow(_ window: NSWindow) {
        for (id, storedWindow) in windows where storedWindow === window {
            windows.removeValue(forKey: id)
            break
        }
        if mainMenuWindow === window { mainMenuWindow = nil }
        // Делегат больше не нужен — иначе массив растёт всю сессию
        delegates.removeAll { $0 === window.delegate }
    }
    
    func closeAllWindows() {
        // Не закрываем окно настроек, если пользователь закрывает меню
        for (id, window) in windows where id != "settings" {
            window.delegate = nil
            window.close()
            windows.removeValue(forKey: id)
        }
        delegates.removeAll()
        mainMenuWindow = nil
    }
    
    func closeAllWindowsIncludingSettings() {
        for window in windows.values {
            window.delegate = nil
            window.close()
        }
        windows.removeAll()
        delegates.removeAll()
        mainMenuWindow = nil
    }
    
    /// Есть ли открытое окно с таким id.
    func isWindowOpen(id: String) -> Bool {
        windows[id] != nil
    }
    
    /// Открывает главное меню в отдельном окне.
    ///
    /// Окно пересобирается при каждом вызове: раньше оно создавалось один раз
    /// и оставалось с устаревшими настройками, а размер был жёстко задан
    /// (300×500), из-за чего содержимое клипалось и снизу оставалась пустота.
    func showMainMenu() {
        closeMainMenuWindow()

        let menuView = BarXMenuView()
            .environmentObject(AppStateManager.shared)
            .environmentObject(ThemeManager.shared)
            .environmentObject(LauncherManager.shared)

        let hostingController = NSHostingController(rootView: menuView)
        // sizingOptions = [.preferredContentSize] НЕ ставим: он заставляет AppKit
        // читать preferredContentSize внутри updateViewConstraints, а контент в
        // этот момент ещё не успокоился (onAppear подгружает папки и пресеты).
        // AppKit ловит реентерабельное обновление констрейнтов и сознательно
        // падает через _crashOnException в _postWindowNeedsUpdateConstraints —
        // это и был краш при открытии главного меню. Размер задаём явно через
        // setContentSize — так уже работает не крашащееся окно настроек.

        let window = NSWindow(contentViewController: hostingController)
        window.title = "BarX"
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.backgroundColor = .clear
        window.isOpaque = false
        window.animationBehavior = .utilityWindow
        window.setContentSize(hostingController.view.fittingSize)
        window.center()

        let delegate = BarXWindowDelegate { [weak self, weak window] in
            guard let self else { return }
            if let window { self.removeWindow(window) }
        }
        window.delegate = delegate
        delegates.append(delegate)
        mainMenuWindow = window

        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    /// Скрывает открытые presentations меню: окно главного меню и панель
    /// MenuBarExtra. Вызывается после запуска приложения («Скрывать меню
    /// после запуска») и при закрытии меню.
    ///
    /// Критично НЕ трогать:
    /// - окно Launcher (оно тоже безрамочное, но имеет заголовок «BarX Launcher»);
    /// - окно Настроек и любые диалоги (они с рамкой `.titled`).
    ///
    /// Раньше эта логика была продублирована в двух местах и ловила окна
    /// по строке заголовка — легко перепутать с другими безрамочными окнами.
    func dismissMenuPresentations() {
        closeMainMenuWindow()
        
        for window in NSApp.windows where window.isVisible {
            let isMenuBarPanel = window.styleMask.contains(.borderless) && window.title.isEmpty
            let isMainMenuTitled = window.title == "BarX"
            if isMenuBarPanel || isMainMenuTitled {
                window.orderOut(nil)
            }
        }
    }

    /// Открывает окно первого запуска (приветствие, выбор приложений и темы).
    func showOnboarding() {
        closeWindow(id: "onboarding")

        let view = OnboardingView()
            .environmentObject(AppStateManager.shared)
            .environmentObject(ThemeManager.shared)

        let hostingController = NSHostingController(rootView: view)
        // Без sizingOptions — иначе тот же реентерабельный краш Auto Layout,
        // что и у главного меню. Контент онбординга фиксированного размера
        // (620×460), поэтому явного setContentSize ниже достаточно.

        let window = NSWindow(contentViewController: hostingController)
        window.title = "Добро пожаловать в BarX"
        // Без рамки и тайтлбара — экран выглядит как часть интерфейса
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.backgroundColor = .clear
        window.isOpaque = false
        window.animationBehavior = .utilityWindow
        window.setContentSize(hostingController.view.fittingSize)
        window.center()

        let delegate = BarXWindowDelegate { [weak self, weak window] in
            guard let self else { return }
            if let window { self.removeWindow(window) }
        }
        window.delegate = delegate
        delegates.append(delegate)
        windows["onboarding"] = window

        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    /// Закрывает окно главного меню (если оно открыто).
    func closeMainMenuWindow() {
        guard let window = mainMenuWindow else { return }
        let delegate = window.delegate
        window.delegate = nil
        window.close()
        mainMenuWindow = nil
        if let delegate {
            delegates.removeAll { $0 === delegate }
        }
    }
}

// MARK: - BarXWindowDelegate

final class BarXWindowDelegate: NSObject, NSWindowDelegate {
    private let onClose: () -> Void
    
    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }
    
    func windowWillClose(_ notification: Notification) {
        onClose()
    }
}
