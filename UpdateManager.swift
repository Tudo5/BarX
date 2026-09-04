// MARK: - UpdateManager.swift

import Foundation
import AppKit
import Combine
import SwiftUI

class UpdateManager: ObservableObject {
    static let shared = UpdateManager()
    
    @Published var isChecking = false
    @Published var updateAvailable = false
    @Published var latestVersion = ""
    @Published var releaseNotes = ""
    @Published var downloadURL = ""
    
    // Текущая версия приложения (обновляйте при каждом релизе)
    private let currentVersion = "1.0.0"
    
    // Для GitHub релизов
    private let repoOwner = "Tudo5"
    private let repoName = "BarX"
    
    private var updateURL: URL {
        URL(string: "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest")!
    }
    
    private init() {}
    
    func checkForUpdates() {
        isChecking = true
        updateAvailable = false
        
        URLSession.shared.dataTask(with: updateURL) { [weak self] data, response, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isChecking = false
            }
            
            if let error = error {
                print("Ошибка проверки обновлений: \(error)")
                return
            }
            
            guard let data = data else { return }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    self.processUpdateJSON(json)
                } else {
                    print("Неверный формат JSON")
                }
            } catch {
                print("Ошибка парсинга JSON: \(error)")
            }
        }.resume()
    }
    
    private func processUpdateJSON(_ json: [String: Any]) {
        // Для GitHub API
        if let tagName = json["tag_name"] as? String,
           let assets = json["assets"] as? [[String: Any]],
           let firstAsset = assets.first,
           let downloadURL = firstAsset["browser_download_url"] as? String {
            
            let version = tagName.replacingOccurrences(of: "v", with: "")
            
            if isNewerVersion(version, than: currentVersion) {
                DispatchQueue.main.async {
                    self.latestVersion = version
                    self.downloadURL = downloadURL
                    self.releaseNotes = json["body"] as? String ?? "Доступна новая версия"
                    self.updateAvailable = true
                    self.showUpdateAlert()
                }
            }
        }
        // Для стандартного JSON (если используете свой сервер)
        else if let version = json["version"] as? String,
                let downloadURL = json["downloadURL"] as? String {
            
            if isNewerVersion(version, than: currentVersion) {
                DispatchQueue.main.async {
                    self.latestVersion = version
                    self.downloadURL = downloadURL
                    self.releaseNotes = json["releaseNotes"] as? String ?? "Доступна новая версия"
                    self.updateAvailable = true
                    self.showUpdateAlert()
                }
            }
        }
    }
    
    private func isNewerVersion(_ newVersion: String, than oldVersion: String) -> Bool {
        return newVersion.compare(oldVersion, options: .numeric) == .orderedDescending
    }
    
    private func showUpdateAlert() {
        let alert = NSAlert()
        alert.messageText = "Доступно обновление BarX!"
        alert.informativeText = """
        Версия \(latestVersion) уже доступна.
        
        \(releaseNotes)
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Скачать")
        alert.addButton(withTitle: "Позже")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if let url = URL(string: downloadURL) {
                NSWorkspace.shared.open(url)
            }
        }
    }
}
