//
//  CryptoUtils.swift
//  SHAiny
//
//  Created by Сергей Вихляев on 26.10.2025.
//

import Foundation
import CryptoKit

enum CryptoError: Error {
    case invalidFormat
    case decryptionFailed
    case authenticationFailed
    case invalidKey
}

class CryptoUtils {
    
    // MARK: - AES-GCM Encryption/Decryption
    
    /// Расшифровывает текст с помощью AES-256-GCM
    /// - Parameters:
    ///   - encryptedText: Зашифрованный текст в формате "nonce:encrypted:authTag"
    ///   - keyPhrase: Кодовая фраза для расшифровки
    /// - Returns: Расшифрованный текст
    static func decrypt(_ encryptedText: String, keyPhrase: String) throws -> String {
        // Разделяем nonce, зашифрованные данные и authentication tag
        let parts = encryptedText.components(separatedBy: ":")
        guard parts.count == 3 else {
            throw CryptoError.invalidFormat
        }
        
        guard let nonceData = Data(hexString: parts[0]),
              let encryptedData = Data(hexString: parts[1]),
              let authTagData = Data(hexString: parts[2]) else {
            throw CryptoError.invalidFormat
        }
        
        // Генерируем ключ из кодовой фразы (SHA-256)
        let symmetricKey = deriveKey(from: keyPhrase)
        
        // Создаем AES.GCM.Nonce
        guard let nonce = try? AES.GCM.Nonce(data: nonceData) else {
            throw CryptoError.invalidFormat
        }
        
        // Создаем SealedBox из компонентов
        guard let sealedBox = try? AES.GCM.SealedBox(nonce: nonce, ciphertext: encryptedData, tag: authTagData) else {
            throw CryptoError.invalidFormat
        }
        
        // Расшифровываем
        do {
            let decryptedData = try AES.GCM.open(sealedBox, using: symmetricKey)
            guard let decryptedString = String(data: decryptedData, encoding: .utf8) else {
                throw CryptoError.decryptionFailed
            }
            return decryptedString
        } catch {
            throw CryptoError.authenticationFailed
        }
    }
    
    /// Шифрует текст с помощью AES-256-GCM
    /// - Parameters:
    ///   - text: Исходный текст
    ///   - keyPhrase: Кодовая фраза для шифрования
    /// - Returns: Зашифрованный текст в формате "nonce:encrypted:authTag"
    static func encrypt(_ text: String, keyPhrase: String) throws -> String {
        guard let textData = text.data(using: .utf8) else {
            throw CryptoError.invalidFormat
        }
        
        // Генерируем ключ из кодовой фразы
        let symmetricKey = deriveKey(from: keyPhrase)
        
        // Шифруем с помощью AES-GCM
        do {
            let sealedBox = try AES.GCM.seal(textData, using: symmetricKey)
            
            // Извлекаем nonce, ciphertext и tag
            let nonceData = sealedBox.nonce.withUnsafeBytes { Data($0) }
            let ciphertext = sealedBox.ciphertext
            let tag = sealedBox.tag
            
            // Возвращаем nonce:encrypted:authTag в hex формате
            return nonceData.hexString + ":" + ciphertext.hexString + ":" + tag.hexString
        } catch {
            throw CryptoError.decryptionFailed
        }
    }
    
    // MARK: - SHA-256 Hashing
    
    /// Генерирует SHA-256 хеш текста
    /// - Parameter text: Исходный текст
    /// - Returns: SHA-256 хеш в hex формате
    static func generateHash(_ text: String) -> String {
        guard let data = text.data(using: .utf8) else { return "" }
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    // MARK: - Private Helper Methods
    
    /// Генерирует 256-битный ключ из кодовой фразы с помощью SHA-256
    private static func deriveKey(from keyPhrase: String) -> SymmetricKey {
        guard let phraseData = keyPhrase.data(using: .utf8) else {
            return SymmetricKey(size: .bits256)
        }
        let hash = SHA256.hash(data: phraseData)
        return SymmetricKey(data: hash)
    }
}

// MARK: - Data Extensions

extension Data {
    /// Создает Data из hex строки
    init?(hexString: String) {
        let len = hexString.count / 2
        var data = Data(capacity: len)
        var index = hexString.startIndex
        
        for _ in 0..<len {
            let nextIndex = hexString.index(index, offsetBy: 2)
            let byteString = hexString[index..<nextIndex]
            
            guard let byte = UInt8(byteString, radix: 16) else {
                return nil
            }
            
            data.append(byte)
            index = nextIndex
        }
        
        self = data
    }
    
    /// Конвертирует Data в hex строку
    var hexString: String {
        return map { String(format: "%02x", $0) }.joined()
    }
}

