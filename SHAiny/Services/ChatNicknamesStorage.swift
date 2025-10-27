//
//  ChatNicknamesStorage.swift
//  SHAiny
//
//  Created by AI Assistant on 26.10.2025.
//

import Foundation

class ChatNicknamesStorage {
    static let shared = ChatNicknamesStorage()
    
    private let userDefaults = UserDefaults.standard
    private let nicknamesKey = "chat_nicknames"
    
    private init() {}
    
    // Получить все никнеймы
    private func getAllNicknames() -> [String: String] {
        if let data = userDefaults.data(forKey: nicknamesKey),
           let nicknames = try? JSONDecoder().decode([String: String].self, from: data) {
            return nicknames
        }
        return [:]
    }
    
    // Сохранить все никнеймы
    private func saveAllNicknames(_ nicknames: [String: String]) {
        if let data = try? JSONEncoder().encode(nicknames) {
            userDefaults.set(data, forKey: nicknamesKey)
            print("✅ Nicknames saved")
        }
    }
    
    // Получить никнейм для конкретного чата
    func getNickname(for chatId: String) -> String? {
        let nicknames = getAllNicknames()
        return nicknames[chatId]
    }
    
    // Сохранить никнейм для конкретного чата
    func saveNickname(_ nickname: String, for chatId: String) {
        var nicknames = getAllNicknames()
        nicknames[chatId] = nickname
        saveAllNicknames(nicknames)
        print("✅ Nickname saved for chat \(chatId): \(nickname)")
    }
    
    // Удалить никнейм для конкретного чата
    func deleteNickname(for chatId: String) {
        var nicknames = getAllNicknames()
        nicknames.removeValue(forKey: chatId)
        saveAllNicknames(nicknames)
        print("🗑️ Nickname deleted for chat \(chatId)")
    }
    
    // Удалить все никнеймы (при logout)
    func deleteAllNicknames() {
        userDefaults.removeObject(forKey: nicknamesKey)
        print("🗑️ All nicknames deleted")
    }
}

