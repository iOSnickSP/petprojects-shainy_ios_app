//
//  ChatKeysStorage.swift
//  SHAiny
//
//  Created by Сергей Вихляев on 26.10.2025.
//

import Foundation
import Security

/// Secure storage for chat encryption keys using Keychain
/// Previously stored in UserDefaults (insecure), now uses iOS Keychain for proper encryption
class ChatKeysStorage {
    static let shared = ChatKeysStorage()
    
    private let service = "com.shainy.app.chatkeys"
    private let keysPrefix = "chatKey_"
    
    private init() {
        // Migrate existing keys from UserDefaults to Keychain on first launch
        migrateFromUserDefaultsIfNeeded()
    }
    
    /// Save encryption key for chat (stored in Keychain)
    func saveKey(_ keyPhrase: String, forChatId chatId: String) {
        guard let data = keyPhrase.data(using: .utf8) else {
            print("❌ Failed to encode key phrase")
            return
        }
        
        let account = keysPrefix + chatId
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock // Available after device unlock
        ]
        
        // Delete existing key if present
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(deleteQuery as CFDictionary)
        
        // Save new key
        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecSuccess {
            print("🔐 Saved encryption key for chat \(chatId) to Keychain")
        } else {
            print("❌ Failed to save encryption key to Keychain: \(status)")
        }
    }
    
    /// Get encryption key for chat (from Keychain)
    func getKey(forChatId chatId: String) -> String? {
        let account = keysPrefix + chatId
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess, let data = dataTypeRef as? Data {
            let keyPhrase = String(data: data, encoding: .utf8)
            if keyPhrase != nil {
                print("🔐 Retrieved encryption key for chat \(chatId) from Keychain")
            }
            return keyPhrase
        }
        
        if status != errSecItemNotFound {
            print("❌ Failed to retrieve encryption key from Keychain: \(status)")
        }
        return nil
    }
    
    /// Delete encryption key for chat (from Keychain)
    func deleteKey(forChatId chatId: String) {
        let account = keysPrefix + chatId
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        if status == errSecSuccess || status == errSecItemNotFound {
            print("🗑 Deleted encryption key for chat \(chatId) from Keychain")
        } else {
            print("❌ Failed to delete encryption key from Keychain: \(status)")
        }
    }
    
    /// Delete all encryption keys (on logout)
    func deleteAllKeys() {
        // Query all items with our service identifier
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        if status == errSecSuccess || status == errSecItemNotFound {
            print("🗑 All chat encryption keys deleted from Keychain")
        } else {
            print("❌ Failed to delete all keys from Keychain: \(status)")
        }
    }
    
    // MARK: - Migration from UserDefaults
    
    /// Migrate existing keys from UserDefaults to Keychain (one-time operation)
    private func migrateFromUserDefaultsIfNeeded() {
        let migrationKey = "chatKeys_migrated_to_keychain"
        let userDefaults = UserDefaults.standard
        
        // Check if migration already done
        if userDefaults.bool(forKey: migrationKey) {
            return
        }
        
        print("🔄 Migrating chat keys from UserDefaults to Keychain...")
        
        var migratedCount = 0
        let allKeys = userDefaults.dictionaryRepresentation().keys
        
        for key in allKeys where key.hasPrefix(keysPrefix) {
            if let keyPhrase = userDefaults.string(forKey: key) {
                // Extract chatId from key
                let chatId = String(key.dropFirst(keysPrefix.count))
                
                // Save to Keychain
                saveKey(keyPhrase, forChatId: chatId)
                
                // Remove from UserDefaults
                userDefaults.removeObject(forKey: key)
                
                migratedCount += 1
            }
        }
        
        // Mark migration as complete
        userDefaults.set(true, forKey: migrationKey)
        userDefaults.synchronize()
        
        if migratedCount > 0 {
            print("✅ Migrated \(migratedCount) chat keys to Keychain")
        } else {
            print("ℹ️ No chat keys found in UserDefaults to migrate")
        }
    }
}

