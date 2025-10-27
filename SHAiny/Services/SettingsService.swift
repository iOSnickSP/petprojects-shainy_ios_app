//
//  SettingsService.swift
//  SHAiny
//
//  Created by Сергей Вихляев on 26.10.2025.
//

import Foundation

class SettingsService {
    static let shared = SettingsService()
    
    private let userDefaults = UserDefaults.standard
    private let showEncryptedDataKey = "settings_showEncryptedData"
    private let serverURLKey = "settings_serverURL"
    
    // Дефолтный URL сервера
    private let defaultServerURL = "http://192.168.1.128:3000/api"
    
    private init() {
        print("🔧 SettingsService initialized with server URL: \(serverURL)")
    }
    
    /// URL сервера (можно изменить в настройках)
    var serverURL: String {
        get {
            return userDefaults.string(forKey: serverURLKey) ?? defaultServerURL
        }
        set {
            userDefaults.set(newValue, forKey: serverURLKey)
            print("🔧 Settings: serverURL changed to \(newValue)")
        }
    }
    
    /// WebSocket URL (преобразует http -> ws)
    var webSocketURL: String {
        let apiURL = serverURL
        // Убираем /api если есть
        let baseURL = apiURL.replacingOccurrences(of: "/api", with: "")
        // Заменяем http на ws
        let wsURL = baseURL.replacingOccurrences(of: "http://", with: "ws://")
                           .replacingOccurrences(of: "https://", with: "wss://")
        return "\(wsURL)/ws"
    }
    
    /// Показывать ли зашифрованные данные в сообщениях (по умолчанию true)
    var showEncryptedData: Bool {
        get {
            // Если ключ не установлен, возвращаем true (показываем по умолчанию)
            if userDefaults.object(forKey: showEncryptedDataKey) == nil {
                return true
            }
            return userDefaults.bool(forKey: showEncryptedDataKey)
        }
        set {
            userDefaults.set(newValue, forKey: showEncryptedDataKey)
            print("🔧 Settings: showEncryptedData = \(newValue)")
        }
    }
}

