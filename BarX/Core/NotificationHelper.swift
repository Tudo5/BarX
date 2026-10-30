//
//  NotificationHelper.swift
//  BarX
//
//  Системные уведомления
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers
import Combine
import ServiceManagement
import UserNotifications
import ApplicationServices

// MARK: - NotificationHelper

final class NotificationHelper {
    static let shared = NotificationHelper()

    private var isAuthorized = false
    private var requestedAuthorization = false

    private init() {}

    func requestAuthorizationIfNeeded(completion: ((Bool) -> Void)? = nil) {
        guard BarXSettings.showNotifications else {
            completion?(false)
            return
        }

        if requestedAuthorization, isAuthorized {
            completion?(true)
            return
        }

        requestedAuthorization = true
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            DispatchQueue.main.async {
                self.isAuthorized = granted
                completion?(granted)
            }
        }
    }

    func notify(title: String, body: String) {
        guard BarXSettings.showNotifications else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = nil
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    /// Уведомление о запуске приложения (используется Launcher'ом и панелью Bar).
    func notifyAppLaunched(_ app: AppItem) {
        guard BarXSettings.showNotifications else { return }
        notify(title: app.name, body: "Приложение запущено")
    }
}
