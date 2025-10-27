//
//  ExpandableSHAView.swift
//  SHAiny
//
//  Created by Сергей Вихляев on 26.10.2025.
//

import SwiftUI

struct ExpandableSHAView: View {
    let label: String
    let content: String
    let isFromCurrentUser: Bool
    
    @State private var isExpanded: Bool = false
    
    var body: some View {
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
                
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded = true
                    }
                }) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(isFromCurrentUser ? .white.opacity(0.6) : .purple.opacity(0.6))
                }
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
        // TODO: Show toast notification
    }
}

#Preview {
    VStack(spacing: 20) {
        ExpandableSHAView(
            label: "Encrypted",
            content: "639f9e09635313572d18ba34:7bd2380447ad0ba40b71fa5fb8ea5cd65893e8722eb91fc02024d62fc9b60c8188ef8bec0d8",
            isFromCurrentUser: true
        )
        .padding()
        
        ExpandableSHAView(
            label: "SHA-256",
            content: "0468699d3b3be251441ec0da5006e5143a0096b22e86326ca8a16bc5a248ae5b",
            isFromCurrentUser: false
        )
        .padding()
    }
    .padding()
    .background(Color(red: 0.1, green: 0.1, blue: 0.12))
}

