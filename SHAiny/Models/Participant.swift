//
//  Participant.swift
//  SHAiny
//
//  Created by Сергей Вихляев on 27.10.2025.
//

import Foundation

/// Represents a participant in a chat with their message visibility status
struct Participant: Identifiable, Codable {
    /// Unique identifier (user ID)
    let id: String
    
    /// User ID from the backend
    let userId: String
    
    /// User's nickname in this chat (if set)
    let nickname: String?
    
    /// When this participant joined the chat (timestamp in milliseconds)
    let joinedAt: Double?
    
    /// Whether this participant can see YOUR messages
    let canSeeMyMessages: Bool
    
    /// Whether this is the current user
    let isCurrentUser: Bool
    
    init(
        userId: String,
        nickname: String? = nil,
        joinedAt: Double? = nil,
        canSeeMyMessages: Bool = false,
        isCurrentUser: Bool = false
    ) {
        self.id = userId
        self.userId = userId
        self.nickname = nickname
        self.joinedAt = joinedAt
        self.canSeeMyMessages = canSeeMyMessages
        self.isCurrentUser = isCurrentUser
    }
    
    /// Display name for the participant
    var displayName: String {
        nickname ?? "User \(userId.prefix(8))"
    }
}

