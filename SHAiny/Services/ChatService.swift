//
//  ChatService.swift
//  SHAiny
//
//  Created by Сергей Вихляев on 26.10.2025.
//

import Foundation

class ChatService {
    static let shared = ChatService()
    
    private var baseURL: String {
        return SettingsService.shared.serverURL
    }
    
    private init() {
        print("💬 ChatService initialized")
    }
    
    struct ChatResponse: Codable {
        let chats: [ChatDTO]
    }
    
    struct ChatDTO: Codable {
        let chatId: String
        let name: String
        let encryptedName: String?
        let participantsCount: Int
        let lastMessage: LastMessageDTO?
        let isGlobal: Bool
        let isReadOnly: Bool
        let unreadCount: Int
        let createdAt: Double
    }
    
    struct LastMessageDTO: Codable {
        let text: String
        let timestamp: Double
        let senderName: String?
    }
    
    // Получение списка чатов
    func fetchChats() async throws -> [Chat] {
        guard let token = KeychainService.shared.getAccessToken() else {
            throw NSError(domain: "ChatService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No access token"])
        }
        
        let url = URL(string: "\(baseURL)/chat/list")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        print("💬 Fetching chats...")
        print("📡 Request URL: \(url.absoluteString)")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response type")
                throw NSError(domain: "ChatService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
            }
            
