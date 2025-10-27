//
//  KeychainService.swift
//  SHAiny
//
//  Created by Сергей Вихляев on 26.10.2025.
//

import Foundation
import Security

class KeychainService {
    static let shared = KeychainService()
    
    private let service = "com.shainy.app"
    private let accessTokenKey = "accessToken"
    
    private init() {}
    
    // Сохранение accessToken
    func saveAccessToken(_ token: String) -> Bool {
        let data = token.data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: accessTokenKey,
            kSecValueData as String: data
        ]
        
        // Удаляем старый токен если есть
        SecItemDelete(query as CFDictionary)
        
        // Сохраняем новый
        let status = SecItemAdd(query as CFDictionary, nil)
        let success = status == errSecSuccess
        print(success ? "✅ Access token saved to Keychain" : "❌ Failed to save access token")
        return success
    }
    
    // Получение accessToken
    func getAccessToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: accessTokenKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess, let data = dataTypeRef as? Data {
            let token = String(data: data, encoding: .utf8)
            print(token != nil ? "✅ Access token found in Keychain" : "❌ Failed to decode token")
            return token
        }
        
        print("ℹ️ No access token in Keychain")
        return nil
    }
    
    // Удаление accessToken
    func deleteAccessToken() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: accessTokenKey
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
    
    // Извлечение userId из JWT токена
    func getUserIdFromToken() -> String? {
        guard let token = getAccessToken() else {
            return nil
        }
        
        // JWT состоит из 3 частей: header.payload.signature
        let parts = token.components(separatedBy: ".")
        guard parts.count == 3 else {
            print("❌ Invalid JWT format")
            return nil
        }
        
        // Декодируем payload (вторая часть)
        let payload = parts[1]
        
        // Добавляем padding если нужно
        var base64String = payload
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        
        let paddingLength = 4 - base64String.count % 4
        if paddingLength < 4 {
            base64String += String(repeating: "=", count: paddingLength)
        }
        
        guard let data = Data(base64Encoded: base64String),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let userId = json["userId"] as? String else {
            print("❌ Failed to decode userId from token")
            return nil
        }
        
        print("✅ Extracted userId: \(userId)")
        return userId
    }
}

