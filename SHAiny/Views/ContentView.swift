//
//  ContentView.swift
//  SHAiny
//
//  Created by Сергей Вихляев on 26.10.2025.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ChatListViewModel()
    @State private var keyPhrase = ""
    @State private var navigationToChatId: String? = nil
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.1, green: 0.1, blue: 0.12)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    if viewModel.isLoading && viewModel.chats.isEmpty {
                        // Показываем loading только если чатов еще нет (первая загрузка)
                        loadingView
                    } else if let error = viewModel.errorMessage {
                        errorView(error: error)
                    } else if viewModel.chats.isEmpty {
                        emptyStateView
                    } else {
                        chatListView
                    }
                    
                    Spacer()
                    
                    newChatButton
                }
            }
            .navigationTitle("SHAiny")
            .navigationBarTitleDisplayMode(.large)
            .preferredColorScheme(.dark)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: ProfileView()) {
                        Image(systemName: "person.circle.fill")
                            .font(.title2)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.purple, .blue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }
                }
            }
            .alert("Enter Key Phrase", isPresented: $viewModel.showAlert) {
                TextField("Key phrase", text: $keyPhrase)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                
                Button("Cancel", role: .cancel) {
                    keyPhrase = ""
                }
                
                Button("Connect") {
                    if !keyPhrase.isEmpty {
                        viewModel.checkAndConnect(keyPhrase: keyPhrase)
                        let savedPhrase = keyPhrase
                        keyPhrase = ""
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            keyPhrase = savedPhrase
                        }
                    }
                }
            }
            .sheet(isPresented: $viewModel.showConnectionView) {
                ChatConnectionView(viewModel: viewModel, keyPhrase: keyPhrase)
                    .onDisappear {
                        keyPhrase = ""
                    }
            }
            .onAppear {
                // Подписываемся на уведомления о навигации из push-уведомлений
                NotificationCenter.default.addObserver(
                    forName: NSNotification.Name("NavigateToChat"),
                    object: nil,
                    queue: .main
                ) { notification in
                    if let chatId = notification.userInfo?["chatId"] as? String {
                        // Ищем чат по ID
                        if viewModel.chats.first(where: { $0.chatId == chatId }) != nil {
                            navigationToChatId = chatId
                        } else {
                            // Если чат не найден, перезагружаем список
                            viewModel.loadChats()
                        }
                    }
                }
            }
        }
    }
    
    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.5)
            Text("Loading chats...")
                .font(.subheadline)
                .foregroundColor(.gray)
                .padding(.top, 16)
            Spacer()
        }
    }
    
    private func errorView(error: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.red)
            Text("Error")
                .font(.title2)
                .foregroundColor(.white)
            Text(error)
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Retry") {
                viewModel.loadChats()
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(12)
            Spacer()
        }
    }
    
    private var emptyStateView: some View {
        VStack {
            Spacer()
            Text("No chats yet")
                .font(.title2)
                .foregroundColor(.gray)
            Spacer()
        }
    }
    
    private var chatListView: some View {
        ZStack {
            List {
                // Global chats section
                if !viewModel.globalChats.isEmpty {
                    Section {
                        ForEach(viewModel.globalChats) { chat in
                            NavigationLink(destination: ChatView(
                                chat: chat,
                                onAppear: {
                                    viewModel.markChatAsRead(chatId: chat.chatId)
                                },
                                onChatRenamed: {
                                    viewModel.loadChats(preserveIds: true)
                                }
                            )) {
                                ChatRowView(chat: chat)
                            }
                            .listRowBackground(Color(red: 0.15, green: 0.15, blue: 0.17))
                        }
                    }
                }
                
                // Private chats section
                Section(header: Text("Private Chats").font(.caption).foregroundColor(.gray)) {
                    if viewModel.privateChats.isEmpty {
                        // Показываем инструкцию когда чатов нет
                        EmptyPrivateChatsView()
                            .listRowBackground(Color(red: 0.15, green: 0.15, blue: 0.17))
                    } else {
                        ForEach(viewModel.privateChats) { chat in
                            NavigationLink(destination: ChatView(
                                chat: chat,
                                onAppear: {
                                    viewModel.markChatAsRead(chatId: chat.chatId)
                                },
                                onChatRenamed: {
                                    viewModel.loadChats(preserveIds: true)
                                }
                            )) {
                                ChatRowView(chat: chat)
                            }
                            .listRowBackground(Color(red: 0.15, green: 0.15, blue: 0.17))
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .refreshable {
                viewModel.loadChats(preserveIds: true, minDelay: 2.0)
            }
            
            // Скрытый NavigationLink для программной навигации из уведомлений
            if let chatId = navigationToChatId,
               let chat = viewModel.chats.first(where: { $0.chatId == chatId }) {
                NavigationLink(
                    destination: ChatView(
                        chat: chat,
                        onAppear: {
                            viewModel.markChatAsRead(chatId: chat.chatId)
                        },
                        onChatRenamed: {
                            viewModel.loadChats(preserveIds: true)
                        }
                    ),
                    isActive: .constant(true)
                ) {
                    EmptyView()
                }
                .hidden()
                .onAppear {
                    // Сбрасываем navigationToChatId после навигации
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        navigationToChatId = nil
                    }
                }
            }
        }
    }
    
    private var newChatButton: some View {
        Button(action: {
            viewModel.didTapNewChat()
        }) {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                Text("Add SHAiny Chat")
                    .font(.headline)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                LinearGradient(
                    colors: [Color.purple, Color.blue],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }
}

#Preview {
    ContentView()
}
