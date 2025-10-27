//
//  ChatView.swift
//  SHAiny
//
//  Created by Сергей Вихляев on 26.10.2025.
//

import SwiftUI

struct ChatView: View {
    @StateObject private var viewModel: ChatViewModel
    @FocusState private var isInputFocused: Bool
    @State private var keyboardHeight: CGFloat = 0
    @State private var showRenameDialog = false
    @State private var newChatName = ""
    @State private var showNicknameDialog = false
    @State private var nickname = ""
    @State private var showEncryptedData: Bool = SettingsService.shared.showEncryptedData
    @State private var showChatInfo = false
    
    let onAppear: (() -> Void)?
    let onChatRenamed: (() -> Void)?
    
    init(chat: Chat, onAppear: (() -> Void)? = nil, onChatRenamed: (() -> Void)? = nil) {
        _viewModel = StateObject(wrappedValue: ChatViewModel(chat: chat))
        self.onAppear = onAppear
        self.onChatRenamed = onChatRenamed
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Participants header
            participantsHeader
            
            Divider()
                .background(Color.gray.opacity(0.3))
            
            // Key sharing prompt (если есть участники без ключа и это не read-only чат)
            if !viewModel.participantsWithoutKey.isEmpty && !viewModel.chat.isReadOnly {
                keySharePromptView
            }
            
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(Array(viewModel.messages.enumerated()), id: \.element.id) { index, message in
                            MessageBubbleView(
                                message: message,
                                showEncryptedData: showEncryptedData,
                                encryptionKey: viewModel.chat.encryptionKey,
                                shouldShowTimestamp: shouldShowTimestamp(for: message, at: index),
                                shouldShowSenderName: shouldShowSenderName(for: message, at: index),
                                onReply: { replyMessage in
                                    viewModel.setReply(to: replyMessage)
                                    isInputFocused = true
                                }
                            )
                            .id(message.id)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .padding(.bottom, keyboardHeight > 0 ? keyboardHeight - 100 : 0)
                }
                .contentShape(Rectangle())
                .simultaneousGesture(
                    DragGesture(minimumDistance: 20)
                        .onChanged { gesture in
                            // Hide keyboard on downward swipe
                            if gesture.translation.height > 10 {
                                isInputFocused = false
                            }
                        }
                )
                .onTapGesture {
                    isInputFocused = false
                }
                .onChange(of: viewModel.messages.count) { _ in
                    scrollToBottom(proxy: proxy)
                }
                .onChange(of: keyboardHeight) { _ in
                    if keyboardHeight > 0 {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            scrollToBottom(proxy: proxy)
                        }
                    }
                }
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        scrollToBottom(proxy: proxy, animated: false)
                    }
                    setupKeyboardObservers()
                }
                .onDisappear {
                    removeKeyboardObservers()
                }
            }
            
            // Input area
            if viewModel.canSendMessages {
                messageInputView
            } else {
                readOnlyNotice
            }
        }
        .background(Color(red: 0.1, green: 0.1, blue: 0.12))
        .navigationTitle(viewModel.chatName)
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showChatInfo = true
                }) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                }
            }
        }
        .sheet(isPresented: $showChatInfo) {
            ChatInfoView(
                chat: viewModel.chat,
                isPresented: $showChatInfo,
                onChatRenamed: {
                    // Обновляем список чатов
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        onChatRenamed?()
                    }
                }
            )
        }
        .onAppear {
            // Отслеживаем текущий открытый чат
            NotificationService.shared.currentOpenChatId = viewModel.chat.chatId
            // Очищаем уведомления для этого чата
            NotificationService.shared.clearNotifications(for: viewModel.chat.chatId)
            // Вызываем callback для пометки чата как прочитанного
            onAppear?()
            
            // Загружаем актуальные настройки отображения
            showEncryptedData = SettingsService.shared.showEncryptedData
        }
        .onDisappear {
            // Сбрасываем текущий открытый чат
            NotificationService.shared.currentOpenChatId = nil
        }
        .alert("Name This Chat", isPresented: $showRenameDialog) {
            TextField("Chat name", text: $newChatName)
                .textInputAutocapitalization(.words)
            
            Button("Skip", role: .cancel) {
                newChatName = ""
            }
            
            Button("Save") {
                Task {
                    let success = await viewModel.renameChat(newName: newChatName)
                    if success {
                        await MainActor.run {
                            newChatName = ""
                        }
                        // Обновляем список чатов с большой задержкой
                        // чтобы пользователь остался в чате
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            onChatRenamed?()
                        }
                    }
                }
            }
            .disabled(newChatName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } message: {
            Text("Give this chat a memorable name. It will be encrypted and only visible to chat members.")
        }
        .alert("Your Nickname Required", isPresented: $showNicknameDialog) {
            TextField("Nickname", text: $nickname)
                .textInputAutocapitalization(.words)
            
            Button("Cancel", role: .cancel) {
                nickname = ""
                viewModel.cancelPendingMessage()
            }
            
            Button("Save for here") {
                Task {
                    let success = await viewModel.setNickname(nickname)
                    await MainActor.run {
                        nickname = ""
                        if !success {
                            // Если не удалось установить никнейм, возвращаем текст в поле
                            showNicknameDialog = true
                        }
                    }
                }
            }
            .disabled(nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } message: {
            Text("Set a nickname to send messages in this chat. Other participants will see this name.")
        }
        .onChange(of: viewModel.shouldShowNicknameDialog) { shouldShow in
            if shouldShow {
                showNicknameDialog = true
                viewModel.shouldShowNicknameDialog = false
            }
        }
    }
    
    private var participantsHeader: some View {
        HStack {
            Image(systemName: "person.2.fill")
                .font(.caption)
                .foregroundColor(.gray)
            
            // Показываем предупреждение только если это не read-only чат
            if viewModel.participantsWithoutKey.isEmpty || viewModel.chat.isReadOnly {
                Text("\(viewModel.participantsCount) participants")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            } else {
                let withoutKeyCount = viewModel.participantsWithoutKey.count
                let pluralSuffix = withoutKeyCount == 1 ? "" : "s"
                Text("\(viewModel.participantsCount) participants (\(withoutKeyCount) does not see your message\(pluralSuffix))")
                    .font(.subheadline)
                    .foregroundColor(.orange)
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(red: 0.15, green: 0.15, blue: 0.17))
    }
    
    private var keySharePromptView: some View {
        VStack(spacing: 0) {
            ForEach(viewModel.participantsWithoutKey) { participant in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        Image(systemName: "key.fill")
                            .foregroundColor(.orange)
                            .font(.subheadline)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Share your messages with \(participant.displayName)?")
                                .font(.subheadline)
                                .foregroundColor(.white)
                            
                            Text("They joined after you and can't see your messages yet")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                    }
                    
                    HStack(spacing: 12) {
                        Button(action: {
                            // Decline - просто скрываем для этого участника
                            // В идеале можно сохранить это решение локально
                        }) {
                            Text("No")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 8)
                                .background(Color(red: 0.2, green: 0.2, blue: 0.22))
                                .cornerRadius(8)
                        }
                        
                        Button(action: {
                            viewModel.shareKey(with: participant)
                        }) {
                            Text("Yes, Share")
                                .font(.subheadline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 8)
                                .background(
                                    LinearGradient(
                                        colors: [Color.purple, Color.blue],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(8)
                        }
                    }
                }
                .padding(12)
                .background(Color.orange.opacity(0.1))
                .overlay(
                    Rectangle()
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
            }
        }
    }
    
    private var readOnlyNotice: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.fill")
                .foregroundColor(.gray)
            Text("This is a read-only channel")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(red: 0.15, green: 0.15, blue: 0.17))
    }
    
    private var messageInputView: some View {
        VStack(spacing: 0) {
            // Reply preview (if replying to a message)
            if let replyingTo = viewModel.replyingTo {
                replyPreviewBar(message: replyingTo)
            }
            
            // Input field
            HStack(spacing: 12) {
                TextField("Message", text: $viewModel.messageText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(Color(red: 0.15, green: 0.15, blue: 0.17))
                    .cornerRadius(20)
                    .lineLimit(1...6)
                    .focused($isInputFocused)
                    .foregroundColor(.white)
                
                Button(action: {
                    viewModel.sendMessage()
                }) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(viewModel.messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : .blue)
                }
                .disabled(viewModel.messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(red: 0.1, green: 0.1, blue: 0.12))
    }
    
    @ViewBuilder
    private func replyPreviewBar(message: Message) -> some View {
        HStack(spacing: 6) {
            // Vertical line indicator
            Rectangle()
                .fill(Color.purple)
                .frame(width: 2)
            
            VStack(alignment: .leading, spacing: 0) {
                Text("\(message.senderName ?? "Unknown")")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.purple)
                
                Text(message.text)
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Button(action: {
                viewModel.cancelReply()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.gray)
            }
        }
        .frame(height: 40)
        .padding(.horizontal, 10)
        .background(Color(red: 0.15, green: 0.15, blue: 0.17))
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
    
    private func shouldShowTimestamp(for message: Message, at index: Int) -> Bool {
        // Всегда показываем timestamp для последнего сообщения
        guard index < viewModel.messages.count - 1 else { return true }
        
        let nextMessage = viewModel.messages[index + 1]
        
        // Если следующее сообщение от другого пользователя - показываем timestamp
        if message.senderName != nextMessage.senderName {
            return true
        }
        
        // Если разница между сообщениями больше 1 минуты - показываем timestamp
        let timeDifference = nextMessage.timestamp.timeIntervalSince(message.timestamp)
        return timeDifference >= 60
    }
    
    private func shouldShowSenderName(for message: Message, at index: Int) -> Bool {
        // Всегда показываем имя для первого сообщения
        guard index > 0 else { return true }
        
        let previousMessage = viewModel.messages[index - 1]
        
        // Если предыдущее сообщение от другого пользователя - показываем имя
        if message.senderName != previousMessage.senderName {
            return true
        }
        
        // Если разница с предыдущим сообщением больше 1 минуты - показываем имя
        let timeDifference = message.timestamp.timeIntervalSince(previousMessage.timestamp)
        return timeDifference >= 60
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy, animated: Bool = true) {
        guard let lastMessage = viewModel.messages.last else { return }
        if animated {
            withAnimation {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        } else {
            proxy.scrollTo(lastMessage.id, anchor: .bottom)
        }
    }
    
    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil,
            queue: .main
        ) { notification in
            guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
            withAnimation(.easeOut(duration: 0.25)) {
                keyboardHeight = keyboardFrame.height
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { _ in
            withAnimation(.easeOut(duration: 0.25)) {
                keyboardHeight = 0
            }
        }
    }
    
    private func removeKeyboardObservers() {
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }
}

#Preview {
    NavigationView {
        ChatView(chat: Chat(
            id: UUID(),
            chatId: "",
            name: "Test Chat",
            lastMessage: nil,
            timestamp: Date(),
            participantsCount: 5
        ))
    }
}

