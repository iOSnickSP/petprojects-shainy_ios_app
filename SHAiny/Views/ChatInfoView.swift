//
//  ChatInfoView.swift
//  SHAiny
//
//  Created by AI Assistant on 26.10.2025.
//

import SwiftUI

struct ChatInfoView: View {
    let chat: Chat
    @Binding var isPresented: Bool
    @State private var isKeyPhraseVisible = false
    @State private var showRenameDialog = false
    @State private var newChatName = ""
    @State private var keyPhraseCopied = false
    @State private var isRenaming = false
    
    let onChatRenamed: (() -> Void)?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Chat Name Section
                    chatNameSection
                    
                    Divider()
                        .background(Color.gray.opacity(0.3))
                    
                    // Key Phrase Section
                    if let keyPhrase = chat.encryptionKey {
                        keyPhraseSection(keyPhrase: keyPhrase)
                        
                        Divider()
                            .background(Color.gray.opacity(0.3))
                    }
                    
                    // Chat Info Section
                    chatInfoSection
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
            .background(Color(red: 0.1, green: 0.1, blue: 0.12))
            .navigationTitle("Chat Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                    .foregroundColor(.blue)
                }
            }
        }
        .preferredColorScheme(.dark)
        .alert("Rename Chat", isPresented: $showRenameDialog) {
            TextField("New name", text: $newChatName)
                .textInputAutocapitalization(.words)
            
            Button("Cancel", role: .cancel) {
                newChatName = ""
            }
            
            Button("Save") {
                Task {
                    await renameChat()
                }
            }
            .disabled(newChatName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isRenaming)
        } message: {
            Text("Enter a new name for this chat. It will be encrypted and only visible to chat members.")
        }
    }
    
    private var chatNameSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Chat Name")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                if !chat.isGlobal {
                    Button(action: {
                        newChatName = chat.name
                        showRenameDialog = true
                    }) {
                        Text("Edit")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    }
                }
            }
            
            HStack {
                Image(systemName: chat.isGlobal ? "globe" : "lock.fill")
                    .foregroundColor(.purple)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(chat.name)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    if chat.isGlobal {
                        Text("Global Chat")
                            .font(.caption)
                            .foregroundColor(.gray)
                    } else if chat.hasCustomName {
                        Text("Encrypted name")
                            .font(.caption)
                            .foregroundColor(.green)
                    } else {
                        Text("Default name")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
            }
            .padding(16)
            .background(Color(red: 0.15, green: 0.15, blue: 0.17))
            .cornerRadius(12)
        }
    }
    
    private func keyPhraseSection(keyPhrase: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Encryption Key")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Image(systemName: "key.fill")
                    .foregroundColor(.yellow)
            }
            
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                    
                    Text("Keep this secret! Anyone with this key can read your messages.")
                        .font(.caption)
                        .foregroundColor(.orange)
                    
                    Spacer()
                }
                .padding(12)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(isKeyPhraseVisible ? keyPhrase : String(repeating: "•", count: keyPhrase.count))
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.white)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Spacer()
                    }
                    
                    HStack(spacing: 16) {
                        Button(action: {
                            withAnimation {
                                isKeyPhraseVisible.toggle()
                            }
                        }) {
                            HStack {
                                Image(systemName: isKeyPhraseVisible ? "eye.slash.fill" : "eye.fill")
                                Text(isKeyPhraseVisible ? "Hide" : "Show")
                            }
                            .font(.subheadline)
                            .foregroundColor(.blue)
                        }
                        
                        Button(action: {
                            UIPasteboard.general.string = keyPhrase
                            keyPhraseCopied = true
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                keyPhraseCopied = false
                            }
                        }) {
                            HStack {
                                Image(systemName: keyPhraseCopied ? "checkmark" : "doc.on.doc")
                                Text(keyPhraseCopied ? "Copied!" : "Copy")
                            }
                            .font(.subheadline)
                            .foregroundColor(keyPhraseCopied ? .green : .blue)
                        }
                    }
                }
                .padding(16)
                .background(Color(red: 0.15, green: 0.15, blue: 0.17))
                .cornerRadius(12)
            }
        }
    }
    
    private var chatInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Chat Information")
                .font(.headline)
                .foregroundColor(.white)
            
            VStack(spacing: 0) {
                InfoRow(
                    icon: "person.2.fill",
                    title: "Participants",
                    value: "\(chat.participantsCount)"
                )
                
                Divider()
                    .background(Color.gray.opacity(0.2))
                    .padding(.leading, 44)
                
                InfoRow(
                    icon: "calendar",
                    title: "Created",
                    value: formatDate(chat.timestamp)
                )
                
                if chat.isReadOnly {
                    Divider()
                        .background(Color.gray.opacity(0.2))
                        .padding(.leading, 44)
                    
                    InfoRow(
                        icon: "lock.fill",
                        title: "Status",
                        value: "Read Only"
                    )
                }
            }
            .background(Color(red: 0.15, green: 0.15, blue: 0.17))
            .cornerRadius(12)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func renameChat() async {
        guard !newChatName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let encryptionKey = chat.encryptionKey else {
            return
        }
        
        isRenaming = true
        
        do {
            try await ChatService.shared.renameChat(
                chatId: chat.chatId,
                newName: newChatName,
                encryptionKey: encryptionKey
            )
            
            await MainActor.run {
                newChatName = ""
                isRenaming = false
                
                // Уведомляем об успешном переименовании
                onChatRenamed?()
                
                // Закрываем шторку после небольшой задержки
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isPresented = false
                }
            }
            
            print("✅ Chat renamed successfully")
        } catch {
            await MainActor.run {
                isRenaming = false
                print("❌ Failed to rename chat: \(error.localizedDescription)")
            }
        }
    }
}

struct InfoRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.purple)
                .frame(width: 28)
            
            Text(title)
                .foregroundColor(.gray)
            
            Spacer()
            
            Text(value)
                .foregroundColor(.white)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

#Preview {
    ChatInfoView(
        chat: Chat(
            id: UUID(),
            chatId: "test",
            name: "Test Chat",
            lastMessage: nil,
            timestamp: Date(),
            participantsCount: 5,
            encryptionKey: "super-secret-key-phrase-123"
        ),
        isPresented: .constant(true),
        onChatRenamed: nil
    )
}

