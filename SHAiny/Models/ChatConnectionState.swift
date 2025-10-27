//
//  ChatConnectionState.swift
//  SHAiny
//
//  Created by Сергей Вихляев on 26.10.2025.
//

import Foundation

/// Represents the state of connecting to/creating a chat via key phrase
enum ChatConnectionState {
    /// Checking if a chat with this key phrase exists
    case checking
    
    /// Chat exists and user can join
    /// - Parameters:
    ///   - chatId: The ID of the existing chat
    ///   - chatName: The name of the existing chat
    case exists(chatId: String, chatName: String)
    
    /// No chat exists with this key phrase, user can create one
    case notExists
    
    /// An error occurred during the check
    /// - Parameter message: Error message to display
    case error(String)
}

