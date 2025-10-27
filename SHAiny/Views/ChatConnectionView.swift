//
//  ChatConnectionView.swift
//  SHAiny
//
//  Created by Сергей Вихляев on 26.10.2025.
//

import SwiftUI

/// Modal view for connecting to or creating a chat via key phrase
struct ChatConnectionView: View {
    @ObservedObject var viewModel: ChatListViewModel
    @Environment(\.dismiss) var dismiss
    
    let keyPhrase: String
    
    @State private var showNamingDialog = false
    @State private var chatName = ""
    @State private var createdChatId: String?
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.1, green: 0.1, blue: 0.12)
                    .ignoresSafeArea()
                
                VStack(spacing: 32) {
                    Spacer()
                    
                    switch viewModel.connectionState {
                    case .checking:
                        checkingView
                        
                    case .exists(let chatId, let chatName):
                        chatExistsView(chatId: chatId, chatName: chatName)
                        
                    case .notExists:
                        chatNotExistsView
                        
                    case .error(let errorMessage):
                        errorView(message: errorMessage)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 32)
            }
            .navigationTitle("Connect to Chat")
            .navigationBarTitleDisplayMode(.inline)
            .preferredColorScheme(.dark)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .alert("Name This Chat", isPresented: $showNamingDialog) {
                TextField("Chat name", text: $chatName)
                    .textInputAutocapitalization(.words)
                
                Button("Skip", role: .cancel) {
                    chatName = ""
                    dismiss()
                }
                
                Button("Save") {
                    Task {
                        if let chatId = createdChatId, !chatName.isEmpty {
                            await renameChat(chatId: chatId, newName: chatName)
                        }
                        chatName = ""
                        dismiss()
                    }
                }
                .disabled(chatName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } message: {
                Text("Give this chat a memorable name. It will be encrypted and only visible to chat members.")
            }
        }
    }
    
    private func renameChat(chatId: String, newName: String) async {
        // Находим чат и переименовываем
        if let chat = viewModel.chats.first(where: { $0.chatId == chatId }),
           let encryptionKey = chat.encryptionKey {
            do {
                try await ChatService.shared.renameChat(
                    chatId: chatId,
                    newName: newName,
                    encryptionKey: encryptionKey
                )
                print("✅ Chat renamed successfully")
                
                // Обновляем список чатов
                await MainActor.run {
                    viewModel.loadChats(preserveIds: true)
                }
            } catch {
                print("❌ Failed to rename chat: \(error.localizedDescription)")
            }
        }
    }
    
    private var checkingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.5)
            
            Text("Checking for existing chat...")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
    }
    
    private func chatExistsView(chatId: String, chatName: String) -> some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.green, .blue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            VStack(spacing: 8) {
                Text("Chat Already Exists")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                
                Text("This chat is already active. Join to start messaging.")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: {
                Task {
                    await viewModel.joinChat(chatId: chatId, keyPhrase: keyPhrase)
                    
                    // После подключения проверяем - есть ли у чата кастомное имя
                    await MainActor.run {
                        if let chat = viewModel.chats.first(where: { $0.chatId == chatId }),
                           !chat.hasCustomName {
                            // Если имени нет - показываем диалог именования
                            createdChatId = chatId
                            showNamingDialog = true
                        } else {
                            // Если имя уже есть - просто закрываем sheet
                            dismiss()
                        }
                    }
                }
            }) {
                HStack {
                    if viewModel.isJoining {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Join Chat")
                            .font(.headline)
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    LinearGradient(
                        colors: [.green, .blue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
            }
            .disabled(viewModel.isJoining)
        }
    }
    
    private var chatNotExistsView: some View {
        VStack(spacing: 24) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.purple, .blue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            VStack(spacing: 8) {
                Text("Chat Doesn't Exist Yet")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                
                Text("No chat found with this key phrase. Create a new one?")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 12) {
                Button(action: {
                    Task {
                        let chatId = await viewModel.createChat(keyPhrase: keyPhrase)
                        
                        // После создания показываем диалог именования
                        if let chatId = chatId {
                            await MainActor.run {
                                createdChatId = chatId
                                showNamingDialog = true
                            }
                        } else {
                            dismiss()
                        }
                    }
                }) {
                    HStack {
                        if viewModel.isCreating {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Create Chat")
                                .font(.headline)
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                }
                .disabled(viewModel.isCreating)
                
                Button(action: {
                    dismiss()
                }) {
                    Text("Cancel")
                        .font(.headline)
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(red: 0.15, green: 0.15, blue: 0.17))
                        .cornerRadius(12)
                }
            }
        }
    }
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.red)
            
            VStack(spacing: 8) {
                Text("Error")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: {
                dismiss()
            }) {
                Text("Close")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .cornerRadius(12)
            }
        }
    }
}