            print("📊 Response status: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode == 200 {
                let chatResponse = try JSONDecoder().decode(ChatResponse.self, from: data)
                print("✅ Fetched \(chatResponse.chats.count) chats")
                
                return chatResponse.chats.compactMap { dto -> Chat? in
                    // Для глобального чата Announcements устанавливаем ключ шифрования
                    var encryptionKey: String? = nil
                    if dto.chatId == "global-announcements" {
                        encryptionKey = "AnnouncementsSHAinyChat"
                    } else {
                        // Для приватных чатов получаем ключ из локального хранилища
                        encryptionKey = ChatKeysStorage.shared.getKey(forChatId: dto.chatId)
                    }
                    
                    let hasEncryptedName = dto.encryptedName != nil
                    var chatName = dto.name
                    
                    // Если имя зашифровано и есть ключ - расшифровываем
                    if hasEncryptedName, let encKey = encryptionKey, let encrypted = dto.encryptedName {
                        do {
                            chatName = try CryptoUtils.decrypt(encrypted, keyPhrase: encKey)
                            print("✅ Chat name decrypted: \(chatName)")
                        } catch {
                            print("⚠️ Failed to decrypt chat name: \(error.localizedDescription)")
                            chatName = dto.name // Fallback to hash/encrypted name
                        }
                    }
                    
                    return Chat(
                        id: UUID(),
                        chatId: dto.chatId,
                        name: chatName,
                        lastMessage: dto.lastMessage?.text,
                        lastMessageSender: dto.lastMessage?.senderName,
                        timestamp: Date(timeIntervalSince1970: dto.createdAt / 1000),
                        participantsCount: dto.participantsCount,
                        isGlobal: dto.isGlobal,
                        isReadOnly: dto.isReadOnly,
                        encryptionKey: encryptionKey,
                        hasCustomName: hasEncryptedName,
                        unreadCount: dto.unreadCount
                    )
                }
            } else {
                print("❌ Failed to fetch chats: \(httpResponse.statusCode)")
                throw NSError(domain: "ChatService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch chats"])
            }
        } catch {
            print("❌ Network error: \(error.localizedDescription)")
            throw error
        }
    }
    
    struct MessagesResponse: Codable {
        let messages: [MessageDTO]
        let pagination: PaginationDTO
    }
    
    struct PaginationDTO: Codable {
        let limit: Int
        let offset: Int
        let totalCount: Int
        let hasMore: Bool
    }
    
    struct MessageDTO: Codable {
        let id: String
        let userId: String
        let text: String
        let shaHash: String
        let timestamp: Double
        let senderName: String?
        let isSystem: Bool?
        let replyTo: ReplyDTO?
        
        struct ReplyDTO: Codable {
            let messageId: String
            let text: String
            let senderName: String
            let timestamp: Double
        }
    }
    
    // Получение сообщений чата с пагинацией
    func fetchMessages(chatId: String, encryptionKey: String? = nil, limit: Int = 50, offset: Int = 0) async throws -> (messages: [Message], hasMore: Bool) {
        guard let token = KeychainService.shared.getAccessToken() else {
            throw NSError(domain: "ChatService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No access token"])
        }
        
        var urlComponents = URLComponents(string: "\(baseURL)/chat/\(chatId)/messages")!
        urlComponents.queryItems = [
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "offset", value: String(offset))
        ]
        
        guard let url = urlComponents.url else {
            throw NSError(domain: "ChatService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        print("💬 Fetching messages for chat: \(chatId)")
        print("📡 Request URL: \(url.absoluteString)")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response type")
                throw NSError(domain: "ChatService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
            }
            
            print("📊 Response status: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode == 200 {
                let messagesResponse = try JSONDecoder().decode(MessagesResponse.self, from: data)
                print("✅ Fetched \(messagesResponse.messages.count) messages (hasMore: \(messagesResponse.pagination.hasMore))")
                
                // Получаем userId текущего пользователя
                let currentUserId = KeychainService.shared.getUserIdFromToken()
                
                let messages = messagesResponse.messages.compactMap { dto -> Message? in
                    let encryptedText = dto.text
                    var decryptedText = dto.text
                    
                    print("📩 Processing message \(dto.id)")
                    print("   Encrypted text (first 50 chars): \(String(dto.text.prefix(50)))...")
                    print("   SHA hash from backend: \(dto.shaHash)")
                    
                    // Если есть ключ шифрования, расшифровываем сообщение
                    if let key = encryptionKey {
                        do {
                            decryptedText = try CryptoUtils.decrypt(dto.text, keyPhrase: key)
                            print("   Decrypted text: \(String(decryptedText.prefix(50)))...")
                            
                            // Проверяем хеш расшифрованного сообщения
                            let calculatedHash = CryptoUtils.generateHash(decryptedText)
                            print("   Calculated hash: \(calculatedHash)")
                            if calculatedHash != dto.shaHash {
                                print("⚠️ Hash mismatch for message \(dto.id)")
                            } else {
                                print("✅ Message decrypted and verified: \(dto.id)")
                            }
                        } catch {
                            print("❌ Failed to decrypt message \(dto.id): \(error.localizedDescription)")
                            return nil // Пропускаем сообщения, которые не удалось расшифровать
                        }
                    }
                    
                    // Process reply if present
                    var replyTo: MessageReply? = nil
                    if let replyDTO = dto.replyTo {
                        replyTo = MessageReply(
                            messageId: replyDTO.messageId,
                            text: replyDTO.text,
                            senderName: replyDTO.senderName,
                            timestamp: Date(timeIntervalSince1970: replyDTO.timestamp / 1000)
                        )
                    }
                    
                    let message = Message(
                        id: UUID(uuidString: dto.id) ?? UUID(),
                        text: decryptedText,
                        encryptedText: encryptedText,
                        shaHash: dto.shaHash,
                        timestamp: Date(timeIntervalSince1970: dto.timestamp / 1000),
                        isFromCurrentUser: (dto.userId == currentUserId),
                        senderName: dto.senderName,
                        replyTo: replyTo
                    )
                    
                    print("   Message created with encrypted text length: \(message.encryptedText.count)")
                    
                    return message
                }
                
                return (messages: messages, hasMore: messagesResponse.pagination.hasMore)
            } else {
                print("❌ Failed to fetch messages: \(httpResponse.statusCode)")
                throw NSError(domain: "ChatService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch messages"])
            }
        } catch {
            print("❌ Network error: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Chat Management
    
    struct CheckChatResponse: Codable {
        let exists: Bool
        let chatId: String?
        let chatName: String?
    }
    
    /// Проверяет существование чата по hash ключа
    func checkChatExists(keyHash: String) async throws -> CheckChatResponse {
        guard let token = KeychainService.shared.getAccessToken() else {
            throw NSError(domain: "ChatService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No access token"])
        }
        
        let url = URL(string: "\(baseURL)/chat/check")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let body = ["keyHash": keyHash]
        request.httpBody = try JSONEncoder().encode(body)
        
        print("🔍 Checking chat existence with keyHash: \(String(keyHash.prefix(16)))...")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "ChatService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        
        print("📊 Response status: \(httpResponse.statusCode)")
        
        if httpResponse.statusCode == 200 {
            let checkResponse = try JSONDecoder().decode(CheckChatResponse.self, from: data)
            print(checkResponse.exists ? "✅ Chat exists" : "ℹ️ Chat doesn't exist")
            return checkResponse
        } else {
            throw NSError(domain: "ChatService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to check chat"])
        }
    }
    
    struct CreateChatResponse: Codable {
        let chatId: String
        let name: String
        let keyHash: String
        let createdAt: Double
    }
    
    /// Создает новый чат
    func createChat(keyPhrase: String, keyHash: String) async throws -> Chat {
        guard let token = KeychainService.shared.getAccessToken() else {
            throw NSError(domain: "ChatService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No access token"])
        }
        
        let url = URL(string: "\(baseURL)/chat/create")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let body = ["keyHash": keyHash]
        request.httpBody = try JSONEncoder().encode(body)
        
        print("🆕 Creating new chat with keyHash: \(String(keyHash.prefix(16)))...")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "ChatService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        
        print("📊 Response status: \(httpResponse.statusCode)")
        
        if httpResponse.statusCode == 201 {
            let createResponse = try JSONDecoder().decode(CreateChatResponse.self, from: data)
            print("✅ Chat created: \(createResponse.name)")
            
            return Chat(
                chatId: createResponse.chatId,
                name: createResponse.name,
                lastMessage: nil,
                timestamp: Date(timeIntervalSince1970: createResponse.createdAt / 1000),
                participantsCount: 1,
                encryptionKey: keyPhrase,
                unreadCount: 0
            )
        } else {
            throw NSError(domain: "ChatService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to create chat"])
        }
    }
    
    struct JoinChatResponse: Codable {
        let chatId: String
        let name: String
        let participantsCount: Int
        let createdAt: Double
    }
    
    /// Присоединяется к существующему чату
    func joinChat(chatId: String, keyPhrase: String) async throws -> Chat {
        guard let token = KeychainService.shared.getAccessToken() else {
            throw NSError(domain: "ChatService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No access token"])
        }
        
        let url = URL(string: "\(baseURL)/chat/\(chatId)/join")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        print("🤝 Joining chat: \(chatId)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "ChatService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        
        print("📊 Response status: \(httpResponse.statusCode)")
        
        if httpResponse.statusCode == 200 {
            let joinResponse = try JSONDecoder().decode(JoinChatResponse.self, from: data)
            print("✅ Joined chat: \(joinResponse.name)")
            
            return Chat(
                chatId: joinResponse.chatId,
                name: joinResponse.name,
                lastMessage: nil,
                timestamp: Date(timeIntervalSince1970: joinResponse.createdAt / 1000),
                participantsCount: joinResponse.participantsCount,
                encryptionKey: keyPhrase,
                unreadCount: 0
            )
        } else {
            throw NSError(domain: "ChatService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to join chat"])
        }
    }
    
    /// Переименовать чат (зашифрованное имя)
    func renameChat(chatId: String, newName: String, encryptionKey: String) async throws {
        guard let token = KeychainService.shared.getAccessToken() else {
            throw NSError(domain: "ChatService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No access token"])
        }
        
        // Шифруем новое имя
        let encryptedName = try CryptoUtils.encrypt(newName, keyPhrase: encryptionKey)
        
        let url = URL(string: "\(baseURL)/chat/\(chatId)/name")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let body = ["encryptedName": encryptedName]
        request.httpBody = try JSONEncoder().encode(body)
        
        print("✏️ Renaming chat \(chatId) to: \(newName)")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "ChatService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        
        print("📊 Response status: \(httpResponse.statusCode)")
        
        if httpResponse.statusCode != 200 {
            throw NSError(domain: "ChatService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to rename chat"])
        }
        
        print("✅ Chat renamed successfully")
    }
    
    /// Пометить чат как прочитанный
    func markChatAsRead(chatId: String) async throws {
        guard let token = KeychainService.shared.getAccessToken() else {
            throw NSError(domain: "ChatService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No access token"])
        }
        
        let url = URL(string: "\(baseURL)/chat/\(chatId)/read")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        print("✅ Marking chat \(chatId) as read")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "ChatService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        
        if httpResponse.statusCode != 200 {
            throw NSError(domain: "ChatService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to mark chat as read"])
        }
        
        print("✅ Chat \(chatId) marked as read")
    }
    
    // MARK: - Nicknames
    
    struct SetNicknameResponse: Codable {
        let success: Bool
        let nickname: String
    }
    
    struct GetNicknameResponse: Codable {
        let nickname: String?
    }
    
    /// Установить никнейм для текущего пользователя в чате
    func setNickname(_ nickname: String, for chatId: String) async throws {
        guard let token = KeychainService.shared.getAccessToken() else {
            throw NSError(domain: "ChatService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No access token"])
        }
        
        let url = URL(string: "\(baseURL)/chat/\(chatId)/nickname")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let body = ["nickname": nickname]
        request.httpBody = try JSONEncoder().encode(body)
        
        print("👤 Setting nickname '\(nickname)' for chat \(chatId)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "ChatService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        
        if httpResponse.statusCode == 200 {
            let setResponse = try JSONDecoder().decode(SetNicknameResponse.self, from: data)
            print("✅ Nickname set: \(setResponse.nickname)")
            
            // Сохраняем локально
            ChatNicknamesStorage.shared.saveNickname(nickname, for: chatId)
        } else {
            throw NSError(domain: "ChatService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to set nickname"])
        }
    }
    
    /// Получить свой никнейм в чате
    func getNickname(for chatId: String) async throws -> String? {
        // Сначала проверяем локальное хранилище
        if let localNickname = ChatNicknamesStorage.shared.getNickname(for: chatId) {
            return localNickname
        }
        
        // Если нет локально, запрашиваем с бэкенда
        guard let token = KeychainService.shared.getAccessToken() else {
            throw NSError(domain: "ChatService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No access token"])
        }
        
        let url = URL(string: "\(baseURL)/chat/\(chatId)/nickname")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "ChatService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        
        if httpResponse.statusCode == 200 {
            let getResponse = try JSONDecoder().decode(GetNicknameResponse.self, from: data)
            
            // Если есть никнейм с бэкенда, сохраняем его локально
            if let nickname = getResponse.nickname {
                ChatNicknamesStorage.shared.saveNickname(nickname, for: chatId)
            }
            
            return getResponse.nickname
        } else {
            throw NSError(domain: "ChatService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to get nickname"])
        }
    }
}

