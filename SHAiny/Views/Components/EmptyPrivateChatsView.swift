//
//  EmptyPrivateChatsView.swift
//  SHAiny
//
//  Created by Сергей Вихляев on 26.10.2025.
//

import SwiftUI

/// Displays an informative message when the user has no private chats yet
/// Provides instructions on how to create or join a chat
struct EmptyPrivateChatsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.title)
                    .foregroundColor(.purple.opacity(0.7))
                
                Text("No Private Chats Yet")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            
            Text("Here you can have secure end-to-end encrypted conversations. To join an existing chat or create a new one, tap the button below.")
                .font(.subheadline)
                .foregroundColor(.gray)
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(nil)
            
            HStack {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(.purple)
                Text("Add SHAiny Chat")
                    .font(.subheadline)
                    .foregroundColor(.purple)
            }
            .padding(.top, 4)
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    ZStack {
        Color(red: 0.15, green: 0.15, blue: 0.17)
            .ignoresSafeArea()
        
        EmptyPrivateChatsView()
            .padding()
    }
}

