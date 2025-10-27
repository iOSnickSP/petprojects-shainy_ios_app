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
    let encryptionKey: String?
    let shouldShowTimestamp: Bool
    let shouldShowSenderName: Bool
    let onReply: ((Message) -> Void)?
    
    @State private var offset: CGFloat = 0
    @State private var isSwiping = false
    
    private let swipeThreshold: CGFloat = -50
    private let triggerHapticThreshold: CGFloat = -35
    @State private var hasTriggeredHaptic = false
    
    init(message: Message, showEncryptedData: Bool, encryptionKey: String? = nil, shouldShowTimestamp: Bool = true, shouldShowSenderName: Bool = true, onReply: ((Message) -> Void)? = nil) {
        self.message = message
        self.showEncryptedData = showEncryptedData
        self.encryptionKey = encryptionKey
        self.shouldShowTimestamp = shouldShowTimestamp
        self.shouldShowSenderName = shouldShowSenderName
        self.onReply = onReply
    }
    
    var body: some View {
        ZStack(alignment: .trailing) {
            // Reply icon that appears behind the message when swiping
            if onReply != nil && offset < -20 {
                HStack {
                    Spacer()
                    Image(systemName: "arrowshape.turn.up.left.fill")
                        .font(.title2)
                        .foregroundColor(.purple)
                        .opacity(min(1.0, Double(-offset / 60)))
                        .padding(.trailing, 20)
                }
            }
            
            HStack(alignment: .bottom, spacing: 0) {
                if message.isFromCurrentUser {
                    Spacer(minLength: 60)
                }
                
                VStack(alignment: message.isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                // Sender name (with "You" indicator for own messages, only if should show)
                if shouldShowSenderName, let senderName = message.senderName {
                    Text(message.isFromCurrentUser ? "\(senderName) (You)" : senderName)
                        .font(.caption)
                        .foregroundColor(.purple.opacity(0.8))
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    // Reply preview (if this message is a reply)
                    if let reply = message.replyTo {
                        replyPreviewView(reply: reply)
                    }
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
                
                // Timestamp (only if should show)
                if shouldShowTimestamp {
                    Text(formatTime(message.timestamp))
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
                
                if !message.isFromCurrentUser {
                    Spacer(minLength: 60)
                }
            }
            .offset(x: offset)
            .gesture(
                onReply != nil ? DragGesture(minimumDistance: 15)
                    .onChanged { gesture in
                        let translation = gesture.translation
                        
                        // Check if swipe is more horizontal than vertical
                        let isHorizontalSwipe = abs(translation.width) > abs(translation.height) * 1.5
                        
                        // Only allow left swipe that's clearly horizontal
                        if translation.width < 0 && isHorizontalSwipe {
                            offset = translation.width
                            isSwiping = true
                            
                            // Trigger haptic feedback when crossing threshold
                            if translation.width < triggerHapticThreshold && !hasTriggeredHaptic {
                                let generator = UIImpactFeedbackGenerator(style: .medium)
                                generator.impactOccurred()
                                hasTriggeredHaptic = true
                            }
                        }
                    }
                    .onEnded { gesture in
                        isSwiping = false
                        
                        // If swiped past threshold, trigger reply
                        if offset < swipeThreshold {
                            onReply?(message)
                            // Stronger haptic feedback
                            let generator = UIImpactFeedbackGenerator(style: .heavy)
                            generator.impactOccurred()
                        }
                        
                        // Animate back to original position
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            offset = 0
                            hasTriggeredHaptic = false
                        }
                    }
                : nil
            )
        }
    }
    
    // MARK: - Reply Preview
    
    @ViewBuilder
    private func replyPreviewView(reply: MessageReply) -> some View {
        HStack(alignment: .top, spacing: 6) {
            // Vertical line on the left
            Rectangle()
                .fill(Color.purple.opacity(0.8))
                .frame(width: 2)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(reply.senderName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.purple.opacity(0.9))
                
                Text(decryptReplyText(reply.text))
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.15))
        .cornerRadius(6)
    }
    
    private func decryptReplyText(_ text: String) -> String {
        // Пытаемся расшифровать (fallback если текст всё ещё зашифрован)
        guard let key = encryptionKey else {
            return text
        }
        
        // Проверяем, выглядит ли текст как зашифрованный (содержит ':')
        if text.contains(":") {
            do {
                return try CryptoUtils.decrypt(text, keyPhrase: key)
            } catch {
                // Если не удалось расшифровать, возвращаем как есть
                return text
            }
        }
        
        // Текст уже расшифрован
        return text
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
                showEncryptedData: false,
                encryptionKey: nil,
                shouldShowTimestamp: true,
                shouldShowSenderName: true,
                onReply: { message in
                    print("Reply to: \(message.text)")
                }
            )
            
            MessageBubbleView(
                message: Message(
                    text: "This is my response!",
                    encryptedText: "639f9e09635313572d18ba34:7bd2380447ad0ba40b71fa5fb8ea5cd65893e8722eb91fc02024d62fc9b60c8188ef8bec0d8",
                    shaHash: "0468699d3b3be251441ec0da5006e5143a0096b22e86326ca8a16bc5a248ae5b",
                    timestamp: Date(),
                    isFromCurrentUser: true,
                    senderName: "You",
                    replyTo: MessageReply(
                        messageId: "123",
                        text: "Hello! This is a test message.",
                        senderName: "Alice",
                        timestamp: Date().addingTimeInterval(-300)
                    )
                ),
                showEncryptedData: false,
                encryptionKey: nil,
                shouldShowTimestamp: true,
                shouldShowSenderName: true,
                onReply: { message in
                    print("Reply to: \(message.text)")
                }
            )
        }
        .padding()
    }
}

