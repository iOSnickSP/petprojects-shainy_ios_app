//
//  WebSocketService.swift
//  SHAiny
//
//  Created by Сергей Вихляев on 26.10.2025.
//

import Foundation
import Combine

enum WebSocketMessage: Codable {
    case auth(token: String)
    case sendMessage(chatId: String, encryptedText: String, shaHash: String)
    case refreshChats
}

struct IncomingWSMessage: Codable {
    let type: String
    let chatId: String?
    let message: MessageDTO?
    let error: String?
    let userId: String?
    
    struct MessageDTO: Codable {
        let id: String
        let userId: String?
        let senderName: String?
        let text: String
        let shaHash: String
        let timestamp: Double
        let replyTo: ReplyDTO?
        
        struct ReplyDTO: Codable {
            let messageId: String
            let text: String
            let senderName: String
            let timestamp: Double
        }
    }
}

class WebSocketService: NSObject, ObservableObject {
    static let shared = WebSocketService()
    
    private var webSocket: URLSessionWebSocketTask?
    
    private var baseURL: String {
        return SettingsService.shared.webSocketURL
    }
    
    @Published var isConnected = false
    @Published var connectionError: String?
    
    private let newMessageSubject = PassthroughSubject<(chatId: String, message: Message), Never>()
    var newMessagePublisher: AnyPublisher<(chatId: String, message: Message), Never> {
        newMessageSubject.eraseToAnyPublisher()
    }
    
    private let chatsUpdatedSubject = PassthroughSubject<Void, Never>()
    var chatsUpdatedPublisher: AnyPublisher<Void, Never> {
        chatsUpdatedSubject.eraseToAnyPublisher()
    }
    
    private override init() {
        super.init()
    }
    
    func connect() {
        guard let url = URL(string: baseURL) else {
            print("❌ Invalid WebSocket URL")
            return
        }
        
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: OperationQueue())
        webSocket = session.webSocketTask(with: url)
        webSocket?.resume()
        
