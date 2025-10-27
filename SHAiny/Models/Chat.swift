//
//  Chat.swift
//  SHAiny
//
//  Created by Сергей Вихляев on 26.10.2025.
//

import Foundation

/// Represents a chat room in the application
/// Can be either a global announcement channel or a private encrypted chat
struct Chat: Identifiable {
    /// Unique identifier for SwiftUI list management
    let id: UUID
    
    /// Chat ID from the backend
    let chatId: String
    
    /// Display name of the chat (decrypted if custom name exists)
    let name: String
    
    /// Preview of the last message in the chat
    let lastMessage: String?
    
    /// Name of the user who sent the last message
    let lastMessageSender: String?
    
    /// Timestamp of the last activity in the chat
    let timestamp: Date
    
    /// Number of participants in the chat
    let participantsCount: Int
    
    /// Whether this is a global announcement channel
    let isGlobal: Bool
    
    /// Whether users can send messages (false for announcement channels)
    let isReadOnly: Bool
    
    /// Encryption key for message encryption/decryption (stored locally)
    let encryptionKey: String?
    
    /// Whether the chat has a custom encrypted name
    let hasCustomName: Bool
    
    /// Number of unread messages in this chat
    let unreadCount: Int
    
    init(
        id: UUID = UUID(),
        chatId: String,
        name: String,
        lastMessage: String?,
        lastMessageSender: String? = nil,
        timestamp: Date,
        participantsCount: Int,
        isGlobal: Bool = false,
        isReadOnly: Bool = false,
        encryptionKey: String? = nil,
        hasCustomName: Bool = false,
        unreadCount: Int = 0
    ) {
        self.id = id
        self.chatId = chatId
        self.name = name
        self.lastMessage = lastMessage
        self.lastMessageSender = lastMessageSender
        self.timestamp = timestamp
        self.participantsCount = participantsCount
        self.isGlobal = isGlobal
        self.isReadOnly = isReadOnly
        self.encryptionKey = encryptionKey
        self.hasCustomName = hasCustomName
        self.unreadCount = unreadCount
    }
}

