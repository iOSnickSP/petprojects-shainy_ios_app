//
//  Message.swift
//  SHAiny
//
//  Created by Сергей Вихляев on 26.10.2025.
//

import Foundation

/// Represents a reply to another message
struct MessageReply: Codable, Equatable {
    /// ID of the original message being replied to
    let messageId: String
    
    /// Encrypted text of the original message
    let text: String
    
    /// Sender name of the original message
    let senderName: String
    
    /// Timestamp of the original message
    let timestamp: Date
}

/// Represents a single message in a chat
/// Messages are encrypted using the chat's encryption key
struct Message: Identifiable, Equatable {
    /// Unique identifier for the message
    let id: UUID
    
    /// Decrypted message text (for display)
    let text: String
    
    /// Original encrypted text (for verification and display in debug mode)
    let encryptedText: String
    
    /// SHA-256 hash of the original unencrypted text (for integrity verification)
    let shaHash: String
    
    /// When the message was sent
    let timestamp: Date
    
    /// Whether this message was sent by the current user
    let isFromCurrentUser: Bool
    
    /// Display name of the sender (nickname set in this chat)
    let senderName: String?
    
    /// Reply information if this is a reply to another message
    let replyTo: MessageReply?
    
    init(
        id: UUID = UUID(),
        text: String,
        encryptedText: String,
        shaHash: String,
        timestamp: Date = Date(),
        isFromCurrentUser: Bool,
        senderName: String? = nil,
        replyTo: MessageReply? = nil
    ) {
        self.id = id
        self.text = text
        self.encryptedText = encryptedText
        self.shaHash = shaHash
        self.timestamp = timestamp
        self.isFromCurrentUser = isFromCurrentUser
        self.senderName = senderName
        self.replyTo = replyTo
    }
}

