//
//  ChatListViewModel.swift
//  SHAiny
//
//  Created by Сергей Вихляев on 26.10.2025.
//

import Foundation
import Combine

final class ChatListViewModel: ObservableObject {
    @Driver var chats: [Chat] = []
    @Driver var showAlert: Bool = false
    @Driver var showConnectionView: Bool = false
    @Driver var isLoading: Bool = false
    @Driver var errorMessage: String?
    @Driver var connectionState: ChatConnectionState = .checking
    @Driver var isCreating: Bool = false
    @Driver var isJoining: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    private let chatService = ChatService.shared
    private let webSocketService = WebSocketService.shared
    
    // Разделенные чаты
    var globalChats: [Chat] {
        chats.filter { $0.isGlobal }
    }
    
    var privateChats: [Chat] {
        chats.filter { !$0.isGlobal }
    }
    
    init() {
        setupBindings()
        setupWebSocketListener()
        loadChats()
    }
    
    func loadChats(preserveIds: Bool = false, minDelay: TimeInterval = 0) {
        isLoading = true
        errorMessage = nil
        
        Task {
            let startTime = Date()
            
            do {
                let fetchedChats = try await chatService.fetchChats()
                
                // Добавляем минимальную задержку если нужно (для плавности pull-to-refresh)
                if minDelay > 0 {
                    let elapsed = Date().timeIntervalSince(startTime)
                    let remaining = minDelay - elapsed
                    if remaining > 0 {
                        try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
                    }
                }
                await MainActor.run {
                    if preserveIds {
                        // Сохраняем существующие UUID для плавной работы навигации
                        let updatedChats = fetchedChats.map { newChat in
                            if let existingChat = self.chats.first(where: { $0.chatId == newChat.chatId }) {
                                // Используем существующий UUID
                                return Chat(
                                    id: existingChat.id,
                                    chatId: newChat.chatId,
                                    name: newChat.name,
                                    lastMessage: newChat.lastMessage,
                                    lastMessageSender: newChat.lastMessageSender,
                                    timestamp: newChat.timestamp,
                                    participantsCount: newChat.participantsCount,
                                    isGlobal: newChat.isGlobal,
                                    isReadOnly: newChat.isReadOnly,
                                    encryptionKey: newChat.encryptionKey,
                                    hasCustomName: newChat.hasCustomName,
                                    unreadCount: newChat.unreadCount
                                )
                            } else {
                                return newChat
                            }
                        }
                        self.chats = self.sortChats(updatedChats)
                    } else {
                        self.chats = self.sortChats(fetchedChats)
                    }
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                    print("❌ Failed to load chats: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func sortChats(_ chats: [Chat]) -> [Chat] {
        return chats.sorted { chat1, chat2 in
            // Админский чат всегда первый
            if chat1.chatId == "global-announcements" {
                return true
            }
            if chat2.chatId == "global-announcements" {
                return false
            }
            
            // Остальные чаты сортируем по времени последнего сообщения
            return chat1.timestamp > chat2.timestamp
        }
    }
    
    private func setupBindings() {
        $chats
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        
        $showAlert
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        
        $showConnectionView
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        
        $isLoading
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        
        $errorMessage
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        
        $connectionState
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        
        $isCreating
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        
        $isJoining
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }
    
    private func setupWebSocketListener() {
        // Подписываемся на новые сообщения для обновления списка чатов
        webSocketService.newMessagePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (chatId, message) in
                guard let self = self else { return }
                
                print("🔄 New message received for chat: \(chatId), from current user: \(message.isFromCurrentUser)")
                
                self.updateChatPreview(chatId: chatId, message: message)
            }
            .store(in: &cancellables)
    }
    
    private func updateChatPreview(chatId: String, message: Message) {
        guard let index = self.chats.firstIndex(where: { $0.chatId == chatId }) else {
            // Если чата нет в списке, перезагружаем весь список
            print("🔄 New chat detected, reloading full list...")
            self.loadChats(preserveIds: true)
            return
        }
        
        let chat = self.chats[index]
        
        // Расшифровываем сообщение для preview
        var lastMessage = message.text
        if let encryptionKey = chat.encryptionKey {
            do {
                lastMessage = try CryptoUtils.decrypt(message.text, keyPhrase: encryptionKey)
            } catch {
                print("⚠️ Failed to decrypt preview: \(error.localizedDescription)")
            }
        }
        
        print("📝 Updating chat preview: \(chat.name)")
        print("   Last message: \(lastMessage.prefix(30))...")
        print("   Sender: \(message.senderName ?? "unknown")")
        print("   From current user: \(message.isFromCurrentUser)")
        
        // Определяем новый unreadCount
        let newUnreadCount = message.isFromCurrentUser ? chat.unreadCount : chat.unreadCount + 1
        
        // Обновляем чат с новым последним сообщением и временем
        let updatedChat = Chat(
            id: chat.id, // Сохраняем тот же UUID!
            chatId: chat.chatId,
            name: chat.name,
            lastMessage: lastMessage,
            lastMessageSender: message.senderName, // Добавляем отправителя
            timestamp: message.timestamp,
            participantsCount: chat.participantsCount,
            isGlobal: chat.isGlobal,
            isReadOnly: chat.isReadOnly,
            encryptionKey: chat.encryptionKey,
            hasCustomName: chat.hasCustomName,
            unreadCount: newUnreadCount
        )
        
        // КЛЮЧЕВОЕ: обновляем только конкретный элемент, не пересоздавая массив
        self.chats[index] = updatedChat
        
        // Сортируем только если это не админский чат и нужно изменить порядок
        if chat.chatId != "global-announcements" {
            // Проверяем, нужна ли пересортировка
            let needsReorder = index > 1 || (index == 1 && self.chats.first?.chatId == "global-announcements")
            
            if needsReorder {
                // Используем DispatchQueue.main.async для отложенной сортировки
                // Это позволяет избежать конфликтов с навигацией
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                    guard let self = self else { return }
                    let sortedChats = self.sortChats(self.chats)
                    
                    // Проверяем, действительно ли порядок изменился
                    let orderChanged = !zip(self.chats, sortedChats).allSatisfy { $0.chatId == $1.chatId }
                    
                    if orderChanged {
                        self.chats = sortedChats
                        print("✅ Chat list reordered")
                    }
                }
            }
        }
        
        print("✅ Chat preview updated locally")
    }
    
    func didTapNewChat() {
        showAlert = true
    }
    
    func checkAndConnect(keyPhrase: String) {
        showAlert = false
        showConnectionView = true
        connectionState = .checking
        
        Task {
            do {
                let keyHash = CryptoUtils.generateHash(keyPhrase)
                let result = try await chatService.checkChatExists(keyHash: keyHash)
                
                await MainActor.run {
                    if result.exists {
                        self.connectionState = .exists(chatId: result.chatId ?? "", chatName: result.chatName ?? "Unknown")
                    } else {
                        self.connectionState = .notExists
                    }
                }
            } catch {
                await MainActor.run {
                    self.connectionState = .error(error.localizedDescription)
                }
            }
        }
    }
    
    func createChat(keyPhrase: String) async -> String? {
        isCreating = true
        
        do {
            let keyHash = CryptoUtils.generateHash(keyPhrase)
            let newChat = try await chatService.createChat(keyPhrase: keyPhrase, keyHash: keyHash)
            
            // Сохраняем ключ локально
            ChatKeysStorage.shared.saveKey(keyPhrase, forChatId: newChat.chatId)
            
            await MainActor.run {
                self.chats.append(newChat)
                self.isCreating = false
                print("✅ Chat created: \(newChat.name)")
            }
            
            return newChat.chatId
        } catch {
            await MainActor.run {
                self.connectionState = .error(error.localizedDescription)
                self.isCreating = false
                print("❌ Failed to create chat: \(error.localizedDescription)")
            }
            return nil
        }
    }
    
    func markChatAsRead(chatId: String) {
        Task {
            do {
                try await chatService.markChatAsRead(chatId: chatId)
                
                // Обновляем локально сразу для быстрого отклика UI
                await MainActor.run {
                    if let index = self.chats.firstIndex(where: { $0.chatId == chatId }) {
                        let chat = self.chats[index]
                        let updatedChat = Chat(
                            id: chat.id,
                            chatId: chat.chatId,
                            name: chat.name,
                            lastMessage: chat.lastMessage,
                            timestamp: chat.timestamp,
                            participantsCount: chat.participantsCount,
                            isGlobal: chat.isGlobal,
                            isReadOnly: chat.isReadOnly,
                            encryptionKey: chat.encryptionKey,
                            hasCustomName: chat.hasCustomName,
                            unreadCount: 0
                        )
                        self.chats[index] = updatedChat
                    }
                }
                
                print("✅ Chat \(chatId) marked as read on backend")
            } catch {
                print("❌ Failed to mark chat as read: \(error.localizedDescription)")
            }
        }
    }
    
    func joinChat(chatId: String, keyPhrase: String) async -> String? {
        isJoining = true
        
        do {
            let chat = try await chatService.joinChat(chatId: chatId, keyPhrase: keyPhrase)
            
            // Сохраняем ключ локально
            ChatKeysStorage.shared.saveKey(keyPhrase, forChatId: chat.chatId)
            
            await MainActor.run {
                // Добавляем чат, если его еще нет
                if !self.chats.contains(where: { $0.chatId == chat.chatId }) {
                    self.chats.append(chat)
                }
                self.isJoining = false
                print("✅ Joined chat: \(chat.name)")
            }
            
            return chat.chatId
        } catch {
            await MainActor.run {
                self.connectionState = .error(error.localizedDescription)
                self.isJoining = false
                print("❌ Failed to join chat: \(error.localizedDescription)")
            }
            return nil
        }
    }
}

