//
//  ChatViewModel.swift
//  SHAiny
//
//  Created by Сергей Вихляев on 26.10.2025.
//

import Foundation
import Combine

final class ChatViewModel: ObservableObject {
    let chat: Chat
    
    @Driver var messages: [Message] = []
    @Driver var messageText: String = ""
    @Driver var participantsCount: Int = 0
    @Driver var isLoading: Bool = false
    @Driver var hasMoreMessages: Bool = false
    @Driver var chatName: String = ""
    @Published var shouldShowNicknameDialog: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    private let chatService = ChatService.shared
    private let webSocketService = WebSocketService.shared
    private var currentOffset = 0
    private let pageSize = 50
    private var pendingMessageText: String?
    
    var canSendMessages: Bool {
        return !chat.isReadOnly
    }
    
    init(chat: Chat) {
        self.chat = chat
        self.participantsCount = chat.participantsCount
        self.chatName = chat.name
        setupBindings()
        loadMessages()
        setupWebSocketListener()
    }
    
    private func setupBindings() {
        $messages
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        $messageText
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        $participantsCount
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        $isLoading
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        $hasMoreMessages
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        $chatName
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
    
    private func setupWebSocketListener() {
        // Подписываемся на новые сообщения через WebSocket
        webSocketService.newMessagePublisher
            .filter { [weak self] (chatId, _) in
                chatId == self?.chat.chatId
            }
            .sink { [weak self] (_, incomingMessage) in
                guard let self = self else { return }
                
                // Расшифровываем сообщение
                var decryptedText = incomingMessage.text
                
                if let encryptionKey = self.chat.encryptionKey {
                    do {
                        decryptedText = try CryptoUtils.decrypt(incomingMessage.text, keyPhrase: encryptionKey)
                    } catch {
                        print("❌ Failed to decrypt message: \(error.localizedDescription)")
                    }
                }
                
                // Создаем сообщение (isFromCurrentUser уже определен в WebSocketService)
                let message = Message(
                    id: incomingMessage.id,
                    text: decryptedText,
                    encryptedText: incomingMessage.encryptedText,
                    shaHash: incomingMessage.shaHash,
                    timestamp: incomingMessage.timestamp,
                    isFromCurrentUser: incomingMessage.isFromCurrentUser,
                    senderName: incomingMessage.senderName
                )
                
                // Проверяем, нет ли уже этого сообщения в списке
                if !self.messages.contains(where: { $0.id == message.id }) {
                    self.messages.append(message)
                    print("📩 New message added to chat \(self.chat.name)")
                }
            }
            .store(in: &cancellables)
    }
    
    private func loadMessages(reset: Bool = true) {
        if reset {
            currentOffset = 0
        }
        
        isLoading = true
        
        Task {
            do {
                let result = try await chatService.fetchMessages(
                    chatId: chat.chatId,
                    encryptionKey: chat.encryptionKey,
                    limit: pageSize,
                    offset: currentOffset
                )
                
                await MainActor.run {
                    if reset {
                        self.messages = result.messages
                    } else {
                        self.messages.insert(contentsOf: result.messages, at: 0)
                    }
                    self.hasMoreMessages = result.hasMore
                    self.currentOffset += result.messages.count
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    print("❌ Failed to load messages: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func loadMoreMessages() {
        guard !isLoading && hasMoreMessages else { return }
        loadMessages(reset: false)
    }
    
    func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        let textToSend = messageText
        
        // Проверяем, есть ли никнейм пользователя в этом чате
        Task {
            do {
                let nickname = try await chatService.getNickname(for: chat.chatId)
                
                if nickname == nil {
                    // Если никнейма нет, сохраняем сообщение и показываем диалог
                    await MainActor.run {
                        self.pendingMessageText = textToSend
                        // НЕ очищаем messageText - оставляем в поле ввода
                        self.shouldShowNicknameDialog = true
                    }
                    return
                }
                
                // Если никнейм есть, очищаем поле и отправляем сообщение
                await MainActor.run {
                    self.messageText = ""
                }
                
                await sendMessageInternal(textToSend)
            } catch {
                await MainActor.run {
                    print("❌ Failed to check nickname: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func sendMessageInternal(_ textToSend: String) async {
        do {
            // Шифруем сообщение
            var encryptedText = textToSend
            if let encryptionKey = chat.encryptionKey {
                encryptedText = try CryptoUtils.encrypt(textToSend, keyPhrase: encryptionKey)
            }
            
            // Генерируем SHA hash от оригинального текста
            let shaHash = CryptoUtils.generateHash(textToSend)
            
            // Отправляем через WebSocket
            webSocketService.sendChatMessage(
                chatId: chat.chatId,
                encryptedText: encryptedText,
                shaHash: shaHash
            )
            
            print("📤 Message sent to chat: \(chat.name)")
        } catch {
            await MainActor.run {
                print("❌ Failed to send message: \(error.localizedDescription)")
                // Возвращаем текст обратно в поле ввода при ошибке
                self.messageText = textToSend
            }
        }
    }
    
    func updateParticipantsCount(_ count: Int) {
        participantsCount = count
    }
    
    func renameChat(newName: String) async -> Bool {
        guard let encryptionKey = chat.encryptionKey else {
            print("❌ No encryption key for chat")
            return false
        }
        
        do {
            try await chatService.renameChat(chatId: chat.chatId, newName: newName, encryptionKey: encryptionKey)
            
            // Обновляем название локально
            await MainActor.run {
                self.chatName = newName
            }
            
            print("✅ Chat renamed to: \(newName)")
            return true
        } catch {
            print("❌ Failed to rename chat: \(error.localizedDescription)")
            return false
        }
    }
    
    // Установить никнейм пользователя в этом чате
    func setNickname(_ nickname: String) async -> Bool {
        guard !nickname.isEmpty else { return false }
        
        do {
            try await chatService.setNickname(nickname, for: chat.chatId)
            print("✅ Nickname set to: \(nickname)")
            
            // После успешной установки никнейма отправляем отложенное сообщение
            if let pendingText = pendingMessageText {
                await MainActor.run {
                    self.pendingMessageText = nil
                    self.messageText = "" // Теперь очищаем поле
                }
                await sendMessageInternal(pendingText)
            }
            
            return true
        } catch {
            print("❌ Failed to set nickname: \(error.localizedDescription)")
            return false
        }
    }
    
    // Отменить отправку сообщения
    func cancelPendingMessage() {
        pendingMessageText = nil
        // messageText остается как есть - не очищаем
    }
}

