//
//  MessageBubbleView.swift
//  SHAiny
//
//  Created by Сергей Вихляев on 26.10.2025.
//

import SwiftUI

/// Displays a single message bubble in a chat
/// Shows encrypted data, SHA hash, and decrypted message based on settings
struct MessageBubbleView: View {
    let message: Message
    let showEncryptedData: Bool
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            if message.isFromCurrentUser {
                Spacer(minLength: 60)
            }
            
            VStack(alignment: message.isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                // Sender name (only for messages from others)
                if !message.isFromCurrentUser, let senderName = message.senderName {
                    Text(senderName)
                        .font(.caption)
                        .foregroundColor(.purple.opacity(0.8))
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    if showEncryptedData {
                        // Encrypted text
                        ExpandableSHAView(
                            label: "Encrypted",
                            content: message.encryptedText,
                            isFromCurrentUser: message.isFromCurrentUser
                        )
                        
                        // SHA Hash
                        ExpandableSHAView(
                            label: "SHA-256",
                            content: message.shaHash,
                            isFromCurrentUser: message.isFromCurrentUser
                        )
                        
                        Divider()
                            .background(Color.white.opacity(0.2))
                            .padding(.vertical, 4)
                    }
                    
                    // Decrypted message text
                    Text(message.text)
                        .font(.body)
                        .foregroundColor(.white)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    message.isFromCurrentUser
                        ? LinearGradient(
                            colors: [Color.purple, Color.blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        : LinearGradient(
                            colors: [Color(red: 0.2, green: 0.2, blue: 0.22), Color(red: 0.2, green: 0.2, blue: 0.22)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                )
                .cornerRadius(18)
                .frame(maxWidth: UIScreen.main.bounds.width * 0.75, alignment: message.isFromCurrentUser ? .trailing : .leading)
                
                // Timestamp
                Text(formatTime(message.timestamp))
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            
            if !message.isFromCurrentUser {
                Spacer(minLength: 60)
            }
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    ZStack {
        Color(red: 0.1, green: 0.1, blue: 0.12)
            .ignoresSafeArea()
        
        VStack(spacing: 20) {
            MessageBubbleView(
                message: Message(
                    text: "Hello! This is a test message.",
                    encryptedText: "639f9e09635313572d18ba34:7bd2380447ad0ba40b71fa5fb8ea5cd65893e8722eb91fc02024d62fc9b60c8188ef8bec0d8",
                    shaHash: "0468699d3b3be251441ec0da5006e5143a0096b22e86326ca8a16bc5a248ae5b",
                    timestamp: Date(),
                    isFromCurrentUser: false,
                    senderName: "Alice"
                ),
                showEncryptedData: false
            )
            
            MessageBubbleView(
                message: Message(
                    text: "This is my response!",
                    encryptedText: "639f9e09635313572d18ba34:7bd2380447ad0ba40b71fa5fb8ea5cd65893e8722eb91fc02024d62fc9b60c8188ef8bec0d8",
                    shaHash: "0468699d3b3be251441ec0da5006e5143a0096b22e86326ca8a16bc5a248ae5b",
                    timestamp: Date(),
                    isFromCurrentUser: true,
                    senderName: "You"
                ),
                showEncryptedData: false
            )
        }
        .padding()
    }
}