        print("🔌 Connecting to WebSocket...")
        receiveMessage()
    }
    
    func disconnect() {
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
        isConnected = false
        print("🔌 WebSocket disconnected")
    }
    
    func authenticate() {
        guard let token = KeychainService.shared.getAccessToken() else {
            print("❌ No access token for WebSocket auth")
            return
        }
        
        let authMessage = ["type": "auth", "token": token]
        sendMessage(authMessage)
        print("🔐 Authenticating WebSocket...")
    }
    
    func sendChatMessage(chatId: String, encryptedText: String, shaHash: String, replyTo: [String: Any]? = nil) {
        guard isConnected else {
            print("❌ Cannot send message: WebSocket not connected!")
            return
        }
        
        var message: [String: Any] = [
            "type": "send_message",
            "chatId": chatId,
            "encryptedText": encryptedText,
            "shaHash": shaHash
        ]
        
        // Add reply information if present
        if let replyData = replyTo {
            message["replyTo"] = replyData
        }
        
        sendMessage(message)
        if replyTo != nil {
            print("📤 Sending reply to chat: \(chatId)")
        } else {
            print("📤 Sending message to chat: \(chatId)")
        }
    }
    
    func refreshChats() {
        let message = ["type": "refresh_chats"]
        sendMessage(message)
    }
    
    private func sendMessage(_ message: [String: Any]) {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: message),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            print("❌ Failed to serialize message")
            return
        }
        
        let message = URLSessionWebSocketTask.Message.string(jsonString)
        webSocket?.send(message) { error in
            if let error = error {
                print("❌ WebSocket send error: \(error.localizedDescription)")
            }
        }
    }
    
    private func receiveMessage() {
        webSocket?.receive { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self.handleMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self.handleMessage(text)
                    }
                @unknown default:
                    break
                }
                
                // Continue receiving messages
                self.receiveMessage()
                
            case .failure(let error):
                print("❌ WebSocket receive error: \(error.localizedDescription)")
                self.isConnected = false
                self.connectionError = error.localizedDescription
            }
        }
    }
    
    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }
        
        do {
            let incoming = try JSONDecoder().decode(IncomingWSMessage.self, from: data)
            
            DispatchQueue.main.async {
                switch incoming.type {
                case "auth_success":
                    self.isConnected = true
                    self.connectionError = nil
                    print("✅ WebSocket authenticated, userId: \(incoming.userId ?? "unknown")")
                    
                case "auth_error":
                    self.isConnected = false
                    self.connectionError = incoming.error
                    print("❌ WebSocket auth error: \(incoming.error ?? "unknown")")
                    
                case "new_message":
                    if let chatId = incoming.chatId, let messageDTO = incoming.message {
                        let message = self.convertToMessage(messageDTO)
                        self.newMessageSubject.send((chatId: chatId, message: message))
                        print("📩 New message received for chat: \(chatId)")
                        
                        // Показываем уведомление, если сообщение не от текущего пользователя
                        // и чат не открыт в данный момент
                        if !message.isFromCurrentUser {
                            // Получаем название чата для уведомления
                            self.showNotificationForMessage(
                                chatId: chatId,
                                message: message
                            )
                        }
                    }
                    
                case "chats_updated":
                    self.chatsUpdatedSubject.send()
                    print("🔄 Chats updated notification")
                    
                case "error":
                    print("❌ WebSocket error: \(incoming.error ?? "unknown")")
                    
                default:
                    print("⚠️ Unknown message type: \(incoming.type)")
                }
            }
        } catch {
            print("❌ Failed to decode WebSocket message: \(error.localizedDescription)")
        }
    }
    
    private func convertToMessage(_ dto: IncomingWSMessage.MessageDTO) -> Message {
        // Определяем, от текущего пользователя или нет
        let currentUserId = KeychainService.shared.getUserIdFromToken()
        let isFromCurrentUser = (dto.userId == currentUserId)
        
        // Convert reply DTO if present
        var replyTo: MessageReply? = nil
        if let replyDTO = dto.replyTo {
            replyTo = MessageReply(
                messageId: replyDTO.messageId,
                text: replyDTO.text,
                senderName: replyDTO.senderName,
                timestamp: Date(timeIntervalSince1970: replyDTO.timestamp / 1000)
            )
        }
        
        return Message(
            id: UUID(uuidString: dto.id) ?? UUID(),
            text: dto.text, // Encrypted text
            encryptedText: dto.text,
            shaHash: dto.shaHash,
            timestamp: Date(timeIntervalSince1970: dto.timestamp / 1000),
            isFromCurrentUser: isFromCurrentUser,
            senderName: dto.senderName,
            replyTo: replyTo
        )
    }
    
    private func showNotificationForMessage(chatId: String, message: Message) {
        // Получаем информацию о чате через ChatService
        Task {
            do {
                let chats = try await ChatService.shared.fetchChats()
                
                if let chat = chats.first(where: { $0.chatId == chatId }) {
                    // Расшифровываем текст сообщения для уведомления
                    var decryptedText = message.text
                    
                    if let encryptionKey = chat.encryptionKey {
                        do {
                            decryptedText = try CryptoUtils.decrypt(message.text, keyPhrase: encryptionKey)
                        } catch {
                            print("⚠️ Failed to decrypt message for notification: \(error.localizedDescription)")
                        }
                    }
                    
                    // Обрезаем длинные сообщения для preview
                    if decryptedText.count > 100 {
                        decryptedText = String(decryptedText.prefix(100)) + "..."
                    }
                    
                    // Показываем уведомление
                    await MainActor.run {
                        NotificationService.shared.showNewMessageNotification(
                            chatName: chat.name,
                            messageText: decryptedText,
                            chatId: chatId,
                            senderName: message.senderName
                        )
                    }
                }
            } catch {
                print("❌ Failed to fetch chat info for notification: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - URLSessionWebSocketDelegate
extension WebSocketService: URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        print("✅ WebSocket connected")
        DispatchQueue.main.async {
            self.authenticate()
        }
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        print("🔌 WebSocket closed with code: \(closeCode.rawValue)")
        DispatchQueue.main.async {
            self.isConnected = false
        }
    }
}

