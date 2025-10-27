//
//  ChatRowView.swift
//  SHAiny
//
//  Created by Сергей Вихляев on 26.10.2025.
//

import SwiftUI

/// Displays a single chat row in the chat list
/// Has different designs for global announcement channels vs private chats
struct ChatRowView: View {
    let chat: Chat
    
    var body: some View {
        if chat.isGlobal {
            globalChatRow
        } else {
            regularChatRow
        }
    }
    
    // MARK: - Global Chat Row (Announcements)
    
    /// Special design for the global announcements channel
    private var globalChatRow: some View {
        HStack(spacing: 12) {
            // Icon with gradient
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.purple.opacity(0.3), .blue.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                
                Image(systemName: "megaphone.fill")
                    .font(.title3)
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(chat.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    if chat.isReadOnly {
                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                Text("\(chat.participantsCount) members")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // Unread indicator
            if chat.unreadCount > 0 {
                Text("\(chat.unreadCount)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        LinearGradient(
                            colors: [.orange, .red],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(12)
            }
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Private Chat Row
    
    /// Standard design for private encrypted chats
    private var regularChatRow: some View {
        HStack(spacing: 12) {
            // Chat icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.purple.opacity(0.3), Color.blue.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                
                Image(systemName: "lock.fill")
                    .font(.body)
                    .foregroundColor(.purple.opacity(0.8))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(chat.name)
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                // Show "UserName left last message" or "No messages yet"
                if let sender = chat.lastMessageSender {
                    Text("\(sender) left last message")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                } else {
                    Text("No messages yet")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Unread badge
            if chat.unreadCount > 0 {
                Text("\(chat.unreadCount)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        LinearGradient(
                            colors: [Color.purple, Color.blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(12)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ZStack {
        Color(red: 0.1, green: 0.1, blue: 0.12)
            .ignoresSafeArea()
        
        VStack(spacing: 16) {
            ChatRowView(chat: Chat(
                chatId: "test-1",
                name: "Announcements",
                lastMessage: "Welcome!",
                timestamp: Date(),
                participantsCount: 42,
                isGlobal: true,
                isReadOnly: true,
                unreadCount: 3
            ))
            
            ChatRowView(chat: Chat(
                chatId: "test-2",
                name: "Private Chat",
                lastMessage: "Hello there",
                lastMessageSender: "Alice",
                timestamp: Date(),
                participantsCount: 5,
                unreadCount: 1
            ))
        }
        .padding()
    }
}

