//
//  DisplaySettingsView.swift
//  SHAiny
//
//  Created by Сергей Вихляев on 26.10.2025.
//

import SwiftUI

struct DisplaySettingsView: View {
    @State private var showEncryptedData: Bool = SettingsService.shared.showEncryptedData
    
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Message Preview")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    // Пример сообщения с включенными данными
                    MessagePreview(showEncryptedData: showEncryptedData)
                }
                .padding(.vertical, 8)
            } header: {
                Text("Preview")
                    .foregroundColor(.gray)
            }
            .listRowBackground(Color(red: 0.15, green: 0.15, blue: 0.17))
            
            Section {
                Toggle(isOn: $showEncryptedData.animation(.easeInOut(duration: 0.3))) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Show Encrypted Data")
                            .font(.headline)
                        Text("Display encrypted text and SHA-256 hash in messages")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .tint(.purple)
                .onChange(of: showEncryptedData) { newValue in
                    withAnimation(.easeInOut(duration: 0.3)) {
                        SettingsService.shared.showEncryptedData = newValue
                    }
                }
            } header: {
                Text("Message Display")
                    .foregroundColor(.gray)
            }
            .listRowBackground(Color(red: 0.15, green: 0.15, blue: 0.17))
        }
        .navigationTitle("Display Settings")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(red: 0.1, green: 0.1, blue: 0.12))
        .scrollContentBackground(.hidden)
        .preferredColorScheme(.dark)
    }
}

struct MessagePreview: View {
    let showEncryptedData: Bool
    @State private var isEncryptedExpanded = false
    @State private var isSHAExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Preview User")
                .font(.caption)
                .foregroundColor(.purple.opacity(0.8))
            
            VStack(alignment: .leading, spacing: 8) {
                if showEncryptedData {
                    VStack(spacing: 8) {
                        // Encrypted text with real component
                        ControlledExpandableSHAView(
                            label: "Encrypted",
                            content: "a3f5b2c8d9e1f4a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0",
                            isFromCurrentUser: false,
                            isExpanded: $isEncryptedExpanded
                        )
                        .id("preview_encrypted")
                        
                        // SHA Hash with real component
                        ControlledExpandableSHAView(
                            label: "SHA-256",
                            content: "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824",
                            isFromCurrentUser: false,
                            isExpanded: $isSHAExpanded
                        )
                        .id("preview_sha256")
                        
                        Divider()
                            .background(Color.white.opacity(0.2))
                            .padding(.vertical, 4)
                    }
                    .transition(.opacity)
                }
                
                // Decrypted message text
                Text("Hello! This is a preview message.")
                    .font(.body)
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(red: 0.2, green: 0.2, blue: 0.22))
            .cornerRadius(18)
            .frame(maxWidth: UIScreen.main.bounds.width * 0.75, alignment: .leading)
            
            Text("2:45 PM")
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .onChange(of: showEncryptedData) { newValue in
            if !newValue {
                // Сбрасываем состояния при выключении
                isEncryptedExpanded = false
                isSHAExpanded = false
            }
        }
    }
}

// Версия ExpandableSHAView с внешним контролем состояния
struct ControlledExpandableSHAView: View {
    let label: String
    let content: String
    let isFromCurrentUser: Bool
    @Binding var isExpanded: Bool
    
    var body: some View {
        Group {
            if isExpanded {
                // Expanded state with Copy button
                VStack(alignment: .leading, spacing: 8) {
                    Button(action: {
                        copyToClipboard()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 10))
                            Text("Copy")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(isFromCurrentUser ? .white.opacity(0.8) : .purple.opacity(0.8))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            isFromCurrentUser
                                ? Color.white.opacity(0.15)
                                : Color.black.opacity(0.2)
                        )
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    
                    HStack(alignment: .top, spacing: 8) {
                        Text(label)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(Color.white.opacity(0.5))
                            .frame(width: 80, alignment: .leading)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(content)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(Color.white.opacity(0.7))
                                .lineLimit(nil)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isExpanded = false
                                }
                            }) {
                                Text("Less")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(isFromCurrentUser ? .white.opacity(0.6) : .purple.opacity(0.6))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    isFromCurrentUser
                        ? Color.white.opacity(0.1)
                        : Color.black.opacity(0.15)
                )
                .cornerRadius(8)
            } else {
                // Collapsed state
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded = true
                    }
                }) {
                    HStack(alignment: .center, spacing: 8) {
                        Text(label)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(Color.white.opacity(0.5))
                            .frame(width: 80, alignment: .leading)
                        
                        Text(truncatedContent)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(Color.white.opacity(0.6))
                            .lineLimit(1)
                        
                        Spacer(minLength: 0)
                        
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(isFromCurrentUser ? .white.opacity(0.6) : .purple.opacity(0.6))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        isFromCurrentUser
                            ? Color.white.opacity(0.1)
                            : Color.black.opacity(0.15)
                    )
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private var truncatedContent: String {
        if content.count > 30 {
            return String(content.prefix(30)) + "..."
        }
        return content
    }
    
    private func copyToClipboard() {
        UIPasteboard.general.string = content
        print("📋 Copied to clipboard: \(label)")
    }
}

#Preview {
    NavigationStack {
        DisplaySettingsView()
    }
}

